function R = fitSpectrum(x, y, regionCfg, peakShape)
%FITSPECTRUM Fit configured, bounded XPS peak components to a spectrum.
%
% R = xps.fitSpectrum(x, y, regionCfg, peakShape) consumes one region
% configuration decoded from config JSON (with a .peaks field) and returns
% the result schema consumed by the plotting and composition stages.

arguments
    x (:,1) double
    y (:,1) double
    regionCfg (1,1) struct
    peakShape (1,1) string = "gaussian"
end

if ~isfield(regionCfg, "peaks") || isempty(regionCfg.peaks)
    error("xps:fitSpectrum:MissingPeaks", ...
        "regionCfg must contain a nonempty 'peaks' configuration field.");
end
if numel(x) ~= numel(y)
    error("xps:fitSpectrum:SizeMismatch", "x and y must have the same length.");
end

peaksCfg = regionCfg.peaks;
n = numel(peaksCfg);
p0 = zeros(3*n,1);
lb = zeros(3*n,1);
ub = zeros(3*n,1);

% This is a deliberately loose numerical initialization/bound heuristic,
% not a Ruoff-derived physical constraint. It is evaluated in the
% preprocessing scale. P.scale is retained by the caller for later
% cross-region quantification.
[xInt, sortIdx] = sort(x);
yInt = y(sortIdx);
totalPositiveArea = trapz(xInt, max(yInt, 0));
areaUpperBound = max(10 * totalPositiveArea, 1);

for i = 1:n
    pk = configuredPeak(peaksCfg, i);
    j = 3*(i-1)+1;
    p0(j) = pk.initial_center_eV;
    p0(j+1) = mean(pk.FWHM_bounds_eV);
    p0(j+2) = max(totalPositiveArea/n, eps);
    lb(j) = pk.center_bounds_eV(1);
    ub(j) = pk.center_bounds_eV(2);
    lb(j+1) = pk.FWHM_bounds_eV(1);
    ub(j+1) = pk.FWHM_bounds_eV(2);
    lb(j+2) = 0;
    ub(j+2) = areaUpperBound;
end

model = @(p) buildModel(x, p, peakShape);
resid = @(p) model(p) - y;
opts = optimoptions("lsqnonlin", ...
    "Display", "off", ...
    "MaxFunctionEvaluations", 5e4, ...
    "MaxIterations", 2e3);
[p,resnorm,residual,exitflag,output] = lsqnonlin(resid,p0,lb,ub,opts);
fitY = model(p);

R.initialParams = p0;
R.lowerBounds = lb;
R.upperBounds = ub;
R.finalParams = p;
R.totalPositiveArea = totalPositiveArea;
R.energy = x;
R.observed = y;
R.fitted = fitY;
R.residual = residual;
R.exitflag = exitflag;
R.output = output;
R.resnorm = resnorm;
R.fitParameterCount = 3*n;
R.areaUpperBoundHeuristic = areaUpperBound;
R.areaFractionDefinition = ...
    "fraction of fitted peak area within this spectral region";
R.peaks = repmat(struct(),n,1);
R.warnings = strings(0,1);

for i = 1:n
    pk = configuredPeak(peaksCfg, i);
    j = 3*(i-1)+1;
    R.peaks(i).id = string(pk.id);
    R.peaks(i).assignment = string(pk.assignment);
    R.peaks(i).center_eV = p(j);
    R.peaks(i).FWHM_eV = p(j+1);
    R.peaks(i).area = p(j+2);
    R.peaks(i).initial_center_eV = p0(j);
    R.peaks(i).initial_FWHM_eV = p0(j+1);
    R.peaks(i).initial_area = p0(j+2);
    R.peaks(i).center_lower_bound = lb(j);
    R.peaks(i).center_upper_bound = ub(j);
    R.peaks(i).FWHM_lower_bound = lb(j+1);
    R.peaks(i).FWHM_upper_bound = ub(j+1);
    R.peaks(i).area_lower_bound = lb(j+2);
    R.peaks(i).area_upper_bound = ub(j+2);
    R.peaks(i).area_fraction = p(j+2)/sum(p(3:3:end));
    R.peaks(i).curve = componentCurve(x,p(j),p(j+1),p(j+2),peakShape);

    tolC = 0.02*(ub(j)-lb(j));
    tolW = 0.02*(ub(j+1)-lb(j+1));
    tolA = 0.02*(ub(j+2)-lb(j+2));
    hitTolC = sqrt(eps)*max(1,ub(j)-lb(j));
    hitTolW = sqrt(eps)*max(1,ub(j+1)-lb(j+1));
    hitTolA = sqrt(eps)*max(1,ub(j+2)-lb(j+2));
    R.peaks(i).center_at_bound = ...
        abs(p(j)-lb(j)) <= hitTolC || abs(ub(j)-p(j)) <= hitTolC;
    R.peaks(i).FWHM_at_bound = ...
        abs(p(j+1)-lb(j+1)) <= hitTolW || abs(ub(j+1)-p(j+1)) <= hitTolW;
    R.peaks(i).area_at_bound = ...
        abs(p(j+2)-lb(j+2)) <= hitTolA || abs(ub(j+2)-p(j+2)) <= hitTolA;
    R.peaks(i).center_near_bound = ...
        ~R.peaks(i).center_at_bound && ...
        (abs(p(j)-lb(j)) <= tolC || abs(ub(j)-p(j)) <= tolC);
    R.peaks(i).FWHM_near_bound = ...
        ~R.peaks(i).FWHM_at_bound && ...
        (abs(p(j+1)-lb(j+1)) <= tolW || abs(ub(j+1)-p(j+1)) <= tolW);
    R.peaks(i).area_near_bound = ...
        ~R.peaks(i).area_at_bound && ...
        (abs(p(j+2)-lb(j+2)) <= tolA || abs(ub(j+2)-p(j+2)) <= tolA);

    if R.peaks(i).center_at_bound
        R.warnings(end+1) = "Center at bound: " + R.peaks(i).id;
    elseif R.peaks(i).center_near_bound
        R.warnings(end+1) = "Center near bound: " + R.peaks(i).id;
    end
    if R.peaks(i).FWHM_at_bound
        R.warnings(end+1) = "FWHM at bound: " + R.peaks(i).id;
    elseif R.peaks(i).FWHM_near_bound
        R.warnings(end+1) = "FWHM near bound: " + R.peaks(i).id;
    end
    if p(j+2) <= 1e-8
        R.warnings(end+1) = "Extremely small area: " + R.peaks(i).id;
    elseif R.peaks(i).area_at_bound
        R.warnings(end+1) = "Area at bound: " + R.peaks(i).id;
    elseif R.peaks(i).area_near_bound
        R.warnings(end+1) = "Area near bound: " + R.peaks(i).id;
    end
end

R.metrics = xps.calculateFitMetrics(y,fitY,3*n);
end

function pk = configuredPeak(peaksCfg, index)
% JSON decoding can produce either a struct array or a cell array of
% structs, depending on MATLAB release and JSON structure.
if iscell(peaksCfg)
    pk = peaksCfg{index};
else
    pk = peaksCfg(index);
end
end

function yhat = buildModel(x,p,shape)
n = numel(p)/3;
yhat = zeros(size(x));
for i = 1:n
    j = 3*(i-1)+1;
    yhat = yhat + componentCurve(x,p(j),p(j+1),p(j+2),shape);
end
end

function y = componentCurve(x,c,fwhm,area,shape)
switch lower(shape)
    case "gaussian"
        sigma = fwhm/(2*sqrt(2*log(2)));
        y = area/(sigma*sqrt(2*pi)) .* exp(-0.5*((x-c)/sigma).^2);
    case "lorentzian"
        gamma = fwhm/2;
        y = area/pi .* gamma ./ ((x-c).^2 + gamma^2);
    otherwise
        error("xps:fitSpectrum:UnsupportedShape", ...
            "Unsupported peak shape '%s'.", shape);
end
end
