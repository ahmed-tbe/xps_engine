%% PHASE 1A: REAL EXPERIMENTAL DATA - RUOFF SAMPLE A (C1s CORE LEVEL)
% Fits the 6 Ruoff-grounded carbon chemical components to real C1s data
% (C1s_A(1).txt) and compares component area fractions to published values.

clear; clc; close all;

import xps.*
%% 


%% 1. Load Experimental Data (Strict File Requirement)
data_file = 'C1s_A.txt'; 

if ~exist(data_file, 'file')
    error(['[ERROR] File "%s" not found in working directory. ' ...
           'Please ensure C1s_A(1).txt is present.'], data_file);
end

raw_data = readmatrix(data_file);
xdata = raw_data(:, 1); % Binding Energy (eV)
ydata = raw_data(:, 2); % Counts / Intensity

% Ensure Binding Energy is sorted in ascending order for fitting routines
if xdata(1) > xdata(end)
    xdata = flipud(xdata);
    ydata = flipud(ydata);
end

%% 2. Define Ruoff-Grounded Initial Guesses & Bounds
% Peak assignments and BEs extracted from Ruoff Sample A C1s spectrum:
% P1: sp2 C=C                 (~284.2 eV) [Bounds: 284.0 - 284.5]
% P2: C-CF / sp3 C-C          (~285.2 eV) [Bounds: 284.9 - 285.6]
% P3: C-CF2,3 / C=O           (~287.3 eV) [Bounds: 286.8 - 287.7]
% P4: C-F (Primary Covalent)   (~288.1 eV) [Bounds: 287.7 - 288.5]
% P5: CF2 (Difluorocarbon)    (~290.8 eV) [Bounds: 290.3 - 291.3]
% P6: CF3 (Trifluorocarbon)   (~292.6 eV) [Bounds: 292.0 - 293.2]

peak_names = {'sp2 C=C', 'C-CF / sp3', 'C-CF2,3 / C=O', 'C-F', 'CF2', 'CF3'};
num_peaks  = length(peak_names);

% Published normal-emission reference fractions for Ruoff Sample A
published_fractions = [6.0, 41.0, 3.0, 47.0, 2.0, 1.0];

% Estimate initial areas scaled by total integrated signal
dx = mean(diff(xdata));
total_est_area = sum(ydata - min(ydata)) * abs(dx);

peakInit = [
    284.20,  total_est_area * 0.06,  1.10;  % sp2 C=C
    285.20,  total_est_area * 0.41,  1.20;  % C-CF / sp3 C-C
    287.30,  total_est_area * 0.03,  1.30;  % C-CF2,3 / C=O
    288.10,  total_est_area * 0.47,  1.40;  % C-F
    290.80,  total_est_area * 0.02,  1.50;  % CF2
    292.60,  total_est_area * 0.01,  1.50   % CF3
];

%% 3. Execute Production Fitting Engine
fprintf('========================================================================\n');
fprintf('  PHASE 1A: RUOFF SAMPLE A C1s CORE-LEVEL SPECTRUM FIT\n');
fprintf('  Data File: %s (%d data points, %.2f to %.2f eV)\n', ...
        data_file, length(xdata), min(xdata), max(xdata));
fprintf('========================================================================\n\n');

% This exploratory legacy script needs a linear baseline fitted jointly
% with the peaks. Keep that historical API separate from xps.fitSpectrum,
% which is the config-driven, background-subtracted Phase 0G pipeline.
[res, y_fit] = fitSpectrumLegacy(xdata, ydata, peakInit, ...
                           'BackgroundType', 'linear', ...
                           'CenterBounds', 0.5, ...
                           'FWHMBounds', [0.6, 2.2]);

%% 4. Evaluate Area Fractions & Comparison to Literature
areas = res.areas;
A_tot = sum(areas);
fitted_fractions = (areas / A_tot) * 100;
diff_fractions   = fitted_fractions - published_fractions';

%% 5. Display Analytical Results
fprintf('----------------------------------------------------------------------------------------\n');
fprintf('Peak ID        | Fit BE (eV) | FWHM (eV) | Area (cts*eV) | Fit Area %% | Ruoff Lit %% | Diff %%\n');
fprintf('----------------------------------------------------------------------------------------\n');
for i = 1:num_peaks
    fprintf('%-14s | %-11.2f | %-9.2f | %-13.2f | %-10.2f | %-11.1f | %-+6.2f %%\n', ...
        peak_names{i}, res.centers(i), res.fwhms(i), areas(i), ...
        fitted_fractions(i), published_fractions(i), diff_fractions(i));
end
fprintf('----------------------------------------------------------------------------------------\n');
fprintf('Fit Quality:   R^2 = %.5f  |  RMSE = %.4f\n', res.R2, res.RMSE);
fprintf('Baseline:      Offset (b0) = %.2f  |  Slope (b1) = %.4f\n', res.bkgOffset, res.bkgSlope);
fprintf('========================================================================================\n');

%% 6. Plot Experimental Deconvolution
figure('Color', 'w', 'Position', [100, 100, 950, 600]);
hold on; grid on;

% Plot Raw Data, Baseline, and Total Fit
plot(xdata, ydata, 'k.', 'MarkerSize', 7, 'DisplayName', 'Experimental Data');
plot(xdata, y_fit, 'r-', 'LineWidth', 2, 'DisplayName', sprintf('Total Fit (R^2 = %.5f)', res.R2));
plot(xdata, res.y_bkg, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Linear Baseline');

% Reconstruct and fill individual peak components
colors = lines(num_peaks);
for i = 1:num_peaks
    c   = res.centers(i);
    sig = res.sigmas(i);
    a   = res.areas(i);
    y_peak = (a / (sig * sqrt(2*pi))) * exp(-0.5 * ((xdata - c)/sig).^2) + res.y_bkg;
    
    fill(xdata, y_peak, colors(i,:), 'FaceAlpha', 0.25, 'EdgeColor', colors(i,:), ...
        'LineWidth', 1.2, ...
        'DisplayName', sprintf('%s: %.1f eV (%.1f%% vs Lit %.1f%%)', ...
        peak_names{i}, c, fitted_fractions(i), published_fractions(i)));
end

set(gca, 'XDir', 'reverse'); % XPS standard notation: High BE to Low BE
xlabel('Binding Energy (eV)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Intensity (Counts)', 'FontSize', 12, 'FontWeight', 'bold');
title('Ruoff Sample A C1s Core-Level XPS Deconvolution (Phase 1A Baseline)', ...
      'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'northeast', 'FontSize', 9);
xlim([min(xdata), max(xdata)]);
