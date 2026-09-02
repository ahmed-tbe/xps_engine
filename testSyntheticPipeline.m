function tests = testSyntheticPipeline
%TESTSYNTHETICPIPELINE Phase 0G-3 deterministic end-to-end validation.
%
% This test uses the production JSON configuration and executes:
% synthetic two-column files -> readSpectrum -> preprocessSpectrum ->
% fitSpectrum -> classifyF1sPeaks -> calculateComposition.
%
% It deliberately does not validate physical F1s/C1s quantification:
% each region is independently max-normalized by preprocessSpectrum.
% Restoring acquisition scales is the explicit subject of Phase 0G-4.

tests = functiontests(localfunctions);
end

function testDeterministicSixC1sThreeF1sPipeline(testCase)
cfg = jsondecode(fileread(fullfile("config", "legacy_current_v1.json")));
peakShape = "gaussian";

% Noise-free data are intentional here: this is a plumbing/recovery test,
% not a robustness study (deferred to Phase 0H). Every truth parameter is
% strictly inside its configured bound.
cTruth = [ ...
    284.15 0.50 0.80; ... % sp2_C_C
    285.55 0.50 0.80; ... % C_CF_sp3
    287.40 0.50 0.80; ... % C_F
    289.30 0.50 0.80; ... % C_CF23_C_O
    291.40 0.50 0.80; ... % CF2
    293.50 0.50 0.80];   % CF3
fTruth = [ ...
    681.50 0.60 0.80; ... % ionic/substrate-bound F
    686.50 0.60 0.80; ... % semi-covalent F-C
    691.00 0.60 0.80];    % covalent F-C

cEnergy = linspace(280, 297, 681).';
fEnergy = linspace(678, 693, 601).';
% Different raw acquisition multipliers are intentional. They demonstrate
% why the resulting cross-region F/C must not be interpreted physically
% until the Phase 0G-4 scale-restoration path exists.
cAcquisitionScale = 2.0;
fAcquisitionScale = 13.0;
cRaw = cAcquisitionScale * syntheticGaussianSum(cEnergy, cTruth);
fRaw = fAcquisitionScale * syntheticGaussianSum(fEnergy, fTruth);

% Keep these as character vectors: writematrix accepts them consistently
% across MATLAB releases and test-runner file-system implementations.
cFile = [tempname(tempdir) '.txt'];
fFile = [tempname(tempdir) '.txt'];
cleanupFiles = onCleanup(@() deleteIfPresent({cFile, fFile})); %#ok<NASGU>
% Write descending energy to exercise the reader's fitting-order handling.
writematrix([flipud(cEnergy) flipud(cRaw)], cFile, "Delimiter", "tab");
writematrix([flipud(fEnergy) flipud(fRaw)], fFile, "Delimiter", "tab");

C = xps.readSpectrum(cFile);
F = xps.readSpectrum(fFile);
Cpre = xps.preprocessSpectrum(C, cfg.preprocessing);
Fpre = xps.preprocessSpectrum(F, cfg.preprocessing);
Cfit = xps.fitSpectrum(Cpre.energy, Cpre.y_fit, cfg.C1s, peakShape);
Ffit = xps.fitSpectrum(Fpre.energy, Fpre.y_fit, cfg.F1s, peakShape);
Ffit.peaks = xps.classifyF1sPeaks(Ffit.peaks, ...
    cfg.F1s.classification_boundaries_eV);
comp = xps.calculateComposition(Cfit.peaks, Ffit.peaks, ...
    cfg.sensitivity_factors.C1s, cfg.sensitivity_factors.F1s, 0);

% Acceptance tolerances are set before execution. The 0.04 eV center and
% 0.10 eV FWHM limits are small relative to the narrowest 0.5 eV center
% range and 0.75--2.0 eV width bounds; 8% area tolerance allows for the
% configured AsLS subtraction, while demanding accurate recovery.
centerTol_eV = 0.04;
fwhmTol_eV = 0.10;
relativeAreaTol = 0.08;
minR2 = 0.995;

verifyEqual(testCase, C.energyDirection, -1);
verifyEqual(testCase, F.energyDirection, -1);
verifyTrue(testCase, issorted(Cpre.energy));
verifyTrue(testCase, issorted(Fpre.energy));
verifyEqual(testCase, string({Cfit.peaks.id}), configuredPeakIds(cfg.C1s.peaks));
verifyEqual(testCase, sort(string({Ffit.peaks.id})), ...
    sort(configuredPeakIds(cfg.F1s.peaks)));

verifyLessThanOrEqual(testCase, max(abs([Cfit.peaks.center_eV] - cTruth(:,1).')), centerTol_eV);
verifyLessThanOrEqual(testCase, max(abs([Ffit.peaks.center_eV] - fTruth(:,1).')), centerTol_eV);
verifyLessThanOrEqual(testCase, max(abs([Cfit.peaks.FWHM_eV] - cTruth(:,3).')), fwhmTol_eV);
verifyLessThanOrEqual(testCase, max(abs([Ffit.peaks.FWHM_eV] - fTruth(:,3).')), fwhmTol_eV);

% Fit areas are in normalized preprocessing units. Account for both the
% synthetic raw acquisition multiplier and each region's max normalization.
cExpectedAreas = cAcquisitionScale * cTruth(:,2).' / Cpre.scale;
fExpectedAreas = fAcquisitionScale * fTruth(:,2).' / Fpre.scale;
cAreaErrors = relativeError([Cfit.peaks.area], cExpectedAreas);
fAreaErrors = relativeError([Ffit.peaks.area], fExpectedAreas);
verifyLessThanOrEqual(testCase, max(cAreaErrors), relativeAreaTol, ...
    areaDiagnostic("C1s", cExpectedAreas, [Cfit.peaks.area], cAreaErrors, Cpre));
verifyLessThanOrEqual(testCase, max(fAreaErrors), relativeAreaTol, ...
    areaDiagnostic("F1s", fExpectedAreas, [Ffit.peaks.area], fAreaErrors, Fpre));
verifyGreaterThanOrEqual(testCase, Cfit.metrics.R2, minR2, ...
    fitDiagnostic("C1s", Cfit, Cpre));
verifyGreaterThanOrEqual(testCase, Ffit.metrics.R2, minR2, ...
    fitDiagnostic("F1s", Ffit, Fpre));

% Position classification must be independent of peak array order.
verifyEqual(testCase, string({Ffit.peaks.chemical_assignment}), ...
    ["ionic_or_substrate_bound_F", "semi_covalent_F_C", "covalent_F_C"]);
verifyEqual(testCase, [Ffit.peaks.include_in_carbon_bound_F], [false true true]);
verifyEqual(testCase, [Ffit.peaks.include_in_total_F], [true true true]);

% The C-only composition paths are scale-invariant and therefore have
% known truth in this independently normalized pipeline.
cAreas = cTruth(:,2).';
expectedWeightedFC = (cAreas(3) + 2*cAreas(5) + 3*cAreas(6)) / sum(cAreas);
expectedLegacyFC = ((sum(cAreas) - cAreas(1)) / sum(cAreas)) / 3;
verifyEqual(testCase, comp.weighted.F_over_C, expectedWeightedFC, "RelTol", relativeAreaTol);
verifyEqual(testCase, comp.legacy.F_over_C, expectedLegacyFC, "RelTol", relativeAreaTol);
verifyNotEqual(testCase, Cpre.scale, Fpre.scale);
verifyEqual(testCase, comp.crossRegionAreaScaleStatus, ...
    "caller must restore any independent preprocessing scales before using F1s/C1s ratios physically");
end

function y = syntheticGaussianSum(energy, truth)
y = zeros(size(energy));
for i = 1:size(truth,1)
    center = truth(i,1);
    area = truth(i,2);
    fwhm = truth(i,3);
    sigma = fwhm/(2*sqrt(2*log(2)));
    y = y + area/(sigma*sqrt(2*pi)) .* exp(-0.5*((energy-center)/sigma).^2);
end
end

function values = relativeError(actual, expected)
values = abs(actual - expected) ./ expected;
end

function message = areaDiagnostic(region, expected, recovered, errors, pre)
message = sprintf(['%s normalized expected areas=%s; recovered areas=%s; ' ...
    'relative errors=%s; AsLS background range=[%.6g, %.6g].'], ...
    region, mat2str(expected, 6), mat2str(recovered, 6), mat2str(errors, 6), ...
    min(pre.background), max(pre.background));
end

function message = fitDiagnostic(region, fit, pre)
message = sprintf(['%s R2=%.8f; RMSE=%.6g; fitted range=[%.6g, %.6g]; ' ...
    'preprocessed fit-signal range=[%.6g, %.6g]; AsLS background range=[%.6g, %.6g].'], ...
    region, fit.metrics.R2, fit.metrics.RMSE, min(fit.fitted), max(fit.fitted), ...
    min(pre.y_fit), max(pre.y_fit), min(pre.background), max(pre.background));
end

function ids = configuredPeakIds(peaksCfg)
if iscell(peaksCfg)
ids = string(cellfun(@(peak) peak.id, peaksCfg, "UniformOutput", false));
else
    ids = string({peaksCfg.id});
end
ids = reshape(ids, 1, []);
end

function deleteIfPresent(files)
for i = 1:numel(files)
    if isfile(files{i})
        delete(files{i});
    end
end
end
