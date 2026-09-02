function report = diagnoseAsLSImplementation
%DIAGNOSEASLSIMPLEMENTATION Phase 0G non-production AsLS code diagnostic.
%
% Reproduces the zero-true-background synthetic C1s case, verifies the
% current difference matrix against the canonical MATLAB construction, and
% reports a fixed, non-optimizing lambda/p sweep. It never alters config or
% production preprocessing.

cfg = jsondecode(fileread(fullfile("config", "legacy_current_v1.json")));
cTruth = [ ...
    284.15 0.50 0.80; 285.55 0.50 0.80; 287.40 0.50 0.80; ...
    289.30 0.50 0.80; 291.40 0.50 0.80; 293.50 0.50 0.80];
cAcquisitionScale = 2.0;
energy = linspace(280, 297, 681).';
raw = cAcquisitionScale * syntheticGaussianSum(energy, cTruth);
rawScale = max(raw);
y = raw/rawScale;

% The current implementation operates on index spacing, not energy values.
% This synthetic grid is exactly uniform (0.025 eV); readSpectrum sorts it
% ascending before preprocessing.
n = numel(y);
currentD = spdiags(ones(n-2,1)*[1 -2 1], 0:2, n-2, n);
canonicalD = diff(speye(n), 2);
maxDifferenceMatrixError = max(max(abs(full(currentD-canonicalD))));
energyStep = diff(energy);

lambda = cfg.preprocessing.asls_lambda;
p = cfg.preprocessing.asls_p;
iterations = cfg.preprocessing.asls_iterations;
baseline = xps.estimateAsLS(y, lambda, p, iterations);
preprocessed = y-baseline;
fit = xps.fitSpectrum(energy, preprocessed, cfg.C1s, "gaussian");
expectedAreas = cAcquisitionScale*cTruth(:,2).'/rawScale;
areaErrors = abs([fit.peaks.area]-expectedAreas)./expectedAreas;

report = struct();
report.trueAdditiveBackground = 0;
report.energyOrder = "ascending";
report.energyStep_eV = [min(energyStep) max(energyStep)];
report.rawSignalRange = [min(raw) max(raw)];
report.normalizedSignalRange = [min(y) max(y)];
report.aslsBaselineRange = [min(baseline) max(baseline)];
report.baselineSubtractedResidualRange = [min(preprocessed) max(preprocessed)];
report.fittedSignalRange = [min(fit.fitted) max(fit.fitted)];
report.fitResidualRange = [min(fit.residual) max(fit.residual)];
report.lambda = lambda;
report.p = p;
report.iterations = iterations;
report.maxDifferenceMatrixError = maxDifferenceMatrixError;
report.componentRelativeAreaErrors = areaErrors;
report.maxComponentAreaError = max(areaErrors);
report.R2 = fit.metrics.R2;

lambdaGrid = [1e4 1e6 1e8];
pGrid = [0.001 0.01 0.05];
sweep = runFixedSweep(energy, y, cTruth, expectedAreas, cfg.C1s, lambdaGrid, pGrid);
report.fixedSweep = sweep;

fprintf("\nPhase 0G AsLS implementation diagnostic\n");
fprintf("True additive background: exactly 0; energy order: %s; step range: [%.6g, %.6g] eV.\n", ...
    report.energyOrder, report.energyStep_eV(1), report.energyStep_eV(2));
fprintf("Current D vs diff(speye(n),2): max absolute difference = %.3g.\n", ...
    maxDifferenceMatrixError);
fprintf("Raw range: [%.6g, %.6g]; normalized range: [%.6g, %.6g].\n", ...
    report.rawSignalRange, report.normalizedSignalRange);
fprintf("AsLS lambda=%g, p=%g, iterations=%d.\n", lambda, p, iterations);
fprintf("AsLS baseline range: [%.6g, %.6g].\n", report.aslsBaselineRange);
fprintf("Baseline-subtracted range: [%.6g, %.6g]; fitted range: [%.6g, %.6g].\n", ...
    report.baselineSubtractedResidualRange, report.fittedSignalRange);
fprintf("Fit residual range: [%.6g, %.6g]; max area error=%.6g; R2=%.8f.\n\n", ...
    report.fitResidualRange, report.maxComponentAreaError, report.R2);
disp(sweep);
end

function sweep = runFixedSweep(energy, y, truth, expectedAreas, regionCfg, lambdaGrid, pGrid)
% Fixed diagnostic grid, not an optimization or parameter recommendation.
centerTol_eV = 0.04;
fwhmTol_eV = 0.10;
relativeAreaTol = 0.08;
minR2 = 0.995;
nRows = numel(lambdaGrid)*numel(pGrid);
lambdaOut = zeros(nRows,1);
pOut = zeros(nRows,1);
backgroundMin = zeros(nRows,1);
backgroundMax = zeros(nRows,1);
maxAreaError = zeros(nRows,1);
r2 = zeros(nRows,1);
passes0G3 = false(nRows,1);
row = 0;
for lambda = lambdaGrid
    for p = pGrid
        row = row+1;
        baseline = xps.estimateAsLS(y, lambda, p, 20);
        fit = xps.fitSpectrum(energy, y-baseline, regionCfg, "gaussian");
        areaErrors = abs([fit.peaks.area]-expectedAreas)./expectedAreas;
        centerError = max(abs([fit.peaks.center_eV]-truth(:,1).'));
        fwhmError = max(abs([fit.peaks.FWHM_eV]-truth(:,3).'));
        lambdaOut(row) = lambda;
        pOut(row) = p;
        backgroundMin(row) = min(baseline);
        backgroundMax(row) = max(baseline);
        maxAreaError(row) = max(areaErrors);
        r2(row) = fit.metrics.R2;
        passes0G3(row) = centerError <= centerTol_eV && ...
            fwhmError <= fwhmTol_eV && maxAreaError(row) <= relativeAreaTol && ...
            r2(row) >= minR2;
    end
end
sweep = table(lambdaOut, pOut, backgroundMin, backgroundMax, maxAreaError, ...
    r2, passes0G3, 'VariableNames', {'Lambda', 'p', 'BackgroundMin', ...
    'BackgroundMax', 'MaxComponentAreaError', 'R2', 'Passes0G3'});
end

function y = syntheticGaussianSum(energy, truth)
y = zeros(size(energy));
for i = 1:size(truth,1)
    center = truth(i,1);
    area = truth(i,2);
    fwhm = truth(i,3);
    sigma = fwhm/(2*sqrt(2*log(2)));
    y = y + area/(sigma*sqrt(2*pi)) .* exp(-0.5*((energy-center)/sigma).^2);
end
end
