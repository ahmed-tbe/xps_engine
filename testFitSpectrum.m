function tests = testFitSpectrum
%TESTFITSPECTRUM Phase 0G-1 area-parameterization sanity tests.

tests = functiontests(localfunctions);
end

function testGaussianCurveIntegratesToReportedArea(testCase)
energy = linspace(280, 290, 2001).';
trueCenter = 285.0;
trueFWHM = 1.2;
trueArea = 2.5;
sigma = trueFWHM/(2*sqrt(2*log(2)));
y = trueArea/(sigma*sqrt(2*pi)) .* exp(-0.5*((energy-trueCenter)/sigma).^2);

peak = struct( ...
    "id", "synthetic", ...
    "assignment", "synthetic Gaussian", ...
    "initial_center_eV", trueCenter, ...
    "center_bounds_eV", [284.5 285.5], ...
    "FWHM_bounds_eV", [0.8 1.6]);
fit = xps.fitSpectrum(energy, y, struct("peaks", peak), "gaussian");

numericalArea = trapz(fit.energy, fit.peaks(1).curve);
verifyEqual(testCase, numericalArea, fit.peaks(1).area, "AbsTol", 1e-8);
verifyEqual(testCase, fit.peaks(1).area, trueArea, "AbsTol", 1e-6);
verifyEqual(testCase, fit.peaks(1).center_eV, trueCenter, "AbsTol", 1e-6);
verifyEqual(testCase, fit.peaks(1).FWHM_eV, trueFWHM, "AbsTol", 1e-6);
end
