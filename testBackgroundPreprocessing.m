function tests = testBackgroundPreprocessing
%TESTBACKGROUNDPREPROCESSING Deterministic zero-input background checks.
%
% These are implementation sanity checks. diagnoseBackgroundPreprocessing
% separately tests the more demanding zero-true-background-with-peaks case.

tests = functiontests(localfunctions);
end

function testBackgroundMethodsReturnZeroForZeroSignal(testCase)
x = linspace(280, 297, 681).';
y = zeros(size(x));
methods = {"linear", "shirley", "tougaard"};
for i = 1:numel(methods)
    background = xps_backgrounds(x, y, char(methods{i}), struct());
    verifyEqual(testCase, background, zeros(size(y)), "AbsTol", 1e-12);
end

asls = xps.estimateAsLS(y, 1e6, 0.01, 20);
verifyEqual(testCase, asls, zeros(size(y)), "AbsTol", 1e-12);
end
