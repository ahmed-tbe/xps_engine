function payload = executeTrial(fixture,projectFolder)
%EXECUTETRIAL Run one Phase 0H fixture through the non-graphical fit path.
%
% This function never calls a plotting function. Multi-start changes only
% the initial parameter vector supplied to xps.fitSpectrum.

arguments
    fixture (1,1) struct
    projectFolder (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
end

started = tic;
cfg = jsondecode(fileread(fullfile(projectFolder,"config","test", ...
    "ruoff_like_sample_A_synthetic_v1.json")));

payload = basePayload(fixture);
if fixture.optimizer_invocations_per_trial_planned == 0
    payload = executeCompositionOnly(payload,fixture,cfg);
    payload.elapsed_seconds = toc(started);
    return
end

Cpre = preprocessRegion(fixture.C1s,cfg.preprocessing);
Fpre = preprocessRegion(fixture.F1s,cfg.preprocessing);
variantResults = repmat(struct(),numel(fixture.fit_variants),1);
totalInvocations = 0;
allConverged = true;
for v = 1:numel(fixture.fit_variants)
    variant = fixture.fit_variants(v);
    [Cfit,Cattempts,Cselected,Cinvocations] = fitRegion(Cpre, ...
        variant.C1s_peaks,variant.C1s_starts,cfg.peak_shape);
    [Ffit,Fattempts,Fselected,Finvocations] = fitRegion(Fpre, ...
        variant.F1s_peaks,variant.F1s_starts,cfg.peak_shape);
    totalInvocations = totalInvocations+Cinvocations+Finvocations;

    Ffit.peaks = xps.classifyF1sPeaks(Ffit.peaks, ...
        cfg.F1s.classification_boundaries_eV);
    Ffit.peaks = applyClassificationExpectation(Ffit.peaks, ...
        fixture.classification_expectation);
    acquisition = acquisitionConfiguration(fixture.scaling);
    quantScaling = xps.buildQuantificationScaling(Cpre,Fpre,acquisition);
    composition = safeComposition(Cfit.peaks,Ffit.peaks,fixture,cfg,quantScaling);

    variantResults(v).name = string(variant.name);
    variantResults(v).C1s = compactFit(Cfit,Cpre,Cselected,Cattempts);
    variantResults(v).F1s = compactFit(Ffit,Fpre,Fselected,Fattempts);
    variantResults(v).composition = composition;
    variantResults(v).quantification_scaling = quantScaling;
    variantResults(v).converged = Cfit.exitflag>0 && Ffit.exitflag>0;
    allConverged = allConverged && variantResults(v).converged;
end

if totalInvocations ~= fixture.optimizer_invocations_per_trial_planned
    error("xpsh:executeTrial:OptimizerInvocationMismatch", ...
        "Executed %d optimizer calls; fixture planned %d.",totalInvocations, ...
        fixture.optimizer_invocations_per_trial_planned);
end
payload.status = "success";
payload.trial_converged = allConverged;
payload.optimizer_invocations = totalInvocations;
payload.variants = variantResults;
payload.elapsed_seconds = toc(started);
end

function payload = basePayload(fixture)
payload = struct("schema_id","phase0h_trial_checkpoint", ...
    "schema_version","1.0.0","status","running", ...
    "cell_key",string(fixture.cell_key),"trial_id",fixture.trial_id, ...
    "seeds",fixture.seeds,"settings",fixture.settings, ...
    "charging_shift_eV",fixture.charging_shift_eV, ...
    "scaling_truth_and_supplied",fixture.scaling, ...
    "sensitivity_profile",fixture.sensitivity_profile, ...
    "composition_model_profile",fixture.composition_model_profile, ...
    "classification_expectation",fixture.classification_expectation, ...
    "peak_id_mapping",fixture.peak_id_mapping, ...
    "truth",truthSnapshot(fixture), ...
    "plotting_enabled",false,"optimizer_invocations",0, ...
    "trial_converged",false,"elapsed_seconds",NaN, ...
    "warnings",strings(0,1));
end

function snapshot = truthSnapshot(fixture)
for regionName = ["C1s","F1s"]
    region = fixture.(regionName);
    snapshot.(regionName) = struct("peaks",region.truth_peaks, ...
        "energy_window_eV",[region.energy(1),region.energy(end)], ...
        "point_count",numel(region.energy), ...
        "noise_sigma_raw",region.noise_sigma_raw, ...
        "software_normalization_scale",region.software_normalization_scale, ...
        "generation_acquisition_scale",region.generation_acquisition_scale, ...
        "background_metadata",region.background_truth_metadata, ...
        "background_fit_method",region.background_fit_method, ...
        "pseudo_voigt_eta",region.pseudo_voigt_eta);
end
end

function pre = preprocessRegion(region,settings)
settings.background = region.background_fit_method;
S = struct("energyFit",region.energy,"intensityFit",region.observed);
pre = xps.preprocessSpectrum(S,settings);
end

function [best,attempts,selected,invocations] = fitRegion(pre,peaks,starts,shape)
nStarts = size(starts,3);
if nStarts < 1,error("xpsh:executeTrial:MissingStarts","Fit region has no starts.");end
regionCfg = struct("peaks",peaks);
attempts = repmat(struct("start_index",0,"status","", ...
    "exitflag",NaN,"resnorm",NaN,"runtime_seconds",NaN, ...
    "error_identifier","","error_message",""),nStarts,1);
results = cell(nStarts,1);
score = inf(nStarts,1);
for k = 1:nStarts
    oneStart = tic;
    attempts(k).start_index = k;
    try
        options = struct("initialParams",starts(:,:,k));
        results{k} = xps.fitSpectrum(pre.energy,pre.y_fit,regionCfg,shape,options);
        attempts(k).status = "completed";
        attempts(k).exitflag = results{k}.exitflag;
        attempts(k).resnorm = results{k}.resnorm;
        if isfinite(results{k}.resnorm),score(k)=results{k}.resnorm;end
    catch exception
        attempts(k).status = "error";
        attempts(k).error_identifier = string(exception.identifier);
        attempts(k).error_message = string(exception.message);
    end
    attempts(k).runtime_seconds = toc(oneStart);
end
invocations = nStarts;
[minimum,selected] = min(score);
if ~isfinite(minimum)
    messages = string({attempts.error_message});
    error("xpsh:executeTrial:AllStartsFailed", ...
        "All %d starts failed: %s",nStarts,strjoin(messages," | "));
end
best = results{selected};
end

function out = compactFit(fit,pre,selected,attempts)
out = fit;
out.selected_start_index = selected;
out.attempts = attempts;
out.preprocessing = struct("normalization_method",pre.normalization_method, ...
    "software_normalization_scale",pre.softwareNormalizationScale, ...
    "background_method",pre.background_method, ...
    "background_parameters",pre.background_parameters);
out.residual_autocorrelation = xpsh.residualAutocorrelation( ...
    fit.residual,fit.observed);
if isfield(out.metrics,"residual"),out.metrics=rmfield(out.metrics,"residual");end
if isfield(out.peaks,"curve"),out.peaks=rmfield(out.peaks,"curve");end
out = rmfield(out,["energy","observed","fitted"]);
end

function acquisition = acquisitionConfiguration(scaling)
acquisition.C1s = struct("known",logical(scaling.C1s_known), ...
    "scale_factor",scaling.supplied_C1s_scale, ...
    "provenance","Phase 0H supplied synthetic acquisition metadata");
acquisition.F1s = struct("known",logical(scaling.F1s_known), ...
    "scale_factor",scaling.supplied_F1s_scale, ...
    "provenance","Phase 0H supplied synthetic acquisition metadata");
end

function peaks = applyClassificationExpectation(peaks,expectation)
for i = 1:numel(peaks)
    idx = find(expectation.PeakID==string(peaks(i).id),1);
    if ~isempty(idx)
        peaks(i).chemical_assignment = expectation.ExpectedPostFitLabel(idx);
    end
end
end

function composition = safeComposition(Cpeaks,Fpeaks,fixture,cfg,scaling)
try
    composition=xps.calculateComposition(Cpeaks,Fpeaks, ...
        fixture.sensitivity_profile.S_C,fixture.sensitivity_profile.S_F, ...
        cfg.composition.alpha_ambiguous,scaling,fixture.sensitivity_profile, ...
        fixture.composition_model_profile);
catch exception
    composition=struct("schema_id","phase0h_withheld_composition", ...
        "status","withheld_for_misspecified_peak_model", ...
        "valid",false,"error_identifier",string(exception.identifier), ...
        "error_message",string(exception.message));
end
end

function payload = executeCompositionOnly(payload,fixture,cfg)
Cpeaks = xpsh.truthAsFittedPeaks(fixture.C1s.truth_peaks);
Fpeaks = xpsh.truthAsFittedPeaks(fixture.F1s.truth_peaks);
Fpeaks = xps.classifyF1sPeaks(Fpeaks,cfg.F1s.classification_boundaries_eV);
pre = struct("softwareNormalizationScale",1);
acquisition.C1s=struct("known",true,"scale_factor",1,"provenance","truth areas");
acquisition.F1s=struct("known",true,"scale_factor",1,"provenance","truth areas");
scaling=xps.buildQuantificationScaling(pre,pre,acquisition);
composition=xps.calculateComposition(Cpeaks,Fpeaks, ...
    fixture.sensitivity_profile.S_C,fixture.sensitivity_profile.S_F, ...
    cfg.composition.alpha_ambiguous,scaling,fixture.sensitivity_profile, ...
    fixture.composition_model_profile);
payload.status="success";
payload.trial_converged=true;
payload.optimizer_invocations=0;
payload.variants=struct("name","composition_only", ...
    "composition",composition,"quantification_scaling",scaling, ...
    "converged",true);
end
