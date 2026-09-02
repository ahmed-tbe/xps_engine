%% PHASE 0E-1: BACKGROUND PRESENT BUT IGNORED IN FIT
% Demonstrates parameter bias when an unmodeled baseline is present.

clear; clc; close all;

import xps.*
%% 


% --- 1. Synthetic Spectrum Construction ---
energy = linspace(280, 297, 500)'; % C1s binding energy grid (eV)

% Peak parameters [Center (eV), Area, FWHM (eV)]
true_peaks = [
    284.50, 1.00, 1.20; % sp2 C=C
    285.20, 1.50, 1.20; % C-C / C-H
    286.50, 2.00, 1.30; % C-O / C-F
    288.20, 0.50, 1.30; % C-CF2
    292.41, 0.80, 1.40; % CF2
    294.27, 0.60, 1.40  % CF3
];

num_peaks = size(true_peaks, 1);

% Generate true signal
signal_clean = zeros(size(energy));
for i = 1:num_peaks
    c = true_peaks(i,1);
    a = true_peaks(i,2);
    w = true_peaks(i,3);
    sig = w / (2 * sqrt(2 * log(2)));
    signal_clean = signal_clean + (a / (sig * sqrt(2*pi))) * exp(-0.5 * ((energy - c)/sig).^2);
end

% Add Synthetic Linear Background: B(E) = b0 + b1*E
% High BE offset = 0.5, Low BE offset = 0.1 (Slanted baseline across range)
b0_true = 0.1;
b1_true = (0.5 - 0.1) / (max(energy) - min(energy));
background_true = b0_true + b1_true * (energy - min(energy));

% Add 2% Gaussian Noise relative to peak max
peak_max = max(signal_clean);
noise_level = 0.02 * peak_max;
rng(42); % Fixed seed for reproducibility
noise = noise_level * randn(size(energy));

y_synthetic = signal_clean + background_true + noise;

% --- 2. Run Fit WITH NO BACKGROUND MODEL (Phase 0E-1) ---
% Using standard regionCfg layout
regionCfg.peaks = true_peaks; % Used to initialize bounds/centers

fprintf('========================================================================\n');
fprintf('PHASE 0E-1: UNMODELED BACKGROUND STRESS TEST (2%% Noise + Linear Bkg)\n');
fprintf('========================================================================\n\n');

% Standard optimization without background term
[fit_results, y_fit] = fitSpectrumNoBkg(energy, y_synthetic, true_peaks);

% --- 3. Evaluate Bias ---
fprintf('------------------------------------------------------------------------\n');
fprintf('Peak ID    | True Area  | Fitted Area | Error (%%) | True Center | Fit Center\n');
fprintf('------------------------------------------------------------------------\n');
peak_names = {'sp2_CC', 'C_C', 'C_F', 'C_CF2', 'CF2', 'CF3'};
for i = 1:num_peaks
    err_pct = ((fit_results.area(i) - true_peaks(i,2)) / true_peaks(i,2)) * 100;
    fprintf('%-10s | %-10.4f | %-11.4f | %-+8.2f %% | %-11.2f | %-10.2f\n', ...
        peak_names{i}, true_peaks(i,2), fit_results.area(i), err_pct, true_peaks(i,1), fit_results.center(i));
end
fprintf('------------------------------------------------------------------------\n');
fprintf('Overall Fit R^2: %.5f\n\n', fit_results.r2);

% --- Helper Fitter Function (No Bkg) ---
function [res, y_fit] = fitSpectrumNoBkg(x, y, peaks)
    n = size(peaks,1);
    % State vector x0: [Center_1..n, Sigma_1..n, Area_1..n]
    x0 = zeros(3*n, 1);
    lb = zeros(3*n, 1);
    ub = zeros(3*n, 1);
    
    for i = 1:n
        x0(i)     = peaks(i,1);                     % Center
        x0(n+i)   = peaks(i,3)/(2*sqrt(2*log(2)));   % Sigma
        x0(2*n+i) = peaks(i,2);                     % Area
        
        lb(i)     = peaks(i,1) - 0.5;
        ub(i)     = peaks(i,1) + 0.5;
        lb(n+i)   = 0.3 / 2.355;
        ub(n+i)   = 3.0 / 2.355;
        lb(2*n+i) = 0.0;
        ub(2*n+i) = sum(y) * (x(2)-x(1)) * 2;
    end
    
    opts = optimoptions('lsqcurvefit', 'Display', 'off', 'MaxFunctionEvaluations', 20000);
    p_opt = lsqcurvefit(@(p, xdata) evalGauss(p, xdata, n), x0, x, y, lb, ub, opts);
    
    y_fit = evalGauss(p_opt, x, n);
    res.center = p_opt(1:n);
    res.sigma  = p_opt(n+1:2*n);
    res.area   = p_opt(2*n+1:3*n);
    
    ss_res = sum((y - y_fit).^2);
    ss_tot = sum((y - mean(y)).^2);
    res.r2 = 1 - (ss_res / ss_tot);
end

function y = evalGauss(p, x, n)
    y = zeros(size(x));
    for i = 1:n
        c = p(i); sig = p(n+i); a = p(2*n+i);
        y = y + (a / (sig * sqrt(2*pi))) * exp(-0.5 * ((x - c)/sig).^2);
    end
end