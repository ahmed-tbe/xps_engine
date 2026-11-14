function fixture = generateFixture(cellDefinition,trialID,projectFolder)
%GENERATEFIXTURE Generate one Phase 0H trial fixture without fitting it.

arguments
    cellDefinition (1,1) struct
    trialID (1,1) double {mustBeInteger,mustBePositive}
    projectFolder (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
end

cfg = jsondecode(fileread(fullfile(projectFolder,"config","test", ...
    "ruoff_like_sample_A_synthetic_v1.json")));
reference = xps.loadReference(fullfile(projectFolder, ...
    string(cfg.reference_data_file)));
s = cellDefinition.settings;
seeds = xpsh.trialSeeds(cellDefinition,trialID);

cFit = asStructArray(cfg.C1s.peaks);
fFit = asStructArray(cfg.F1s.peaks);
cTruth = makeCTruth(cFit,reference,cfg);
fTruth = makeFTruth(fFit,cfg);

% Truth-side structural changes.
if s.center_offset_factor ~= 1
    cTruth = contractCenters(cTruth,1:min(4,numel(cTruth)), ...
        s.center_offset_factor);
    fTruth = contractCenters(fTruth,1:numel(fTruth),s.center_offset_factor);
end
if isfinite(s.fwhm_override_eV)
    [cTruth.FWHM_eV] = deal(s.fwhm_override_eV);
    [fTruth.FWHM_eV] = deal(s.fwhm_override_eV);
end
if strlength(s.zero_truth_target) > 0
    [region,id] = parseTarget(s.zero_truth_target);
    if region == "C1s", cTruth = setTruthArea(cTruth,id,0);
    else, fTruth = setTruthArea(fTruth,id,0); end
end
if s.unmodelled_C_fraction > 0
    cTruth = scaleTruthAreas(cTruth,1-s.unmodelled_C_fraction);
    cTruth(end+1) = truthPeak("C_unmodelled_286p25", ...
        "unmodelled C1s component",286.25,0.75,s.unmodelled_C_fraction, ...
        "unmodelled_C1s",false);
end
if s.F_other_fraction > 0
    totalF = sum([fTruth.physical_area]);
    fTruth = scaleTruthAreas(fTruth,1-s.F_other_fraction);
    fTruth(end+1) = truthPeak("F_other_681p5", ...
        "physisorbed/entrapped/interface F",681.5,0.65, ...
        totalF*s.F_other_fraction,"other_or_interface_F",false);
end
if s.extra_F_fraction > 0
    totalF = sum([fTruth.physical_area]);
    fTruth = scaleTruthAreas(fTruth,1-s.extra_F_fraction);
    extraID = "F_"+s.extra_F_type+"_extra";
    extraLabel = s.extra_F_type+"-related unmodelled F1s component";
    fTruth(end+1) = truthPeak(extraID,extraLabel,s.extra_F_center_eV, ...
        0.65,totalF*s.extra_F_fraction, ...
        s.extra_F_type+"_related_F",false);
end
if s.charging_half_range_eV > 0
    chargingShift = uniformDraw(seeds.charging_shift, ...
        -s.charging_half_range_eV,s.charging_half_range_eV,[1,1]);
    for i = 1:numel(cTruth), cTruth(i).center_eV=cTruth(i).center_eV+chargingShift; end
    for i = 1:numel(fTruth), fTruth(i).center_eV=fTruth(i).center_eV+chargingShift; end
else
    chargingShift = 0;
end

% Fit-model structural changes are independent of truth generation.
if strlength(s.omit_fit_target) > 0
    [region,id] = parseTarget(s.omit_fit_target);
    if region == "C1s"
        cFit = removeFitPeak(cFit,id);
        cTruth = markOmitted(cTruth,id);
    else
        fFit = removeFitPeak(fFit,id);
        fTruth = markOmitted(fTruth,id);
    end
end
if strlength(s.add_zero_truth_fit_region) > 0
    if s.add_zero_truth_fit_region == "C1s"
        extra = cFit(1);
        extra.id = "C_extra_fit_286p25";
        extra.assignment = "zero-truth fitted C1s component";
        extra.initial_center_eV = 286.25;
        extra.center_bounds_eV = [285.75 286.75];
        extra.FWHM_bounds_eV = [0.4 1.5];
        if isfield(extra,"fluorine_coefficient"),extra.fluorine_coefficient=0;end
        cFit(end+1) = extra;
        cTruth(end+1) = truthPeak(extra.id,extra.assignment,286.25,0.75,0, ...
            "zero_truth_extraneous_fit",true);
    else
        extra = fFit(1);
        extra.id = "F_extra_fit_689p8";
        extra.assignment = "zero-truth fitted F1s component";
        extra.initial_center_eV = 689.8;
        extra.center_bounds_eV = [689.3 690.3];
        extra.FWHM_bounds_eV = [0.4 1.5];
        extra.include_in_carbon_bound_F = false;
        extra.include_in_total_F = false;
        fFit(end+1) = extra;
        fTruth(end+1) = truthPeak(extra.id,extra.assignment,689.8,0.75,0, ...
            "zero_truth_extraneous_fit",true);
    end
end
if s.use_overlap_test_bounds
    cFit = applyOverlapTestBounds(cFit,"C1s");
    fFit = applyOverlapTestBounds(fFit,"F1s");
end

% Energy windows are generated before trimming.
cEnergyFull = (280:0.025:297).';
fLow = 682;
if isfinite(s.extend_F_window_low_eV), fLow = s.extend_F_window_low_eV; end
fEnergyFull = (fLow:0.020:691).';

% Acquisition/file-unit factors affect generated recorded areas.
[scaling,cGenerationScale,fGenerationScale] = makeScaling(s,seeds,cfg,trialID);

[cPeakSignal,cComponents] = synthesize(cEnergyFull,cTruth, ...
    cGenerationScale,s.pseudo_voigt_eta);
[fPeakSignal,fComponents] = synthesize(fEnergyFull,fTruth, ...
    fGenerationScale,s.pseudo_voigt_eta);
[cBackground,cBackgroundMeta] = xpsh.generateBackground( ...
    cEnergyFull,cPeakSignal,s.background_truth);
[fBackground,fBackgroundMeta] = xpsh.generateBackground( ...
    fEnergyFull,fPeakSignal,s.background_truth);

[cNoise,cSigma] = makeNoise(cPeakSignal,s.snr,seeds.C_noise);
[fNoise,fSigma] = makeNoise(fPeakSignal,s.snr,seeds.F_noise);
cObservedFull = cPeakSignal+cBackground+cNoise;
fObservedFull = fPeakSignal+fBackground+fNoise;

cKeep = retainedMask(cEnergyFull,s.trim_edge,s.trim_eV);
fKeep = retainedMask(fEnergyFull,s.trim_edge,s.trim_eV);
cRegion = makeRegion("C1s",cEnergyFull,cKeep,cTruth,cPeakSignal, ...
    cComponents,cBackground,cNoise,cObservedFull,cSigma,cGenerationScale, ...
    s.pseudo_voigt_eta,cBackgroundMeta,s.background_fit);
fRegion = makeRegion("F1s",fEnergyFull,fKeep,fTruth,fPeakSignal, ...
    fComponents,fBackground,fNoise,fObservedFull,fSigma,fGenerationScale, ...
    s.pseudo_voigt_eta,fBackgroundMeta,s.background_fit);

% Configuration variants encode paired order/bound checks but do not fit.
variants = makeFitVariants(cFit,fFit,cTruth,fTruth,cellDefinition,seeds, ...
    cRegion.generation_acquisition_scale/cRegion.software_normalization_scale, ...
    fRegion.generation_acquisition_scale/fRegion.software_normalization_scale);

% Expected post-fit classification mutations are recorded by stable ID.
classification = makeClassificationExpectation(fFit,s.label_mutation);

% Sensitivity profile used by this cell.
sensitivity = makeSensitivityProfile(s,projectFolder,cfg,cellDefinition.family_id);
compositionModel = xps.loadCompositionModelProfile(fullfile(projectFolder, ...
    "config","composition","ruoff_primary_models_v1.json"));

fixture.schema_id = "phase0h_trial_fixture";
fixture.schema_version = "1.0.0";
fixture.plan_version = "1.0.0";
fixture.cell_key = cellDefinition.cell_key;
fixture.family_id = cellDefinition.family_id;
fixture.cell_index = cellDefinition.cell_index;
fixture.trial_id = trialID;
fixture.no_fitting_performed = true;
fixture.optimizer_invocations_per_trial_planned = ...
    cellDefinition.optimizer_invocations_per_trial;
fixture.seeds = seeds;
fixture.settings = s;
fixture.charging_shift_eV = chargingShift;
fixture.C1s = cRegion;
fixture.F1s = fRegion;
fixture.fit_variants = variants;
fixture.classification_expectation = classification;
fixture.scaling = scaling;
fixture.sensitivity_profile = sensitivity;
fixture.composition_model_profile = compositionModel;
fixture.peak_id_mapping.C1s = idMapping(cTruth,cFit);
fixture.peak_id_mapping.F1s = idMapping(fTruth,fFit);
fixture.provenance = struct( ...
    "base_configuration",fullfile(projectFolder,"config","test", ...
        "ruoff_like_sample_A_synthetic_v1.json"), ...
    "reference_fixture",string(reference.source_file), ...
    "background_generator",cBackgroundMeta.generator_id);
end

function peaks = makeCTruth(fitPeaks,reference,cfg)
refs = asStructArray(reference.direct_references.C1s_normal_emission.peaks);
peaks = repmat(emptyTruthPeak(),1,numel(fitPeaks));
for i = 1:numel(fitPeaks)
    id = string(fitPeaks(i).id);
    idx = find(string({refs.id}) == id,1);
    if isempty(idx),error("xpsh:generateFixture:MissingCReference",id);end
    peaks(i) = truthPeak(id,string(fitPeaks(i).assignment), ...
        refs(idx).center_eV,cfg.synthetic_generation.C1s_FWHM_eV, ...
        cfg.synthetic_generation.C1s_total_physical_area* ...
        refs(idx).fraction_percent/100,"C1s_component",true);
end
end

function peaks = makeFTruth(fitPeaks,cfg)
centers = cfg.synthetic_generation.F1s_centers_eV(:);
areas = cfg.synthetic_generation.F1s_physical_areas(:);
labels = ["ionic_or_substrate_bound_F","semi_covalent_F_C","covalent_F_C"];
peaks = repmat(emptyTruthPeak(),1,numel(fitPeaks));
for i = 1:numel(fitPeaks)
    peaks(i) = truthPeak(string(fitPeaks(i).id), ...
        string(fitPeaks(i).assignment),centers(i), ...
        cfg.synthetic_generation.F1s_FWHM_eV,areas(i),labels(i),true);
end
end

function peak = truthPeak(id,label,center,width,area,chemical,inFit)
peak = emptyTruthPeak();
peak.id = string(id); peak.label = string(label);
peak.center_eV = center; peak.FWHM_eV = width;
peak.physical_area = area; peak.chemical_assignment = string(chemical);
peak.in_fit_model = logical(inFit);
peak.true_full_analytic_area = area;
peak.true_in_window_area = NaN;
peak.true_window_containment_fraction = NaN;
peak.true_sampled_grid_area = NaN;
end

function peak = emptyTruthPeak
peak = struct("id","","label","","center_eV",NaN,"FWHM_eV",NaN, ...
    "physical_area",NaN,"chemical_assignment","","in_fit_model",true, ...
    "true_full_analytic_area",NaN,"true_in_window_area",NaN, ...
    "true_window_containment_fraction",NaN,"true_sampled_grid_area",NaN);
end

function peaks = contractCenters(peaks,indices,factor)
areas = [peaks(indices).physical_area];
centers = [peaks(indices).center_eV];
if sum(areas) > 0, centroid=sum(areas.*centers)/sum(areas); else, centroid=mean(centers); end
for k = indices
    peaks(k).center_eV = centroid+factor*(peaks(k).center_eV-centroid);
end
end

function peaks = scaleTruthAreas(peaks,multiplier)
for i = 1:numel(peaks),peaks(i).physical_area=peaks(i).physical_area*multiplier;end
end

function peaks = setTruthArea(peaks,id,value)
idx = find(string({peaks.id}) == id,1);
if isempty(idx),error("xpsh:generateFixture:MissingTruthPeak",id);end
peaks(idx).physical_area = value;
end

function [region,id] = parseTarget(target)
parts = split(string(target),":"); region=parts(1); id=parts(2);
end

function peaks = removeFitPeak(peaks,id)
idx = find(string({peaks.id}) == id,1);
if isempty(idx),error("xpsh:generateFixture:MissingFitPeak",id);end
peaks(idx) = [];
end

function peaks = applyOverlapTestBounds(peaks,region)
for i = 1:numel(peaks)
    center = peaks(i).initial_center_eV;
    if region == "C1s",halfWidth=1.25;else,halfWidth=2.5;end
    peaks(i).center_bounds_eV = [center-halfWidth center+halfWidth];
end
end

function [scaling,cScale,fScale] = makeScaling(s,seeds,cfg,trialID)
lockedC = cfg.synthetic_generation.C1s_acquisition_scale_factor;
lockedF = cfg.synthetic_generation.F1s_acquisition_scale_factor;
trueC = lockedC; trueF = lockedF; fileMultiplier = 1;
if ismember(s.scale_mode,["random_exact","random_exact_file_units","supplied_error"])
    trueC = logUniformDraw(seeds.C_acquisition,0.25,4,[1,1]);
    trueF = logUniformDraw(seeds.F_acquisition,0.25,4,[1,1]);
end
if s.scale_mode == "random_exact_file_units"
    draws = logUniformDraw(seeds.C_acquisition,1e-3,1e3,[1,2]);
    fileMultiplier = draws(2);
end
cScale = trueC*fileMultiplier; fScale = trueF*fileMultiplier;
suppliedC = cScale; suppliedF = fScale; knownC = true; knownF = true;
if s.scale_mode == "unknown_cycle"
    pattern = mod(trialID-1,3)+1;
    if pattern == 1,knownC=false;suppliedC=NaN;
    elseif pattern == 2,knownF=false;suppliedF=NaN;
    else,knownC=false;knownF=false;suppliedC=NaN;suppliedF=NaN;end
elseif s.scale_mode == "supplied_error"
    if ismember(s.acquisition_error_region,["C1s","both"])
        suppliedC = suppliedC*s.acquisition_error_multiplier;
    end
    if ismember(s.acquisition_error_region,["F1s","both"])
        suppliedF = suppliedF*s.acquisition_error_multiplier;
    end
end
scaling = struct("definition", ...
    "physical_area = fitted_area * software_normalization_scale / supplied_acquisition_scale", ...
    "true_C1s_acquisition_scale",trueC, ...
    "true_F1s_acquisition_scale",trueF, ...
    "file_unit_multiplier",fileMultiplier, ...
    "generation_C1s_scale",cScale,"generation_F1s_scale",fScale, ...
    "supplied_C1s_scale",suppliedC,"supplied_F1s_scale",suppliedF, ...
    "C1s_known",knownC,"F1s_known",knownF, ...
    "scale_mode",s.scale_mode);
end

function [sumSignal,components] = synthesize(energy,peaks,scale,eta)
components = zeros(numel(energy),numel(peaks));
for i = 1:numel(peaks)
    components(:,i) = peakCurve(energy,peaks(i).center_eV, ...
        peaks(i).FWHM_eV,peaks(i).physical_area*scale,eta);
end
sumSignal = sum(components,2);
end

function y = peakCurve(x,center,fwhm,area,eta)
sigma = fwhm/(2*sqrt(2*log(2)));
gaussian = area/(sigma*sqrt(2*pi))*exp(-0.5*((x-center)/sigma).^2);
gamma = fwhm/2;
lorentzian = area/pi*gamma./((x-center).^2+gamma^2);
y = (1-eta)*gaussian+eta*lorentzian;
end

function [noise,sigma] = makeNoise(signal,snr,seed)
if isinf(snr),sigma=0;noise=zeros(size(signal));return;end
sigma = max(signal)/snr;
noise = sigma*normalDraw(seed,size(signal));
end

function keep = retainedMask(energy,edge,amount)
keep = true(size(energy));
if amount <= 0 || edge == "none",return;end
if ismember(edge,["low","both"]),keep=keep & energy>=energy(1)+amount;end
if ismember(edge,["high","both"]),keep=keep & energy<=energy(end)-amount;end
end

function region = makeRegion(name,energyFull,keep,truth,peakSignal,components, ...
        background,noise,observed,sigma,generationScale,eta,backgroundMeta,fitBackground)
energy = energyFull(keep);
for i = 1:numel(truth)
    fraction = analyticContainment(truth(i),energy(1),energy(end),eta);
    truth(i).true_full_analytic_area = truth(i).physical_area;
    truth(i).true_window_containment_fraction = fraction;
    truth(i).true_in_window_area = truth(i).physical_area*fraction;
    truth(i).true_sampled_grid_area = trapz(energy,components(keep,i))/generationScale;
end
region.name = name;
region.energy_full = energyFull;
region.energy = energy;
region.retained_mask = keep;
region.truth_peaks = truth;
region.peak_signal = peakSignal(keep);
region.background = background(keep);
region.noise = noise(keep);
region.observed = observed(keep);
region.noise_sigma_raw = sigma;
region.software_normalization_scale = max(observed(keep));
region.noise_sigma_post_normalization = sigma/region.software_normalization_scale;
region.background_truth_metadata = backgroundMeta;
region.background_fit_method = fitBackground;
region.generation_acquisition_scale = generationScale;
region.pseudo_voigt_eta = eta;
end

function fraction = analyticContainment(peak,lower,upper,eta)
if peak.physical_area == 0,fraction=0;return;end
sigma = peak.FWHM_eV/(2*sqrt(2*log(2)));
g = 0.5*(erf((upper-peak.center_eV)/(sqrt(2)*sigma))- ...
    erf((lower-peak.center_eV)/(sqrt(2)*sigma)));
gamma = peak.FWHM_eV/2;
l = (atan((upper-peak.center_eV)/gamma)- ...
    atan((lower-peak.center_eV)/gamma))/pi;
fraction = (1-eta)*g+eta*l;
end

function variants = makeFitVariants(cFit,fFit,cTruth,fTruth,cellDef,seeds,cScale,fScale)
s = cellDef.settings;
names = "primary";
cConfigs = {cFit}; fConfigs = {fFit};
if cellDef.pipelines_per_trial == 2 && s.permute_fit_order
    names = ["canonical","permuted"];
    cConfigs = {cFit,cFit(permutation(seeds.C_order,numel(cFit)))};
    fConfigs = {fFit,fFit(permutation(seeds.F_order,numel(fFit)))};
elseif cellDef.pipelines_per_trial == 2 && s.bound_variant ~= "none"
    names = ["original_bounds","widened_bounds"];
    cConfigs = {cFit,widenBounds(cFit,s.bound_variant)};
    fConfigs = {fFit,widenBounds(fFit,s.bound_variant)};
elseif s.permute_fit_order
    names = "permuted";
    cConfigs = {cFit(permutation(seeds.C_order,numel(cFit)))};
    fConfigs = {fFit(permutation(seeds.F_order,numel(fFit)))};
end
variants = repmat(struct(),numel(names),1);
for i = 1:numel(names)
    variants(i).name = names(i);
    variants(i).C1s_peaks = cConfigs{i};
    variants(i).F1s_peaks = fConfigs{i};
    variants(i).C1s_starts = makeStarts(cConfigs{i},cTruth,cellDef.starts, ...
        s.start_mode,seeds.C_center,seeds.C_area,seeds.C_width,cScale);
    variants(i).F1s_starts = makeStarts(fConfigs{i},fTruth,cellDef.starts, ...
        s.start_mode,seeds.F_center,seeds.F_area,seeds.F_width,fScale);
end
end

function starts = makeStarts(config,truth,nStarts,mode,centerSeed,areaSeed,widthSeed,scale)
n = numel(config);
if nStarts == 0,starts=zeros(n,3,0);return;end
starts = zeros(n,3,nStarts);
equalArea = max(sum([truth.physical_area])*scale/max(n,1),eps);
centerU = uniformDraw(centerSeed,0,1,[n,nStarts]);
areaU = uniformDraw(areaSeed,0,1,[n,nStarts]);
widthU = uniformDraw(widthSeed,0,1,[n,nStarts]);
for i = 1:n
    cfg = config(i); idx=find(string({truth.id})==string(cfg.id),1);
    if isempty(idx)
        truthCenter=cfg.initial_center_eV; truthWidth=mean(cfg.FWHM_bounds_eV);
        truthArea=equalArea*0.01;
    else
        truthCenter=truth(idx).center_eV; truthWidth=truth(idx).FWHM_eV;
        truthArea=max(truth(idx).physical_area*scale,equalArea*0.01);
    end
    for k = 1:nStarts
        if mode == "production"
            center=cfg.initial_center_eV; width=mean(cfg.FWHM_bounds_eV);
            area=equalArea;
        elseif mode == "moderate"
            center=xpsh.selectInitialCenter(truthCenter,0.25, ...
                cfg.center_bounds_eV,cfg.initial_center_eV,centerU(i,k));
            loW=max(cfg.FWHM_bounds_eV(1),0.75*truthWidth);
            hiW=min(cfg.FWHM_bounds_eV(2),1.25*truthWidth);
            width=exp(log(loW)+(log(hiW)-log(loW))*widthU(i,k));
            area=truthArea*exp(log(0.5)+log(4)*areaU(i,k));
        else
            center=cfg.center_bounds_eV(1)+diff(cfg.center_bounds_eV)*centerU(i,k);
            width=exp(log(cfg.FWHM_bounds_eV(1))+ ...
                log(cfg.FWHM_bounds_eV(2)/cfg.FWHM_bounds_eV(1))*widthU(i,k));
            area=truthArea*exp(log(0.25)+log(16)*areaU(i,k));
        end
        starts(i,:,k)=[center,width,area];
    end
end
end

function peaks = widenBounds(peaks,variant)
for i = 1:numel(peaks)
    if contains(variant,"center")
        peaks(i).center_bounds_eV = peaks(i).center_bounds_eV+[-0.25 0.25];
    end
    if contains(variant,"fwhm")
        bounds=peaks(i).FWHM_bounds_eV; span=diff(bounds);
        peaks(i).FWHM_bounds_eV=[max(eps,bounds(1)-0.25*span), ...
            bounds(2)+0.25*span];
    end
end
end

function expectation = makeClassificationExpectation(fFit,mutation)
ids = string({fFit.id}).';
labels = strings(numel(fFit),1);
for i = 1:numel(fFit)
    id=ids(i);
    if contains(id,"ionic"),labels(i)="ionic_or_substrate_bound_F";
    elseif contains(id,"semi"),labels(i)="semi_covalent_F_C";
    elseif contains(id,"covalent"),labels(i)="covalent_F_C";
    else,labels(i)="unclassified_extraneous";end
end
switch mutation
    case "swap_semi_ionic"
        labels = swapLabels(labels,"semi_covalent_F_C","ionic_or_substrate_bound_F");
    case "swap_semi_covalent"
        labels = swapLabels(labels,"semi_covalent_F_C","covalent_F_C");
    case "remove_semi"
        labels(labels=="semi_covalent_F_C")="unclassified";
    case "duplicate_semi"
        idx=find(labels=="ionic_or_substrate_bound_F",1);
        if ~isempty(idx),labels(idx)="semi_covalent_F_C";end
end
expectation = table(ids,labels,VariableNames=["PeakID","ExpectedPostFitLabel"]);
expectation.Properties.Description = "Expected label mutation; no fitting performed";
end

function labels = swapLabels(labels,a,b)
aIdx=labels==a; bIdx=labels==b; labels(aIdx)=b; labels(bIdx)=a;
end

function profile = makeSensitivityProfile(s,projectFolder,cfg,familyID)
if familyID == 12
    filename = s.sensitivity_base_profile+".json";
    profile = xps.loadSensitivityProfile(fullfile(projectFolder,"config", ...
        "sensitivity",filename));
    profile.base_profile_id = string(profile.profile_id);
    profile.profile_id = string(profile.profile_id)+compose("_test_x%.3g", ...
        s.sensitivity_multiplier);
    profile.S_F = profile.S_F*s.sensitivity_multiplier;
    profile.ratio_value = profile.S_F/profile.S_C;
    profile.status = "test_only_derived_profile";
    profile.source_provenance = string(profile.source_provenance)+ ...
        compose(" Phase 0H test-only multiplier %.3g.",s.sensitivity_multiplier);
else
    profile = struct("profile_id","locked_fixture_numeric_sf4p4118", ...
        "profile_version","1.0.0","S_C",cfg.sensitivity_factors.C1s, ...
        "S_F",cfg.sensitivity_factors.F1s, ...
        "ratio_value",cfg.sensitivity_factors.F1s/cfg.sensitivity_factors.C1s, ...
        "status","test_fixture_locked", ...
        "source_provenance","Frozen Ruoff-like synthetic fixture values.", ...
        "intended_application","Phase 0H synthetic fixture only.");
end
end

function peaks = markOmitted(peaks,id)
idx=find(string({peaks.id})==id,1);
if isempty(idx),error("xpsh:generateFixture:MissingOmittedTruth",id);end
peaks(idx).in_fit_model=false;
end

function mapping = idMapping(truth,fit)
truthIDs=string({truth.id}).'; fitIDs=string({fit.id}).';
mapping = struct("truth_ids",truthIDs,"fit_ids",fitIDs, ...
    "matched_ids",intersect(truthIDs,fitIDs,"stable"), ...
    "truth_only_ids",setdiff(truthIDs,fitIDs,"stable"), ...
    "fit_only_ids",setdiff(fitIDs,truthIDs,"stable"));
end

function order = permutation(seed,n)
[~,order]=sort(uniformDraw(seed,0,1,[n,1])); order=order.';
end

function values = uniformDraw(seed,lower,upper,sz)
state=rng; cleanup=onCleanup(@()rng(state)); %#ok<NASGU>
rng(seed,"twister"); values=lower+(upper-lower)*rand(sz);
end

function values = logUniformDraw(seed,lower,upper,sz)
values=exp(uniformDraw(seed,log(lower),log(upper),sz));
end

function values = normalDraw(seed,sz)
state=rng; cleanup=onCleanup(@()rng(state)); %#ok<NASGU>
rng(seed,"twister"); values=randn(sz);
end

function values = asStructArray(values)
if ~iscell(values),return;end
allFields = strings(0,1);
for i = 1:numel(values)
    allFields = union(allFields,string(fieldnames(values{i})),"stable");
end
for i = 1:numel(values)
    for field = allFields.'
        if ~isfield(values{i},field),values{i}.(field)=[];end
    end
    values{i} = orderfields(values{i},cellstr(allFields));
end
values=[values{:}];
end
