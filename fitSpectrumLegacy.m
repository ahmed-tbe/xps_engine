function [fitResult, y_fit] = fitSpectrumLegacy(x, y, peakInit, varargin)
%FITSPECTRUMLEGACY Legacy matrix-based Gaussian fitter with optional baseline.
%
% This helper preserves the interface used by exploratory Phase 0A--0F and
% Phase 1 scripts. It is deliberately separate from xps.fitSpectrum, the
% config-driven Phase 0G production pipeline.
%
% peakInit is [center_eV, area, FWHM_eV] per row.

p = inputParser;
addRequired(p, 'x');
addRequired(p, 'y');
addRequired(p, 'peakInit');
addParameter(p, 'BackgroundType', 'none', ...
    @(value) ismember(lower(string(value)), ["none" "constant" "linear"]));
addParameter(p, 'CenterBounds', 0.5, @isnumeric);
addParameter(p, 'FWHMBounds', [0.4, 2.5], @isnumeric);
parse(p, x, y, peakInit, varargin{:});

bkgType = lower(string(p.Results.BackgroundType));
centerTol = p.Results.CenterBounds;
fwhmLimits = p.Results.FWHMBounds;
x = x(:);
y = y(:);
numPeaks = size(peakInit, 1);
dx = mean(diff(x));

% Parameter order is [centers, sigmas, areas, optional background].
x0 = zeros(3*numPeaks, 1);
lb = zeros(3*numPeaks, 1);
ub = zeros(3*numPeaks, 1);
for i = 1:numPeaks
    x0(i) = peakInit(i, 1);
    x0(numPeaks+i) = peakInit(i, 3)/(2*sqrt(2*log(2)));
    x0(2*numPeaks+i) = peakInit(i, 2);
    lb(i) = peakInit(i, 1)-centerTol;
    ub(i) = peakInit(i, 1)+centerTol;
    lb(numPeaks+i) = fwhmLimits(1)/(2*sqrt(2*log(2)));
    ub(numPeaks+i) = fwhmLimits(2)/(2*sqrt(2*log(2)));
    lb(2*numPeaks+i) = 0;
    ub(2*numPeaks+i) = sum(y)*abs(dx)*3;
end

switch bkgType
    case "none"
    case "constant"
        x0 = [x0; min(y)];
        lb = [lb; 0];
        ub = [ub; max(y)];
    case "linear"
        x0 = [x0; min(y); 0];
        lb = [lb; 0; -10];
        ub = [ub; max(y); 10];
end

opts = optimoptions('lsqcurvefit', ...
    'Display', 'off', ...
    'MaxFunctionEvaluations', 50000, ...
    'MaxIterations', 2000, ...
    'FunctionTolerance', 1e-8, ...
    'StepTolerance', 1e-8);
pOpt = lsqcurvefit(@(params, xdata) evaluateModel(params, xdata, numPeaks, bkgType), ...
    x0, x, y, lb, ub, opts);
y_fit = evaluateModel(pOpt, x, numPeaks, bkgType);

fitResult.numPeaks = numPeaks;
fitResult.centers = pOpt(1:numPeaks);
fitResult.sigmas = pOpt(numPeaks+1:2*numPeaks);
fitResult.fwhms = fitResult.sigmas*(2*sqrt(2*log(2)));
fitResult.areas = pOpt(2*numPeaks+1:3*numPeaks);
fitResult.areaPercents = fitResult.areas/sum(fitResult.areas)*100;
fitResult.bkgType = bkgType;

if bkgType == "constant"
    fitResult.bkgOffset = pOpt(3*numPeaks+1);
    fitResult.bkgSlope = 0;
    fitResult.y_bkg = repmat(fitResult.bkgOffset, size(x));
elseif bkgType == "linear"
    fitResult.bkgOffset = pOpt(3*numPeaks+1);
    fitResult.bkgSlope = pOpt(3*numPeaks+2);
    fitResult.y_bkg = fitResult.bkgOffset + fitResult.bkgSlope*(x-min(x));
else
    fitResult.bkgOffset = 0;
    fitResult.bkgSlope = 0;
    fitResult.y_bkg = zeros(size(x));
end

ssRes = sum((y-y_fit).^2);
ssTot = sum((y-mean(y)).^2);
fitResult.R2 = 1-ssRes/ssTot;
fitResult.RMSE = sqrt(ssRes/numel(y));
end

function yModel = evaluateModel(params, x, numPeaks, bkgType)
yModel = zeros(size(x));
if bkgType == "constant"
    yModel = yModel + params(3*numPeaks+1);
elseif bkgType == "linear"
    offset = params(3*numPeaks+1);
    slope = params(3*numPeaks+2);
    yModel = yModel + offset+slope*(x-min(x));
end
for i = 1:numPeaks
    center = params(i);
    sigma = params(numPeaks+i);
    area = params(2*numPeaks+i);
    yModel = yModel + area/(sigma*sqrt(2*pi)) .* exp(-0.5*((x-center)/sigma).^2);
end
end
