function tests = testAsLSImplementation
%TESTASLSIMPLEMENTATION Code-level AsLS implementation invariants.

tests = functiontests(localfunctions);
end

function testSecondDifferenceMatrixMatchesCanonicalForm(testCase)
n = 681;
currentD = spdiags(ones(n-2,1)*[1 -2 1], 0:2, n-2, n);
canonicalD = diff(speye(n), 2);
verifyEqual(testCase, full(currentD), full(canonicalD), "AbsTol", 0);
end

function testZeroSignalHasExactZeroAsLSBaseline(testCase)
y = zeros(681,1);
baseline = xps.estimateAsLS(y, 1e6, 0.01, 20);
verifyEqual(testCase, baseline, y, "AbsTol", 1e-12);
end
