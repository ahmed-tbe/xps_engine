%% PHASE 1B-3: STANDARDIZED BACKGROUND MODEL COMPARISON & SELECTION
% Evaluates Linear, Shirley, AsLS, and Tougaard backgrounds on Sample A C1s
% Computes Information Criteria (AICc, BIC) and boundary flags for model selection.

clear; clc; close all;

import xps.*

%% 1. Load Experimental Data
data_file = 'C1s_A(1).txt';
if ~exist(data_file, 'file')
    if exist('C1s_A.txt', 'file'), data_file = 'C1s_A.txt';
    else, error('[ERROR] Data file not found.'); end
end

raw = readmatrix(data_file);
xdata = raw(:,1); ydata = raw(:,2);
if xdata(1) > xdata(end), xdata = flipud(xdata); ydata = flipud(ydata); end
N = length(xdata);

%% 2. Peak Model Definitions (Ruoff Sample A Reference)
peak_names = {'sp2 C=C', 'C-CF / sp3', 'C-CF2,3 / C=O', 'C-F', 'CF2', 'CF3'};
num_peaks  = length(peak_names);
published_fractions = [6.0, 41.0, 3.0, 47.0, 2.0, 1.0];

dx = mean(diff(xdata));
tot_area = sum(ydata - min(ydata)) * abs(dx);

% Peak Guesses [Center, Area, FWHM]
peakInit = [
    284.20,  tot_area * 0.06,  1.10;
    285.20,  tot_area * 0.41,  1.20;
    287.30,  tot_area * 0.03,  1.30;
    288.10,  tot_area * 0.47,  1.40;
    290.80,  tot_area * 0.02,  1.50;
    292.60,  tot_area * 0.01,  1.50
];

center_tol = 0.5;
fwhm_bounds = [0.6, 1.8]; % Conservative physical constraint

%% 3. Execute Controlled Benchmark
bkg_types = {'linear', 'shirley', 'asls', 'tougaard'};
num_bkg   = length(bkg_types);

results = struct();

figure('Color', 'w', 'Position', [70, 70, 1200, 800]);
t = tiledlayout(3, 2, 'TileSpacing', 'Compact', 'Padding', 'Compact');

fprintf('========================================================================================================\n');
fprintf('  PHASE 1B-3: STANDARDIZED XPS BACKGROUND ENGINE COMPARISON\n');
fprintf('========================================================================================================\n\n');

for b = 1:num_bkg
    bkg_type = bkg_types{b};
    
    % Step 1: Compute Baseline
    opts = struct('lambda', 1e5, 'p', 0.01, 'max_iter', 30);
    [y_bkg, bkg_params] = xps_backgrounds(xdata, ydata, bkg_type, opts);
    
    % Step 2: Fit Component Gaussians on Baseline-Subtracted Spectrum
    y_net = ydata - y_bkg;
    y_net(y_net < 0) = 0; % Physical non-negativity constraint
    
    [res, y_peaks] = fitSpectrum(xdata, y_net, peakInit, ...
                                 'BackgroundType', 'none', ...
                                 'CenterBounds', center_tol, ...
                                 'FWHMBounds', fwhm_bounds);
                             
    y_fit_total = y_peaks + y_bkg;
    residuals   = ydata - y_fit_total;
    
    % Step 3: Compute Model Quality Metrics (AICc & BIC)
    RSS = sum(residuals.^2);
    RMSE = sqrt(RSS / N);
    SST = sum((ydata - mean(ydata)).^2);
    R2  = 1 - (RSS / SST);
    
    K = num_peaks * 3; % 18 fitted parameters (centers, areas, sigmas)
    AICc = N * log(RSS / N) + 2*K + (2*K*(K+1)) / (N - K - 1);
    BIC  = N * log(RSS / N) + K * log(N);
    
    % Track Parameter Bounds
    lb_c = peakInit(:,1) - center_tol; ub_c = peakInit(:,1) + center_tol;
    bound_hits = sum(abs(res.centers - lb_c) < 1e-3 | abs(res.centers - ub_c) < 1e-3) + ...
                 sum(abs(res.fwhms - fwhm_bounds(1)) < 1e-3 | abs(res.fwhms - fwhm_bounds(2)) < 1e-3);
             
    area_pct = (res.areas / sum(res.areas)) * 100;
    
    % Store Metrics
    results(b).type = bkg_type;
    results(b).R2 = R2; results(b).RMSE = RMSE;
    results(b).AICc = AICc; results(b).BIC = BIC;
    results(b).bound_hits = bound_hits;
    results(b).area_pct = area_pct;
    
    % Plot Deconvolution
    ax_fit = nexttile(t, b); hold(ax_fit, 'on'); grid(ax_fit, 'on');
    plot(ax_fit, xdata, ydata, 'k.', 'MarkerSize', 5, 'DisplayName', 'Data');
    plot(ax_fit, xdata, y_fit_total, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Fit');
    plot(ax_fit, xdata, y_bkg, 'k--', 'LineWidth', 1.2, 'DisplayName', [upper(bkg_type) ' Baseline']);
    set(ax_fit, 'XDir', 'reverse');
    title(ax_fit, sprintf('%s Background (RMSE=%.1f, AICc=%.1f, Hits=%d)', ...
          upper(bkg_type), RMSE, AICc, bound_hits), 'FontWeight', 'bold');
    ylabel(ax_fit, 'Counts'); xlabel(ax_fit, 'BE (eV)');
    
    % Console Report Table
    fprintf('--- Background Engine: %-10s ---\n', upper(bkg_type));
    fprintf('Metrics: RMSE = %-7.2f | R^2 = %-8.5f | AICc = %-8.1f | BIC = %-8.1f | Bound Hits = %d\n', ...
            RMSE, R2, AICc, BIC, bound_hits);
    fprintf('Fitted Fractions (%%): sp2=%.1f%% | C-CF=%.1f%% | C-CF2,3=%.1f%% | C-F=%.1f%% | CF2=%.1f%% | CF3=%.1f%%\n\n', ...
            area_pct(1), area_pct(2), area_pct(3), area_pct(4), area_pct(5), area_pct(6));
end

%% 4. Summary Comparison Matrix Table
fprintf('========================================================================================================\n');
fprintf('  STANDARDIZED SELECTION MATRIX SUMMARY\n');
fprintf('========================================================================================================\n');
fprintf('Background  | RMSE     | R^2       | AICc     | BIC      | Bound Hits | Delta AICc (vs min)\n');
fprintf('--------------------------------------------------------------------------------------------------------\n');

min_AICc = min([results.AICc]);
for b = 1:num_bkg
    delta_aicc = results(b).AICc - min_AICc;
    fprintf('%-11s | %-8.2f | %-9.5f | %-8.1f | %-8.1f | %-10d | %-+7.1f\n', ...
        upper(results(b).type), results(b).RMSE, results(b).R2, ...
        results(b).AICc, results(b).BIC, results(b).bound_hits, delta_aicc);
end
fprintf('========================================================================================================\n');