function tests = testCrossRegionScaling
%TESTCROSSREGIONSCALING Assertive Phase 0G-4 area-scale validation.

tests = functiontests(localfunctions);
end

function testPhysicalRatiosInvariantToSoftwareNormalization(testCase)
physicalCAreas = [4, 6, 10, 5, 3, 2];
physicalFAreas = [4, 8, 12];
SC = 1.0;
SF = 4.0;
cAcquisitionScale = 2.5;
fAcquisitionScale = 7.0;

caseOne = calculateForScales(physicalCAreas, physicalFAreas, ...
    5.0, 11.0, cAcquisitionScale, fAcquisitionScale, SC, SF);
caseTwo = calculateForScales(physicalCAreas, physicalFAreas, ...
    17.0, 3.0, cAcquisitionScale, fAcquisitionScale, SC, SF);

expectedCarbonBound = ((8+12)/SF)/(sum(physicalCAreas)/SC);
expectedTotal = (sum(physicalFAreas)/SF)/(sum(physicalCAreas)/SC);

verifyTrue(testCase, caseOne.crossRegionValid);
verifyTrue(testCase, caseTwo.crossRegionValid);
verifyEqual(testCase, caseOne.carbonBound.F_over_C, expectedCarbonBound, ...
    "AbsTol", 1e-12);
verifyEqual(testCase, caseOne.totalF.F_over_C, expectedTotal, ...
    "AbsTol", 1e-12);
verifyEqual(testCase, caseTwo.carbonBound.F_over_C, ...
    caseOne.carbonBound.F_over_C, "AbsTol", 1e-12);
verifyEqual(testCase, caseTwo.totalF.F_over_C, ...
    caseOne.totalF.F_over_C, "AbsTol", 1e-12);
verifyEqual(testCase, caseTwo.areas.A_Cfilm_physical, ...
    sum(physicalCAreas), "AbsTol", 1e-12);
verifyEqual(testCase, caseTwo.areas.A_F_total_physical, ...
    sum(physicalFAreas), "AbsTol", 1e-12);
end

function testUnknownAcquisitionScaleIsNotAssumedUnity(testCase)
preC = struct("softwareNormalizationScale", 5);
preF = struct("softwareNormalizationScale", 11);
cfg.C1s = struct("known", false, "scale_factor", [], ...
    "provenance", "unknown in test");
cfg.F1s = struct("known", false, "scale_factor", [], ...
    "provenance", "unknown in test");
scaling = xps.buildQuantificationScaling(preC, preF, cfg);
comp = xps.calculateComposition(makeCPeaks(ones(1,6)), ...
    makeFPeaks(ones(1,3)), 1, 4, 0, scaling);

verifyFalse(testCase, scaling.validForCrossRegion);
verifyFalse(testCase, comp.crossRegionValid);
verifyTrue(testCase, isnan(comp.carbonBound.F_over_C));
verifyTrue(testCase, isnan(comp.totalF.F_over_C));
end

function comp = calculateForScales(cPhysical, fPhysical, cSoftware, ...
        fSoftware, cAcquisition, fAcquisition, SC, SF)
cFitAreas = cPhysical*cAcquisition/cSoftware;
fFitAreas = fPhysical*fAcquisition/fSoftware;
preC = struct("softwareNormalizationScale", cSoftware);
preF = struct("softwareNormalizationScale", fSoftware);
cfg.C1s = struct("known", true, "scale_factor", cAcquisition, ...
    "provenance", "synthetic truth");
cfg.F1s = struct("known", true, "scale_factor", fAcquisition, ...
    "provenance", "synthetic truth");
scaling = xps.buildQuantificationScaling(preC, preF, cfg);
comp = xps.calculateComposition(makeCPeaks(cFitAreas), ...
    makeFPeaks(fFitAreas), SC, SF, 0, scaling);
end

function peaks = makeCPeaks(areas)
ids = {"sp2_C_C", "C_CF_sp3", "C_F", "C_CF23_C_O", "CF2", "CF3"};
peaks = repmat(struct("id", "", "area", 0), 1, numel(ids));
for i = 1:numel(ids)
    peaks(i).id = ids{i};
    peaks(i).area = areas(i);
end
end

function peaks = makeFPeaks(areas)
peaks = struct( ...
    "id", {"F_ionic", "F_semi", "F_covalent"}, ...
    "area", num2cell(areas), ...
    "include_in_carbon_bound_F", {false, true, true}, ...
    "include_in_total_F", {true, true, true});
end
