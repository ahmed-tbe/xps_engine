%% PHASE 0E-2: EXPLICIT LINEAR BACKGROUND RECOVERY
% Solves for peaks AND background simultaneously.

clear; clc; close all;

import xps.*
%% 


% --- 1. Synthetic Spectrum Construction (Identical to 0E-1) ---
energy = linspace(280, 297, 500)'; 
true_peaks = [
    284.50, 1.00, 1.20;
    285.20, 1.50, 1.20;
    286.50, 2.00, 1.30;
    288.20, 0.50, 1.30;
    292.41, 0.80, 1.40;
    294.27, 0.60, 1.40
];
num_peaks = size(true_peaks, 1);

signal_clean = zeros(size(energy));
for i = 1:num_peaks
    c = true_peaks(i,1); a = true_peaks(i,2); w = true_peaks(i,3);
    sig = w / (2 * sqrt(2 * log(2)));
    signal_clean = signal_clean + (a / (sig * sqrt(2*pi))) * exp(-0.5 * ((energy - c)/sig).^2);
end

% True linear background parameters
b0_true = 0.1;
b1_true = (0.5 - 0.1) / (max(energy) - min(energy));
background_true = b0_true + b1_true * (energy - min(energy));

% Noise
peak_max = max(signal_clean);
noise_level = 0.02 * peak_max;
rng(42); 
noise = noise_level * randn(size(energy));

y_synthetic = signal_clean + background_true + noise;

% --- 2. Run Background-Aware Fit (Phase 0E-2) ---
fprintf('========================================================================\n');
fprintf('PHASE 0E-2: BACKGROUND-AWARE DECONVOLUTION (2%% Noise + Linear Bkg)\n');
fprintf('========================================================================\n\n');

[fit_results, y_fit, bkg_fit] = fitSpectrumWithLinearBkg(energy, y_synthetic, true_peaks);

% --- 3. Evaluate Recovered Parameters ---
fprintf('------------------------------------------------------------------------\n');
fprintf('Peak ID    | True Area  | Recovered Area | Error (%%) | True Center | Fit Center\n');
fprintf('------------------------------------------------------------------------\n');
peak_names = {'sp2_CC', 'C_C', 'C_F', 'C_CF2', 'CF2', 'CF3'};
for i = 1:num_peaks
    err_pct = ((fit_results.area(i) - true_peaks(i,2)) / true_peaks(i,2)) * 100;
    fprintf('%-10s | %-10.4f | %-14.4f | %-+8.2f %% | %-11.2f | %-10.2f\n', ...
        peak_names{i}, true_peaks(i,2), fit_results.area(i), err_pct, true_peaks(i,1), fit_results.center(i));
end
fprintf('------------------------------------------------------------------------\n');
fprintf('Background b0 (Offset): True = %.4f | Recovered = %.4f\n', b0_true, fit_results.b0);
fprintf('Background b1 (Slope):  True = %.4f | Recovered = %.4f\n', b1_true, fit_results.b1);
fprintf('Overall Fit R^2: %.5f\n\n', fit_results.r2);

% --- Helper Fitter Function (With Linear Bkg) ---
function [res, y_fit, bkg_fit] = fitSpectrumWithLinearBkg(x, y, peaks)
    n = size(peaks,1);
    % State vector x0: [Center_1..n, Sigma_1..n, Area_1..n, b0, b1]
    x0 = zeros(3*n + 2, 1);
    lb = zeros(3*n + 2, 1);
    ub = zeros(3*n + 2, 1);
    
    for i = 1:n
        x0(i)     = peaks(i,1);
        x0(n+i)   = peaks(i,3)/(2*sqrt(2*log(2)));
        x0(2*n+i) = peaks(i,2);
        
        lb(i)     = peaks(i,1) - 0.5;
        ub(i)     = peaks(i,1) + 0.5;
        lb(n+i)   = 0.3 / 2.355;
        ub(n+i)   = 3.0 / 2.355;
        lb(2*n+i) = 0.0;
        ub(2*n+i) = sum(y) * (x(2)-x(1)) * 2;
    end
    
    % Background parameters: b0 (intercept), b1 (slope)
    x0(3*n+1) = min(y);       lb(3*n+1) = 0;              ub(3*n+1) = max(y);
    x0(3*n+2) = 0;            lb(3*n+2) = -10;            ub(3*n+2) = 10;
    
    opts = optimoptions('lsqcurvefit', 'Display', 'off', 'MaxFunctionEvaluations', 30000);
    p_opt = lsqcurvefit(@(p, xdata) evalGaussWithBkg(p, xdata, n), x0, x, y, lb, ub, opts);
    
    y_fit = evalGaussWithBkg(p_opt, x, n);
    res.center = p_opt(1:n);
    res.sigma  = p_opt(n+1:2*n);
    res.area   = p_opt(2*n+1:3*n);
    res.b0     = p_opt(3*n+1);
    res.b1     = p_opt(3*n+2);
    
    bkg_fit = res.b0 + res.b1 * (x - min(x));
    
    ss_res = sum((y - y_fit).^2);
    ss_tot = sum((y - mean(y)).^2);
    res.r2 = 1 - (ss_res / ss_tot);
end

function y = evalGaussWithBkg(p, x, n)
    y = zeros(size(x));
    % Background
    b0 = p(3*n+1);
    b1 = p(3*n+2);
    y = b0 + b1 * (x - min(x));
    
    % Peaks
    for i = 1:n
        c = p(i); sig = p(n+i); a = p(2*n+i);
        y = y + (a / (sig * sqrt(2*pi))) * exp(-0.5 * ((x - c)/sig).^2);
    end
end