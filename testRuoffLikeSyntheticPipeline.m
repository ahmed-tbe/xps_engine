function tests = testRuoffLikeSyntheticPipeline
%TESTRUOFFLIKESYNTHETICPIPELINE Exact reference-derived synthetic recovery.

tests = functiontests(localfunctions);
end

function testReferenceDerivedNoiseFreeProductionChain(testCase)
report = runRuoffLikeSyntheticPipelineDemo(false,false);

verifyEqual(testCase,string(report.configuration.usage), ...
    "test_only_not_a_production_candidate");
verifyEqual(testCase,report.Cpre.background_method,"linear");
verifyEqual(testCase,report.Fpre.background_method,"linear");
verifyTrue(testCase,report.acceptance.passes);
verifyGreaterThanOrEqual(testCase,report.Cfit.metrics.R2, ...
    report.acceptance.minimumR2);
verifyGreaterThanOrEqual(testCase,report.Ffit.metrics.R2, ...
    report.acceptance.minimumR2);

verifyLessThanOrEqual(testCase,report.acceptance.maxC1sCenterError_eV, ...
    report.acceptance.centerTolerance_eV);
verifyLessThanOrEqual(testCase,report.acceptance.maxC1sAreaError, ...
    report.acceptance.relativeAreaTolerance);
verifyLessThanOrEqual(testCase,report.acceptance.maxF1sCenterError_eV, ...
    report.acceptance.centerTolerance_eV);
verifyLessThanOrEqual(testCase,report.acceptance.maxF1sAreaError, ...
    report.acceptance.relativeAreaTolerance);

verifyEqual(testCase,report.C1sRecovery.RuoffDerivedSyntheticTruthFraction_pct, ...
    [6;41;47;3;2;1],"AbsTol",0);
verifyEqual(testCase,report.C1sRecovery.RuoffDerivedSyntheticTruthCenter_eV, ...
    [284.2;285.2;288.1;287.3;290.8;292.6],"AbsTol",0);
verifyEqual(testCase,string({report.Ffit.peaks.chemical_assignment}), ...
    ["ionic_or_substrate_bound_F","semi_covalent_F_C","covalent_F_C"]);
verifyFalse(testCase,any(string({report.Ffit.peaks.id}) == "F_other"));

% The generator areas are not fit targets: production initialization uses
% its equal-area heuristic even though the reference-derived areas differ.
verifyEqual(testCase,numel(unique([report.Cfit.peaks.initial_area])),1);
verifyGreaterThan(testCase,numel(unique(report.cSyntheticTruth(:,2))),1);

verifyTrue(testCase,report.composition.crossRegionValid);
verifyLessThanOrEqual(testCase, ...
    max(report.crossRegionRecovery.F_over_C_RelativeError_pct),2);
verifyLessThanOrEqual(testCase, ...
    max(report.crossRegionRecovery.C_over_F_RelativeError_pct),2);
end

function testC1sFormulaArithmeticFromPublishedFractions(testCase)
report = runRuoffLikeSyntheticPipelineDemo(false,false);
T = report.C1sFormulaConsistency;

direct = T(T.CandidateOrReference == "RuoffSampleA_main_cf_reference",:);
weighted = T(T.CandidateOrReference == "WeightedC1s",:);
legacy = T(T.CandidateOrReference == "LegacyC1s",:);

verifyEqual(testCase,direct.QuantityClass,"DirectRuoffReference");
verifyEqual(testCase,direct.F_atpct,32,"AbsTol",0);
verifyEqual(testCase,direct.CxF,"essentially C2F");
verifyTrue(testCase,isnan(direct.F_over_C));

verifyEqual(testCase,weighted.QuantityClass, ...
    "ModelAppliedToRuoffPublishedFractions");
verifyEqual(testCase,weighted.Alpha,0,"AbsTol",0);
verifyEqual(testCase,weighted.F_over_C,0.54,"AbsTol",1e-12);
verifyEqual(testCase,weighted.F_atpct,35.0649350649351, ...
    "AbsTol",1e-12);
verifyEqual(testCase,weighted.C_over_F,1.85185185185185, ...
    "AbsTol",1e-12);
verifyEqual(testCase,weighted.CxF,"C1.85F");
verifyEqual(testCase,weighted.DifferenceFrom32atpct_pp, ...
    3.0649350649351,"AbsTol",1e-12);

verifyEqual(testCase,legacy.QuantityClass, ...
    "ModelAppliedToRuoffPublishedFractions");
verifyTrue(testCase,isnan(legacy.Alpha));
verifyEqual(testCase,legacy.F_over_C,0.313333333333333, ...
    "AbsTol",1e-12);
verifyEqual(testCase,legacy.F_atpct,23.8578680203046, ...
    "AbsTol",1e-12);
verifyEqual(testCase,legacy.C_over_F,3.19148936170213, ...
    "AbsTol",1e-12);
verifyEqual(testCase,legacy.CxF,"C3.19F");
verifyEqual(testCase,legacy.DifferenceFrom32atpct_pp, ...
    -8.14213197969543,"AbsTol",1e-12);
end

function testLegacyConflictRemainsIsolated(testCase)
projectFolder = fileparts(mfilename("fullpath"));
legacy = jsondecode(fileread(fullfile(projectFolder,"config", ...
    "legacy_current_v1.json")));
testCfg = jsondecode(fileread(fullfile(projectFolder,"config","test", ...
    "ruoff_like_sample_A_synthetic_v1.json")));
legacyPeak = peakById(legacy.C1s.peaks,"C_CF23_C_O");
testPeak = peakById(testCfg.C1s.peaks,"C_CF23_C_O");

verifyEqual(testCase,legacyPeak.center_bounds_eV(:).',[288.1 289.5],"AbsTol",0);
verifyGreaterThan(testCase,287.3, testPeak.center_bounds_eV(1));
verifyLessThan(testCase,287.3, testPeak.center_bounds_eV(2));
verifyTrue(testCase,testPeak.test_only_reference_bound_override);
end

function peak = peakById(peaks,id)
for i = 1:numel(peaks)
    if iscell(peaks)
        candidate = peaks{i};
    else
        candidate = peaks(i);
    end
    if string(candidate.id) == id
        peak = candidate;
        return;
    end
end
error("testRuoffLikeSyntheticPipeline:MissingPeak", ...
    "Peak '%s' not found.",id);
end
