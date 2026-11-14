function tests = testReferenceData
%TESTREFERENCEDATA Versioned reference-only Ruoff A-C fixtures.

tests = functiontests(localfunctions);
end

function testSampleARuoffReference(testCase)
ref = loadSample("A");
peaks = asStructArray(ref.direct_references.C1s_normal_emission.peaks);
verifyTrue(testCase,ref.direct_references.C1s_normal_emission.fractions_complete);
verifyEqual(testCase,string({peaks.id}), ...
    ["sp2_C_C","C_CF_sp3","C_CF23_C_O","C_F","CF2","CF3"]);
verifyEqual(testCase,[peaks.center_eV], ...
    [284.2,285.2,287.3,288.1,290.8,292.6],"AbsTol",0);
verifyEqual(testCase,[peaks.fraction_percent],[6,41,3,47,2,1],"AbsTol",0);
refs = ref.direct_references.model_specific_fluorine_atomic_percent;
verifyEqual(testCase,refs.ruoff_c1s_main_cf_v1.value,32);
verifyEqual(testCase,refs.ruoff_c1s_f1s_semi_sf3p95_v1.value,32);
verifyEqual(testCase,string(ref.direct_references.qualitative_stoichiometry), ...
    "essentially C2F");
verifyEqual(testCase,ref.direct_references.main_C_F_fraction.fraction,0.47);
end

function testSamplesBCDoNotInventMissingPeakBreakdowns(testCase)
for sampleID = ["B","C"]
    ref = loadSample(sampleID);
    verifyFalse(testCase, ...
        ref.direct_references.C1s_normal_emission.fractions_complete);
    verifyEmpty(testCase,ref.direct_references.C1s_normal_emission.peaks);
    verifyTrue(testCase,contains(string( ...
        ref.direct_references.C1s_normal_emission.availability_note), ...
        "no missing values are inferred"));
end
end

function testModelSpecificReferencesAndDerivedValuesAreSeparate(testCase)
expectedMainLower = [32,26,16];
expectedMainUpper = [32,27,16];
expectedSemi = [32,25,15];
expectedMainFraction = [0.47,0.37,0.19];
for i = 1:3
    sampleID = string(char('A'+i-1));
    ref = loadSample(sampleID);
    refs = ref.direct_references.model_specific_fluorine_atomic_percent;
    [lower,upper] = bounds(refs.ruoff_c1s_main_cf_v1);
    verifyEqual(testCase,[lower upper], ...
        [expectedMainLower(i) expectedMainUpper(i)],"AbsTol",0);
    verifyEqual(testCase,refs.ruoff_c1s_f1s_semi_sf3p95_v1.value, ...
        expectedSemi(i),"AbsTol",0);
    verifyNotEmpty(testCase,refs.ruoff_c1s_main_cf_v1.provenance);
    verifyNotEmpty(testCase, ...
        refs.ruoff_c1s_f1s_semi_sf3p95_v1.provenance);
    verifyEqual(testCase,ref.direct_references.main_C_F_fraction.fraction, ...
        expectedMainFraction(i),"AbsTol",0);
    verifyTrue(testCase,isfield(ref,"model_applied_to_reference"));
end
end

function testReferenceBenchmarkArithmetic(testCase)
summary = validateRuoffBenchmarkFixtures;
verifyEqual(testCase,summary.MainCF_FAt_pct, ...
    [31.97278911564626;27.00729927007299;15.96638655462185], ...
    "AbsTol",1e-10);
verifyEqual(testCase,summary.MainCF_SignedDistanceToReference_pctpt, ...
    [-0.02721088435374;0.00729927007299;-0.03361344537815], ...
    "AbsTol",1e-10);
verifyEqual(testCase,summary.SemiF1s_FAt_pct, ...
    [30.84466328699906;24.6662790919073;14.922210169369464], ...
    "AbsTol",1e-10);
verifyEqual(testCase,summary.SemiF1s_SignedDistanceToReference_pctpt, ...
    [-1.15533671300094;-0.33372090809270;-0.07778983063054], ...
    "AbsTol",1e-10);
end

function [lower,upper] = bounds(reference)
if string(reference.reference_type) == "scalar"
    lower = reference.value;
    upper = reference.value;
else
    lower = reference.lower;
    upper = reference.upper;
end
end

function ref = loadSample(sampleID)
projectFolder = fileparts(mfilename("fullpath"));
ref = xps.loadReference(fullfile(projectFolder,"reference", ...
    "sample_" + sampleID + "_ruoff_v1.json"));
end

function values = asStructArray(values)
if iscell(values)
    values = [values{:}];
end
end
