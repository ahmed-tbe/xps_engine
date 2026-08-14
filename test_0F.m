%% PHASE 0F: PRODUCTION FITTER STRESS TEST (MONTE CARLO GRID)
% Tests production fitSpectrum.m across background and noise levels using
% exact Phase 0C/0D ground-truth peak parameters.

clear; clc; close all;

import xps.*
%% 


% --- 1. Consistent Ground Truth (Matches Phase 0C / 0D) ---
energy = linspace(280, 297, 500)'; % C1s binding energy grid (eV)

% True peaks [Center (eV), Area, FWHM (eV)]
true_peaks = [
    284.50, 1.00, 1.00; % sp2 C=C
    285.20, 1.50, 1.00; % C-C / C-H
    287.99, 2.00, 1.00; % C-F
    288.81, 0.50, 1.00; % C-CF2
    292.41, 0.80, 1.50; % CF2
    294.27, 0.60, 1.50  % CF3
];
num_peaks = size(true_peaks, 1);
peak_names = {'sp2_CC', 'C_C', 'C_F', 'C_CF2', 'CF2', 'CF3'};

% True chemical stoichiometry from ground truth areas:
% F/C = (A_CF + 2*A_CF2 + 3*A_CF3) / Sum(A_all)
true_areas = true_peaks(:,2);
A_total_true = sum(true_areas);
true_FC = (true_areas(3) + 2*true_areas(5) + 3*true_areas(6)) / A_total_true;
true_CxF = 1 / true_FC;

% Construct clean ground-truth signal
signal_clean = zeros(size(energy));
for i = 1:num_peaks
    c = true_peaks(i,1); a = true_peaks(i,2); w = true_peaks(i,3);
    sig = w / (2 * sqrt(2 * log(2)));
    signal_clean = signal_clean + (a / (sig * sqrt(2*pi))) * exp(-0.5 * ((energy - c)/sig).^2);
end
peak_max = max(signal_clean);

% --- 2. Stress Test Grid Definition ---
bkg_strengths   = [0.05, 0.20, 0.50] * peak_max; 
bkg_labels      = {'Weak (5% peak max)', 'Moderate (20% peak max)', 'Strong (50% peak max)'};
noise_fractions = [0.01, 0.03, 0.05];
num_trials      = 10;

fprintf('========================================================================\n');
fprintf('PHASE 0F: PRODUCTION FITTER STRESS TEST (MONTE CARLO GRID)\n');
fprintf('Ground Truth: True F/C = %.4f | True CxF = C%.2fF\n', true_FC, true_CxF);
fprintf('========================================================================\n\n');

rng(101); % For exact reproducibility

% --- 3. Run Monte Carlo Matrix ---
for b_idx = 1:length(bkg_strengths)
    b0_true = bkg_strengths(b_idx) * 0.2;
    b1_true = (bkg_strengths(b_idx) - b0_true) / (max(energy) - min(energy));
    background_true = b0_true + b1_true * (energy - min(energy));
    
    fprintf('************************************************************************\n');
    fprintf(' BACKGROUND LEVEL %d/3: %s\n', b_idx, bkg_labels{b_idx});
    fprintf(' Offset (b0) = %.4f | Slope (b1) = %.4f\n', b0_true, b1_true);
    fprintf('************************************************************************\n');
    
    for n_idx = 1:length(noise_fractions)
        noise_level = noise_fractions(n_idx) * peak_max;
        
        rec_areas = zeros(num_trials, num_peaks);
        rec_FC    = zeros(num_trials, 1);
        rec_r2    = zeros(num_trials, 1);
        
        for t = 1:num_trials
            noise = noise_level * randn(size(energy));
            y_synthetic = signal_clean + background_true + noise;
            
            % --- Calls Production Fitter Engine ---
            % Replace 'fitSpectrum' with 'xps.fitSpectrum' if using package structure
            [res, ~] = fitSpectrum(energy, y_synthetic, true_peaks, ...
                                   'BackgroundType', 'linear', ...
                                   'CenterBounds', 0.5);
            
            rec_areas(t, :) = res.areas';
            rec_r2(t)       = res.R2;
            
            % Compute recovered fluorination metrics
            A_tot = sum(res.areas);
            rec_FC(t) = (res.areas(3) + 2*res.areas(5) + 3*res.areas(6)) / A_tot;
        end
        
        mean_areas  = mean(rec_areas, 1);
        std_areas   = std(rec_areas, 0, 1);
        area_errors = ((mean_areas - true_areas') ./ true_areas') * 100;
        
        mean_FC    = mean(rec_FC);
        std_FC     = std(rec_FC);
        err_FC     = ((mean_FC - true_FC) / true_FC) * 100;
        rec_CxF    = 1 / mean_FC;
        
        fprintf('\n---> Noise Level: %.1f%% Peak Max | Mean R^2: %.5f\n', ...
            noise_fractions(n_idx)*100, mean(rec_r2));
        fprintf('------------------------------------------------------------------------\n');
        fprintf('Peak ID    | True Area  | Recovered Area (Mean +/- Std) | Area Error (%%)\n');
        fprintf('------------------------------------------------------------------------\n');
        for i = 1:num_peaks
            fprintf('%-10s | %-10.4f | %0.4f +/- %0.4f            | %-+8.2f %%\n', ...
                peak_names{i}, true_areas(i), mean_areas(i), std_areas(i), area_errors(i));
        end
        fprintf('------------------------------------------------------------------------\n');
        fprintf('Metric     | True Value | Recovered Value               | Error (%%)\n');
        fprintf('------------------------------------------------------------------------\n');
        fprintf('F/C Ratio  | %-10.4f | %0.4f +/- %0.4f            | %-+8.2f %%\n', ...
            true_FC, mean_FC, std_FC, err_FC);
        fprintf('CxF Value  | C%-9.2fF | C%.2fF                         | ---\n', ...
            true_CxF, rec_CxF);
        fprintf('------------------------------------------------------------------------\n');
    end
    fprintf('\n');
end