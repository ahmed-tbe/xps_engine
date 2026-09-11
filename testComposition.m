function tests = testComposition
%TESTCOMPOSITION Deterministic Phase 0G-2 tests for composition math.
%
% Inputs have analytically known expected values. These tests call the
% production composition function rather than duplicating its equations.

tests = functiontests(localfunctions);
end

function testWeightedC1sFC(testCase)
comp = xps.calculateComposition(makeCPeaks(), makeFPeaks(), ...
    1, 4.4118, 0, knownUnitScaling());
verifyEqual(testCase, comp.weighted.F_over_C, 0.85, "AbsTol", 1e-12);
end

function testLegacyC1sFC(testCase)
comp = xps.calculateComposition(makeCPeaks(), makeFPeaks(), ...
    1, 4.4118, 0, knownUnitScaling());
verifyEqual(testCase, comp.legacy.F_over_C, 0.30, "AbsTol", 1e-12);
end

function testCxFConversion(testCase)
comp = xps.calculateComposition(makeCPeaks(), makeFPeaks(), ...
    1, 4.4118, 0, knownUnitScaling());
verifyEqual(testCase, comp.weighted.C_over_F, 1/0.85, "AbsTol", 1e-12);
% CxF is intentionally returned as a MATLAB string by ratioFields.
verifyEqual(testCase, comp.weighted.CxF, "C1.18F");
end

function testAmbiguousPeakCoefficient(testCase)
comp = xps.calculateComposition(makeCPeaks(), makeFPeaks(), ...
    1, 4.4118, 1.5, knownUnitScaling());
verifyEqual(testCase, comp.weighted.F_over_C, 1.00, "AbsTol", 1e-12);
end

function testPeakOrderInvariance(testCase)
cPeaks = makeCPeaks();
fPeaks = makeFPeaks();
baseline = xps.calculateComposition(cPeaks, fPeaks, ...
    1, 4.4118, 0, knownUnitScaling());

shuffled = xps.calculateComposition(cPeaks([6 3 1 5 2 4]), ...
    fPeaks([2 1]), 1, 4.4118, 0, knownUnitScaling());

verifyEqual(testCase, shuffled.legacy.F_over_C, baseline.legacy.F_over_C, "AbsTol", 1e-12);
verifyEqual(testCase, shuffled.weighted.F_over_C, baseline.weighted.F_over_C, "AbsTol", 1e-12);
verifyEqual(testCase, shuffled.weighted.C_over_F, baseline.weighted.C_over_F, "AbsTol", 1e-12);
verifyEqual(testCase, shuffled.carbonBound.F_over_C, baseline.carbonBound.F_over_C, "AbsTol", 1e-12);
verifyEqual(testCase, shuffled.totalF.F_over_C, baseline.totalF.F_over_C, "AbsTol", 1e-12);
end

function testSensitivityFactorArithmetic(testCase)
comp = xps.calculateComposition(makeCPeaks(), makeFPeaks(), ...
    1, 4.4118, 0, knownUnitScaling());
expected = (100/4.4118)/(100/1);
verifyEqual(testCase, comp.carbonBound.F_over_C, expected, "AbsTol", 1e-12);
verifyEqual(testCase, comp.totalF.F_over_C, expected, "AbsTol", 1e-12);
end

function testMissingScalingWithholdsCrossRegionResults(testCase)
comp = xps.calculateComposition(makeCPeaks(), makeFPeaks(), 1, 4.4118, 0);
verifyFalse(testCase, comp.crossRegionValid);
verifyTrue(testCase, isnan(comp.carbonBound.F_over_C));
verifyTrue(testCase, isnan(comp.totalF.F_over_C));
verifyTrue(testCase, contains(comp.crossRegionAreaScaleStatus, ...
    "not physically validated"));
end

function peaks = makeCPeaks
% Total C area = 100; weighted F numerator (alpha=0) = 85.
ids = {"sp2_C_C", "C_CF_sp3", "C_F", "C_CF23_C_O", "CF2", "CF3"};
areas = [10 20 40 10 15 5];
peaks = repmat(struct("id", "", "area", 0), 1, numel(ids));
for i = 1:numel(ids)
    peaks(i).id = ids{i};
    peaks(i).area = areas(i);
end
end

function peaks = makeFPeaks
peaks = struct( ...
    "id", {"carbon_bound", "other_F"}, ...
    "area", {100, 0}, ...
    "include_in_carbon_bound_F", {true, false}, ...
    "include_in_total_F", {true, true});
end

function scaling = knownUnitScaling
region = struct("softwareNormalizationScale", 1, ...
    "acquisitionScaleKnown", true, "acquisitionScale", 1);
scaling = struct("C1s", region, "F1s", region);
end
