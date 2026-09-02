function summary = diagnoseBackgroundPreprocessing
%DIAGNOSEBACKGROUNDPREPROCESSING Compare current background implementations.
%
% Phase 0G diagnostic only. This function does not alter production
% preprocessing or configuration. It applies each existing background
% implementation to the same deterministic, zero-true-background C1s
% spectrum used by testSyntheticPipeline and reports recovery metrics.

cfg = jsondecode(fileread(fullfile("config", "legacy_current_v1.json")));
cTruth = [ ...
    284.15 0.50 0.80; ... % sp2_C_C
    285.55 0.50 0.80; ... % C_CF_sp3
    287.40 0.50 0.80; ... % C_F
    289.30 0.50 0.80; ... % C_CF23_C_O
    291.40 0.50 0.80; ... % CF2
    293.50 0.50 0.80];   % CF3
cAcquisitionScale = 2.0;
cEnergy = linspace(280, 297, 681).';
% There is mathematically no additive background in this synthetic signal.
cRaw = cAcquisitionScale * syntheticGaussianSum(cEnergy, cTruth);

filename = [tempname(tempdir) '.txt'];
cleanupFile = onCleanup(@() deleteIfPresent(filename)); %#ok<NASGU>
writematrix([flipud(cEnergy) flipud(cRaw)], filename, "Delimiter", "tab");
C = xps.readSpectrum(filename);
scale = max(C.intensityFit);
yNorm = C.intensityFit / scale;
expectedAreas = cAcquisitionScale * cTruth(:,2).' / scale;

% These acceptance values match 0G-3 and are not tuned per method.
centerTol_eV = 0.04;
fwhmTol_eV = 0.10;
relativeAreaTol = 0.08;
minR2 = 0.995;
methods = {"Linear", "Shirley", "AsLS", "Tougaard"};
nMethods = numel(methods);
backgroundMin = zeros(nMethods,1);
backgroundMax = zeros(nMethods,1);
backgroundRange = zeros(nMethods,1);
totalFittedArea = zeros(nMethods,1);
maxAreaError = zeros(nMethods,1);
maxCenterError = zeros(nMethods,1);
maxFWHMError = zeros(nMethods,1);
r2 = zeros(nMethods,1);
passes0G3 = false(nMethods,1);
areaErrorText = strings(nMethods,1);

for i = 1:nMethods
    method = methods{i};
    bkg = estimateBackground(C.energyFit, yNorm, method, cfg.preprocessing);
    fit = xps.fitSpectrum(C.energyFit, yNorm-bkg, cfg.C1s, "gaussian");
    areaErrors = abs([fit.peaks.area] - expectedAreas) ./ expectedAreas;
    maxCenterError(i) = max(abs([fit.peaks.center_eV] - cTruth(:,1).'));
    maxFWHMError(i) = max(abs([fit.peaks.FWHM_eV] - cTruth(:,3).'));
    maxAreaError(i) = max(areaErrors);
    r2(i) = fit.metrics.R2;
    backgroundMin(i) = min(bkg);
    backgroundMax(i) = max(bkg);
    backgroundRange(i) = backgroundMax(i)-backgroundMin(i);
    totalFittedArea(i) = sum([fit.peaks.area]);
    areaErrorText(i) = string(mat2str(areaErrors, 6));
    passes0G3(i) = maxCenterError(i) <= centerTol_eV && ...
        maxFWHMError(i) <= fwhmTol_eV && ...
        maxAreaError(i) <= relativeAreaTol && r2(i) >= minR2;
end

methodNames = string(methods(:));
summary = table(methodNames, backgroundMin, backgroundMax, ...
    backgroundRange, totalFittedArea, areaErrorText, maxAreaError, ...
    maxCenterError, maxFWHMError, r2, passes0G3, ...
    'VariableNames', {'Method', 'BackgroundMin', 'BackgroundMax', ...
    'BackgroundRange', 'TotalFittedArea', 'PeakRelativeAreaErrors', ...
    'MaxComponentAreaError', 'MaxCenterError_eV', 'MaxFWHMError_eV', ...
    'R2', 'Passes0G3'});

fprintf("\nPhase 0G background-preprocessing diagnostic\n");
fprintf("Synthetic C1s true additive background: exactly zero.\n");
fprintf("Normalization: max intensity; C1s raw acquisition multiplier: %.1f.\n", ...
    cAcquisitionScale);
fprintf("AsLS uses config: lambda=%g, p=%g, iterations=%d.\n\n", ...
    cfg.preprocessing.asls_lambda, cfg.preprocessing.asls_p, ...
    cfg.preprocessing.asls_iterations);
disp(summary);
end

function bkg = estimateBackground(x, yNorm, method, preprocessing)
switch lower(method)
    case "linear"
        bkg = xps_backgrounds(x, yNorm, "linear", struct());
    case "shirley"
        bkg = xps_backgrounds(x, yNorm, "shirley", struct());
    case "asls"
        bkg = xps.estimateAsLS(yNorm, preprocessing.asls_lambda, ...
            preprocessing.asls_p, preprocessing.asls_iterations);
    case "tougaard"
        bkg = xps_backgrounds(x, yNorm, "tougaard", struct());
    otherwise
        error("Unsupported diagnostic background '%s'.", method);
end
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

function deleteIfPresent(filename)
if isfile(filename)
    delete(filename);
end
end
