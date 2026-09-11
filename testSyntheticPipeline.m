function tests = testSyntheticPipeline
%TESTSYNTHETICPIPELINE Phase 0G-3 deterministic end-to-end validation.
%
% The background is explicit in every case. Linear is the zero-background
% truth-matched acceptance case. The current AsLS default remains a
% separate known-failure diagnostic regression; its thresholds are not
% loosened and its production parameters are not changed.

tests = functiontests(localfunctions);
end

function testLinearZeroBackgroundProductionChainPasses(testCase)
result = runSyntheticCase("linear");
acceptance = evaluateAcceptance(result);

verifyEqual(testCase, result.Cpre.background_method, "linear");
verifyEqual(testCase, result.Fpre.background_method, "linear");
verifyEqual(testCase, result.C.energyDirection, -1);
verifyEqual(testCase, result.F.energyDirection, -1);
verifyTrue(testCase, issorted(result.Cpre.energy));
verifyTrue(testCase, issorted(result.Fpre.energy));
verifyEqual(testCase, string({result.Cfit.peaks.id}), ...
    configuredPeakIds(result.cfg.C1s.peaks));
verifyEqual(testCase, sort(string({result.Ffit.peaks.id})), ...
    sort(configuredPeakIds(result.cfg.F1s.peaks)));

verifyLessThanOrEqual(testCase, acceptance.maxC1sCenterError_eV, ...
    acceptance.centerTolerance_eV);
verifyLessThanOrEqual(testCase, acceptance.maxF1sCenterError_eV, ...
    acceptance.centerTolerance_eV);
verifyLessThanOrEqual(testCase, acceptance.maxC1sFWHMError_eV, ...
    acceptance.fwhmTolerance_eV);
verifyLessThanOrEqual(testCase, acceptance.maxF1sFWHMError_eV, ...
    acceptance.fwhmTolerance_eV);
verifyLessThanOrEqual(testCase, acceptance.maxC1sAreaError, ...
    acceptance.relativeAreaTolerance, areaDiagnostic(result, "C1s"));
verifyLessThanOrEqual(testCase, acceptance.maxF1sAreaError, ...
    acceptance.relativeAreaTolerance, areaDiagnostic(result, "F1s"));
verifyGreaterThanOrEqual(testCase, result.Cfit.metrics.R2, ...
    acceptance.minimumR2, fitDiagnostic(result, "C1s"));
verifyGreaterThanOrEqual(testCase, result.Ffit.metrics.R2, ...
    acceptance.minimumR2, fitDiagnostic(result, "F1s"));
verifyTrue(testCase, acceptance.passes);

verifyEqual(testCase, string({result.Ffit.peaks.chemical_assignment}), ...
    ["ionic_or_substrate_bound_F", "semi_covalent_F_C", "covalent_F_C"]);
verifyEqual(testCase, [result.Ffit.peaks.include_in_carbon_bound_F], ...
    [false true true]);
verifyEqual(testCase, [result.Ffit.peaks.include_in_total_F], ...
    [true true true]);
verifyEqual(testCase,result.fSyntheticTruth(:,1),[684.7;686.7;688.2], ...
    "AbsTol",0);
verifyFalse(testCase,any(string({result.Ffit.peaks.id}) == "F_other"));

% C1s-only artificial synthetic truth (not Ruoff reference data).
cAreas = result.cSyntheticTruth(:,2).';
expectedWeightedFC = (cAreas(3)+2*cAreas(5)+3*cAreas(6))/sum(cAreas);
expectedLegacyFC = ((sum(cAreas)-cAreas(1))/sum(cAreas))/3;
verifyEqual(testCase, result.comp.weighted.F_over_C, expectedWeightedFC, ...
    "RelTol", acceptance.relativeAreaTolerance);
verifyEqual(testCase, result.comp.legacy.F_over_C, expectedLegacyFC, ...
    "RelTol", acceptance.relativeAreaTolerance);

% Phase 0G-4: software normalization and known synthetic acquisition
% multipliers are both reversed before sensitivity correction.
fAreas = result.fSyntheticTruth(:,2).';
SC = result.cfg.sensitivity_factors.C1s;
SF = result.cfg.sensitivity_factors.F1s;
expectedCarbonBoundFC = (sum(fAreas(2:3))/SF)/(sum(cAreas)/SC);
expectedTotalFC = (sum(fAreas)/SF)/(sum(cAreas)/SC);
verifyTrue(testCase, result.comp.crossRegionValid);
verifyEqual(testCase, result.comp.carbonBound.F_over_C, ...
    expectedCarbonBoundFC, "RelTol", acceptance.relativeAreaTolerance);
verifyEqual(testCase, result.comp.totalF.F_over_C, ...
    expectedTotalFC, "RelTol", acceptance.relativeAreaTolerance);
verifyNotEqual(testCase, result.Cpre.softwareNormalizationScale, ...
    result.Fpre.softwareNormalizationScale);
end

function testAsLSDefaultKnownFailureDiagnostic(testCase)
result = runSyntheticCase("asls");
acceptance = evaluateAcceptance(result);

verifyEqual(testCase, result.Cpre.background_method, "asls");
verifyEqual(testCase, result.Cpre.background_parameters.lambda, 1e6, ...
    "AbsTol", 0);
verifyEqual(testCase, result.Cpre.background_parameters.p, 0.01, ...
    "AbsTol", 0);
verifyEqual(testCase, result.Cpre.background_parameters.iterations, 20, ...
    "AbsTol", 0);
verifyFalse(testCase, acceptance.passes, sprintf([ ...
    'AsLS-default diagnostic unexpectedly met every 0G-3 criterion. ' ...
    'C area error=%.6g; C R2=%.8f. Review before changing this regression.'], ...
    acceptance.maxC1sAreaError, result.Cfit.metrics.R2));
verifyTrue(testCase, acceptance.maxC1sAreaError > ...
    acceptance.relativeAreaTolerance || ...
    result.Cfit.metrics.R2 < acceptance.minimumR2);
end

function result = runSyntheticCase(backgroundMethod)
projectFolder = fileparts(mfilename("fullpath"));
cfg = jsondecode(fileread(fullfile(projectFolder, "config", ...
    "legacy_current_v1.json")));
cfg.preprocessing.background = backgroundMethod;

% Noise-free artificial plumbing/recovery truth. These values are not
% Ruoff reference values. All parameters are strictly inside configured
% bounds and the true additive background is exactly zero.
cSyntheticTruth = [ ...
    284.15 0.50 0.80; ... % sp2_C_C
    285.55 0.50 0.80; ... % C_CF_sp3
    287.40 0.50 0.80; ... % C_F
    289.30 0.50 0.80; ... % C_CF23_C_O
    291.40 0.50 0.80; ... % CF2
    293.50 0.50 0.80];   % CF3
fSyntheticTruth = [ ...
    684.70 0.60 0.80; ... % ionic/substrate-bound F
    686.70 0.60 0.80; ... % semi-covalent F-C
    688.20 0.60 0.80];   % covalent F-C

cEnergy = linspace(280, 297, 681).';
fEnergy = linspace(678, 693, 601).';
cAcquisitionScale = 2.0;
fAcquisitionScale = 13.0;
cRaw = cAcquisitionScale*syntheticGaussianSum(cEnergy, cSyntheticTruth);
fRaw = fAcquisitionScale*syntheticGaussianSum(fEnergy, fSyntheticTruth);

cFile = [tempname(tempdir) '.txt'];
fFile = [tempname(tempdir) '.txt'];
cleanupFiles = onCleanup(@() deleteIfPresent({cFile, fFile}));
writematrix([flipud(cEnergy) flipud(cRaw)], cFile, "Delimiter", "tab");
writematrix([flipud(fEnergy) flipud(fRaw)], fFile, "Delimiter", "tab");

C = xps.readSpectrum(cFile);
F = xps.readSpectrum(fFile);
Cpre = xps.preprocessSpectrum(C, cfg.preprocessing);
Fpre = xps.preprocessSpectrum(F, cfg.preprocessing);
Cfit = xps.fitSpectrum(Cpre.energy, Cpre.y_fit, cfg.C1s, ...
    string(cfg.peak_shape));
Ffit = xps.fitSpectrum(Fpre.energy, Fpre.y_fit, cfg.F1s, ...
    string(cfg.peak_shape));
Ffit.peaks = xps.classifyF1sPeaks(Ffit.peaks, ...
    cfg.F1s.classification_boundaries_eV);

syntheticAcquisition.C1s = struct("known", true, ...
    "scale_factor", cAcquisitionScale, "provenance", "synthetic truth");
syntheticAcquisition.F1s = struct("known", true, ...
    "scale_factor", fAcquisitionScale, "provenance", "synthetic truth");
scaling = xps.buildQuantificationScaling(Cpre, Fpre, syntheticAcquisition);
comp = xps.calculateComposition(Cfit.peaks, Ffit.peaks, ...
    cfg.sensitivity_factors.C1s, cfg.sensitivity_factors.F1s, ...
    cfg.composition.alpha_ambiguous, scaling);

result = struct("cfg", cfg, "C", C, "F", F, "Cpre", Cpre, ...
    "Fpre", Fpre, "Cfit", Cfit, "Ffit", Ffit, "comp", comp, ...
    "scaling", scaling, "cSyntheticTruth", cSyntheticTruth, ...
    "fSyntheticTruth", fSyntheticTruth, ...
    "cAcquisitionScale", cAcquisitionScale, ...
    "fAcquisitionScale", fAcquisitionScale);
end

function acceptance = evaluateAcceptance(result)
acceptance.centerTolerance_eV = 0.04;
acceptance.fwhmTolerance_eV = 0.10;
acceptance.relativeAreaTolerance = 0.08;
acceptance.minimumR2 = 0.995;

cExpectedAreas = result.cAcquisitionScale*result.cSyntheticTruth(:,2).' / ...
    result.Cpre.softwareNormalizationScale;
fExpectedAreas = result.fAcquisitionScale*result.fSyntheticTruth(:,2).' / ...
    result.Fpre.softwareNormalizationScale;
acceptance.cExpectedAreas = cExpectedAreas;
acceptance.fExpectedAreas = fExpectedAreas;
acceptance.cAreaErrors = relativeError([result.Cfit.peaks.area], cExpectedAreas);
acceptance.fAreaErrors = relativeError([result.Ffit.peaks.area], fExpectedAreas);
acceptance.maxC1sAreaError = max(acceptance.cAreaErrors);
acceptance.maxF1sAreaError = max(acceptance.fAreaErrors);
acceptance.maxC1sCenterError_eV = max(abs( ...
    [result.Cfit.peaks.center_eV]-result.cSyntheticTruth(:,1).'));
acceptance.maxF1sCenterError_eV = max(abs( ...
    [result.Ffit.peaks.center_eV]-result.fSyntheticTruth(:,1).'));
acceptance.maxC1sFWHMError_eV = max(abs( ...
    [result.Cfit.peaks.FWHM_eV]-result.cSyntheticTruth(:,3).'));
acceptance.maxF1sFWHMError_eV = max(abs( ...
    [result.Ffit.peaks.FWHM_eV]-result.fSyntheticTruth(:,3).'));

acceptance.passes = ...
    acceptance.maxC1sCenterError_eV <= acceptance.centerTolerance_eV && ...
    acceptance.maxF1sCenterError_eV <= acceptance.centerTolerance_eV && ...
    acceptance.maxC1sFWHMError_eV <= acceptance.fwhmTolerance_eV && ...
    acceptance.maxF1sFWHMError_eV <= acceptance.fwhmTolerance_eV && ...
    acceptance.maxC1sAreaError <= acceptance.relativeAreaTolerance && ...
    acceptance.maxF1sAreaError <= acceptance.relativeAreaTolerance && ...
    result.Cfit.metrics.R2 >= acceptance.minimumR2 && ...
    result.Ffit.metrics.R2 >= acceptance.minimumR2;
end

function y = syntheticGaussianSum(energy, truth)
y = zeros(size(energy));
for i = 1:size(truth,1)
    sigma = truth(i,3)/(2*sqrt(2*log(2)));
    y = y + truth(i,2)/(sigma*sqrt(2*pi)) .* ...
        exp(-0.5*((energy-truth(i,1))/sigma).^2);
end
end

function values = relativeError(actual, expected)
values = abs(actual-expected)./expected;
end

function message = areaDiagnostic(result, region)
acceptance = evaluateAcceptance(result);
if region == "C1s"
    pre = result.Cpre; fit = result.Cfit;
    expected = acceptance.cExpectedAreas; errors = acceptance.cAreaErrors;
else
    pre = result.Fpre; fit = result.Ffit;
    expected = acceptance.fExpectedAreas; errors = acceptance.fAreaErrors;
end
message = sprintf(['%s %s expected fit areas=%s; recovered=%s; ' ...
    'relative errors=%s; background range=[%.6g, %.6g].'], ...
    char(region), char(pre.background_method), mat2str(expected,6), ...
    mat2str([fit.peaks.area],6), mat2str(errors,6), ...
    min(pre.background), max(pre.background));
end

function message = fitDiagnostic(result, region)
if region == "C1s"
    pre = result.Cpre; fit = result.Cfit;
else
    pre = result.Fpre; fit = result.Ffit;
end
message = sprintf(['%s %s R2=%.8f; RMSE=%.6g; fit signal ' ...
    'range=[%.6g, %.6g]; background range=[%.6g, %.6g].'], ...
    char(region), char(pre.background_method), fit.metrics.R2, fit.metrics.RMSE, ...
    min(pre.y_fit), max(pre.y_fit), min(pre.background), max(pre.background));
end

function ids = configuredPeakIds(peaksCfg)
if iscell(peaksCfg)
    ids = string(cellfun(@(peak) peak.id, peaksCfg, "UniformOutput", false));
else
    ids = string({peaksCfg.id});
end
ids = reshape(ids,1,[]);
end

function deleteIfPresent(files)
for i = 1:numel(files)
    if isfile(files{i})
        delete(files{i});
    end
end
end
