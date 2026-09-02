%% PHASE 1B: SENSITIVITY & IDENTIFIABILITY ANALYSIS (RUOFF SAMPLE A C1s)
% Tests FWHM bound sensitivity (1.6 to 2.2 eV), tracks parameter boundary
% hits, and plots residual spectra r(E) = y_exp - y_fit.

clear; clc; close all;

import xps.*
%% 

%% 1. Load Real Experimental Data
data_file = 'C1s_A.txt';
if ~exist(data_file, 'file')
    % Fallback check for alternative naming
    if exist('C1s_A.txt', 'file')
        data_file = 'C1s_A.txt';
    else
        error('[ERROR] Neither C1s_A(1).txt nor C1s_A.txt found in path.');
    end
end

raw_data = readmatrix(data_file);
xdata = raw_data(:, 1); % BE (eV)
ydata = raw_data(:, 2); % Counts

if xdata(1) > xdata(end)
    xdata = flipud(xdata);
    ydata = flipud(ydata);
end

%% 2. Base Model Setup
peak_names = {'sp2 C=C', 'C-CF / sp3', 'C-CF2,3 / C=O', 'C-F', 'CF2', 'CF3'};
num_peaks  = length(peak_names);
published_fractions = [6.0, 41.0, 3.0, 47.0, 2.0, 1.0]; % Ruoff Lit %

dx = mean(diff(xdata));
total_est_area = sum(ydata - min(ydata)) * abs(dx);

% Heuristic initial parameters
peakInit = [
    284.20,  total_est_area * 0.06,  1.10;
    285.20,  total_est_area * 0.41,  1.20;
    287.30,  total_est_area * 0.03,  1.30;
    288.10,  total_est_area * 0.47,  1.40;
    290.80,  total_est_area * 0.02,  1.50;
    292.60,  total_est_area * 0.01,  1.50
];

% Center search bounds (BE_init +/- 0.5 eV)
center_tol = 0.5;
lb_centers = peakInit(:,1) - center_tol;
ub_centers = peakInit(:,1) + center_tol;

%% 3. Execute FWHM Upper Bound Sensitivity Sweep (1.6, 1.8, 2.0, 2.2 eV)
fwhm_max_list = [1.6, 1.8, 2.0, 2.2];
num_runs = length(fwhm_max_list);

sweep_results = struct();

figure('Color', 'w', 'Position', [80, 80, 1100, 750]);
tiledlayout(3, 1, 'TileSpacing', 'Compact', 'Padding', 'Compact');

% Axes 1: Data & Fits
ax1 = nexttile([2 1]); hold(ax1, 'on'); grid(ax1, 'on');
plot(ax1, xdata, ydata, 'k.', 'MarkerSize', 6, 'DisplayName', 'Experimental Data');

% Axes 2: Residuals
ax2 = nexttile([1 1]); hold(ax2, 'on'); grid(ax2, 'on');
plot(ax2, [min(xdata) max(xdata)], [0 0], 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');

colors = lines(num_runs);

fprintf('========================================================================================\n');
fprintf('  PHASE 1B-2: FWHM BOUND SENSITIVITY SWEEP (Ruoff Sample A C1s)\n');
fprintf('========================================================================================\n');

for r = 1:num_runs
    f_max = fwhm_max_list(r);
    fwhm_bounds = [0.6, f_max];
    
    [res, y_fit] = fitSpectrum(xdata, ydata, peakInit, ...
                               'BackgroundType', 'linear', ...
                               'CenterBounds', center_tol, ...
                               'FWHMBounds', fwhm_bounds);
                           
    residuals = ydata - y_fit;
    areas = res.areas;
    area_pct = (areas / sum(areas)) * 100;
    
    % Track parameters at bounds
    at_lb_center = abs(res.centers - lb_centers) < 1e-3;
    at_ub_center = abs(res.centers - ub_centers) < 1e-3;
    at_lb_fwhm   = abs(res.fwhms - fwhm_bounds(1)) < 1e-3;
    at_ub_fwhm   = abs(res.fwhms - fwhm_bounds(2)) < 1e-3;
    
    % Store run data
    sweep_results(r).fwhm_max = f_max;
    sweep_results(r).res = res;
    sweep_results(r).area_pct = area_pct;
    sweep_results(r).bound_hits = sum(at_lb_center + at_ub_center + at_lb_fwhm + at_ub_fwhm);
    
    % Plot Total Fit
    plot(ax1, xdata, y_fit, '-', 'Color', colors(r,:), 'LineWidth', 1.8, ...
        'DisplayName', sprintf('FWHM max = %.1f eV (R^2=%.5f, RMSE=%.1f)', f_max, res.R2, res.RMSE));
    
    % Plot Residual
    plot(ax2, xdata, residuals, '-', 'Color', colors(r,:), 'LineWidth', 1.2, ...
        'DisplayName', sprintf('Max FWHM %.1f eV', f_max));
        
    % Display Summary in Command Window
    fprintf('\n--- Run %d: Max Allowed FWHM = %.1f eV ---\n', r, f_max);
    fprintf('Fit Quality: R^2 = %.5f | RMSE = %.2f | Boundary Hits = %d\n', ...
            res.R2, res.RMSE, sweep_results(r).bound_hits);
    fprintf('----------------------------------------------------------------------------------------\n');
    fprintf('Component       | Center (eV) | FWHM (eV) | Area %%  | Boundary Warning Flags\n');
    fprintf('----------------------------------------------------------------------------------------\n');
    for i = 1:num_peaks
        flags = '';
        if at_lb_center(i), flags = [flags '[CENTER LOWER] ']; end
        if at_ub_center(i), flags = [flags '[CENTER UPPER] ']; end
        if at_lb_fwhm(i),   flags = [flags '[FWHM LOWER] '];   end
        if at_ub_fwhm(i),   flags = [flags '[FWHM UPPER] '];   end
        if isempty(flags),  flags = 'OK';                     end
        
        fprintf('%-15s | %-11.2f | %-9.2f | %-7.2f | %s\n', ...
            peak_names{i}, res.centers(i), res.fwhms(i), area_pct(i), flags);
    end
end

% Format Top Plot
set(ax1, 'XDir', 'reverse');
ylabel(ax1, 'Counts / Intensity', 'FontWeight', 'bold');
title(ax1, 'Phase 1B: Sensitivity of Fit & Line Shapes to Upper FWHM Bound', 'FontWeight', 'bold');
legend(ax1, 'Location', 'northeast');

% Format Bottom Plot (Residuals)
set(ax2, 'XDir', 'reverse');
xlabel(ax2, 'Binding Energy (eV)', 'FontWeight', 'bold');
ylabel(ax2, 'Residual r(E)', 'FontWeight', 'bold');
title(ax2, 'Residual Spectra (y_{exp} - y_{fit}) across FWHM Constraints', 'FontWeight', 'bold');
legend(ax2, 'Location', 'northeast');
linkaxes([ax1, ax2], 'x');
xlim(ax1, [min(xdata), max(xdata)]);