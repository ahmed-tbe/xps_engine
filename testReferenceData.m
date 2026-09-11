function tests = testReferenceData
%TESTREFERENCEDATA Reference-only Sample A schema and values.

tests = functiontests(localfunctions);
end

function testSampleARuoffReference(testCase)
projectFolder = fileparts(mfilename("fullpath"));
ref = xps.loadReference(fullfile(projectFolder, "reference", ...
    "sample_A_ruoff_v1.json"));

peaks = asStructArray(ref.direct_references.C1s_normal_emission.peaks);
verifyEqual(testCase, string({peaks.id}), ...
    ["sp2_C_C", "C_CF_sp3", "C_CF23_C_O", "C_F", "CF2", "CF3"]);
verifyEqual(testCase, [peaks.center_eV], ...
    [284.2, 285.2, 287.3, 288.1, 290.8, 292.6], "AbsTol", 0);
verifyEqual(testCase, [peaks.fraction_percent], [6, 41, 3, 47, 2, 1], ...
    "AbsTol", 0);
verifyEqual(testCase, ...
    ref.direct_references.overall_sample_A.fluorine_atomic_percent, 32, ...
    "AbsTol", 0);
verifyEqual(testCase, ...
    string(ref.direct_references.overall_sample_A.qualitative_stoichiometry), ...
    "essentially C2F");
verifyFalse(testCase, isfield(ref, "derived_model_values"));
end

function values = asStructArray(values)
if iscell(values)
    values = [values{:}];
end
end
