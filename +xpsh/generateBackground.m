function [background,metadata] = generateBackground(energy,peakSignal,method)
%GENERATEBACKGROUND Independent test-only Phase 0H truth backgrounds.
%
% This function deliberately does not call xps.estimateBackground,
% xps.preprocessSpectrum, xps_backgrounds, or another production estimator.

arguments
    energy (:,1) double
    peakSignal (:,1) double
    method (1,1) string
end
if numel(energy) ~= numel(peakSignal) || any(diff(energy) <= 0)
    error("xpsh:generateBackground:InvalidGrid", ...
        "Energy and signal must be equal-length vectors on an ascending grid.");
end

method = lower(method);
M = max(peakSignal);
t = (energy-energy(1))/(energy(end)-energy(1));
metadata = struct("generator_id","phase0h_independent_background_v1", ...
    "method",method,"production_estimator_called",false, ...
    "provenance",["Frozen Phase 0H v1.0.0 independent test-only " + ...
    "discretization; validate limiting cases before scientific use."]);

switch method
    case "zero"
        background = zeros(size(energy));
        metadata.definition = "exact zero additive background";
    case "linear"
        background = M*(0.05+0.10*t);
        metadata.definition = "M*(0.05+0.10*t)";
    case "quadratic"
        background = M*(0.02+0.03*t+0.10*t.^2);
        metadata.definition = "M*(0.02+0.03*t+0.10*t^2)";
    case "shirley"
        cumulative = cumtrapz(energy,peakSignal);
        total = cumulative(end);
        if total <= eps(max(1,abs(total)))
            shape = zeros(size(energy));
        else
            shape = (total-cumulative)/total;
        end
        background = scaleShape(shape,0.15*M);
        metadata.definition = ...
            "trapezoidal integral_E^Emax(signal)/integral_Emin^Emax(signal)";
    case "tougaard"
        if M <= 0
            shape = zeros(size(energy));
        else
            B = 2866; C = 1643;
            n = numel(energy);
            delta = diff(energy);
            if max(abs(delta-delta(1))) > 1e-10*max(1,abs(delta(1)))
                shape = directTougaard(energy,peakSignal,B,C);
                metadata.discretization = "direct_trapezoidal_nonuniform";
            else
                dx = delta(1);
                transfer = (0:n-1).'*dx;
                kernel = B*transfer./(C+transfer.^2).^2;
                convolution = conv(peakSignal,kernel)*dx;
                shape = convolution(1:n)-0.5*dx*peakSignal(1)*kernel;
                metadata.discretization = "uniform_grid_trapezoidal_convolution";
            end
        end
        background = scaleShape(shape,0.15*M);
        metadata.definition = ...
            "integral_Emin^E signal(u)*B*(E-u)/(C+(E-u)^2)^2 du";
        metadata.B = 2866;
        metadata.C = 1643;
    otherwise
        error("xpsh:generateBackground:UnsupportedMethod", ...
            "Unsupported truth background '%s'.",method);
end
background = background(:);
metadata.minimum = min(background);
metadata.maximum = max(background);
end

function output = scaleShape(shape,targetMaximum)
shape = shape-min(shape);
span = max(shape);
if targetMaximum <= 0 || span <= eps(max(1,abs(span)))
    output = zeros(size(shape));
else
    output = shape/span*targetMaximum;
end
end

function q = directTougaard(energy,signal,B,C)
n = numel(energy);
q = zeros(n,1);
for i = 2:n
    transfer = energy(i)-energy(1:i);
    kernel = B*transfer./(C+transfer.^2).^2;
    q(i) = trapz(energy(1:i),signal(1:i).*kernel);
end
end
