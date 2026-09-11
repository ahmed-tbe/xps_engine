function tests = testFitSpectrumLegacy
%TESTFITSPECTRUMLEGACY Regression test for the legacy linear-baseline API.

tests = functiontests(localfunctions);
end

function testGaussianPlusLinearBaseline(testCase)
x = linspace(280, 290, 1001).';
trueCenter = 285.0;
trueArea = 2.5;
trueFWHM = 1.0;
trueOffset = 0.20;
trueSlope = 0.03;
sigma = trueFWHM/(2*sqrt(2*log(2)));
peak = trueArea/(sigma*sqrt(2*pi)) .* exp(-0.5*((x-trueCenter)/sigma).^2);
y = peak + trueOffset + trueSlope*(x-min(x));

[fit, yFit] = fitSpectrumLegacy(x, y, [trueCenter 2.0 1.2], ...
    'BackgroundType', 'linear', 'CenterBounds', 0.5, ...
    'FWHMBounds', [0.6 1.5]);

verifyEqual(testCase, fit.centers, trueCenter, "AbsTol", 1e-6);
verifyEqual(testCase, fit.fwhms, trueFWHM, "AbsTol", 1e-6);
verifyEqual(testCase, fit.areas, trueArea, "AbsTol", 1e-6);
verifyEqual(testCase, fit.bkgOffset, trueOffset, "AbsTol", 1e-6);
verifyEqual(testCase, fit.bkgSlope, trueSlope, "AbsTol", 1e-6);
verifyEqual(testCase, yFit, y, "AbsTol", 1e-8);
verifyEqual(testCase, fit.R2, 1, "AbsTol", 1e-12);
end
