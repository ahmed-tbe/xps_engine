clear;
clc;
close all;
import xps.*

%% ============================================================
%  Phase 0C: Synthetic Multi-Peak Overlapping Benchmark (No Noise)
% =============================================================
% Ground Truth Peak Configurations (C1s region approximation)
% Format: [Center (eV), FWHM (eV), Area]
truePeaksData = [
    284.50,  1.00,  1.00;   % Peak 1: sp2 C-C
    285.20,  1.00,  1.50;   % Peak 2: C-C / C-H
    287.99,  1.00,  2.00;   % Peak 3: C-F
    288.81,  1.00,  0.50;   % Peak 4: C-CF2 / C=O
    292.41,  1.50,  0.80;   % Peak 5: CF2
    294.27,  1.50,  0.60;   % Peak 6: CF3
];

numPeaks = size(truePeaksData, 1);
peakIDs  = {'sp2_CC', 'C_C', 'C_F', 'C_CF2', 'CF2', 'CF3'};

%% Energy axis (280 to 297 eV)
x = linspace(280, 297, 1000)';

%% Generate True Composite Spectrum
yTrue = zeros(size(x));
yIndividualTrue = zeros(length(x), numPeaks);
for i = 1:numPeaks
    center = truePeaksData(i, 1);
    fwhm   = truePeaksData(i, 2);
    area   = truePeaksData(i, 3);
    
    sigma = fwhm / (2 * sqrt(2 * log(2)));
    yIndividualTrue(:, i) = (area / (sigma * sqrt(2 * pi))) .* ...
                            exp(-0.5 * ((x - center) / sigma).^2);
    yTrue = yTrue + yIndividualTrue(:, i);
end

%% ============================================================
%  Build Peak Configuration Matrix for fitSpectrum
% =============================================================
% peakInit format: [Center, Area, FWHM] for N peaks
% Build this row-by-row using the true peaks data with slight initial offsets
peakInit = zeros(numPeaks, 3);
for i = 1:numPeaks
    peakInit(i, 1) = truePeaksData(i, 1) + 0.1;  % Center with +0.1 eV offset
    peakInit(i, 2) = truePeaksData(i, 3);        % Area (true area as initial guess)
    peakInit(i, 3) = truePeaksData(i, 2);        % FWHM
end

%% ============================================================
%  Run Fitting Algorithm (Clean Data / Phase 0C)
% =============================================================
fprintf('\n==================================================\n');
fprintf('   PHASE 0C: 6-PEAK OVERLAPPING DECONVOLUTION TEST   \n');
fprintf('==================================================\n');

[fitResult, y_fit] = xps.fitSpectrum(x, yTrue, peakInit, ...
    'BackgroundType', 'none', ...
    'CenterBounds', 0.5, ...
    'FWHMBounds', [0.5, 2.0]);

%% ============================================================
%  Report & Performance Metrics
% =============================================================
fprintf('\n%-12s | %-10s %-10s | %-10s %-10s | %-10s %-10s\n', ...
    'Peak ID', 'True Area', 'Fit Area', 'True Center', 'Fit Center', 'True FWHM', 'Fit FWHM');
fprintf('%s\n', repmat('-', 1, 80));

totalAreaTrue = sum(truePeaksData(:, 3));
totalAreaFit  = sum(fitResult.areas);

for i = 1:numPeaks
    fitC = fitResult.centers(i);
    fitW = fitResult.fwhms(i);
    fitA = fitResult.areas(i);
    
    fprintf('%-12s | %-10.4f %-10.4f | %-10.4f %-10.4f | %-10.4f %-10.4f\n', ...
        peakIDs{i}, truePeaksData(i, 3), fitA, ...
        truePeaksData(i, 1), fitC, ...
        truePeaksData(i, 2), fitW);
end

fprintf('%s\n', repmat('-', 1, 80));
fprintf('%-12s | %-10.4f %-10.4f |\n', 'TOTAL AREA', totalAreaTrue, totalAreaFit);

fprintf('\nFit Metrics:\n');
fprintf('RMSE : %.6e\n', fitResult.RMSE);
fprintf('R^2  : %.8f\n', fitResult.R2);

%% ============================================================
%  Plotting Deconvolution Verification
% =============================================================
figure('Color', 'w', 'Position', [100, 100, 900, 500]);
plot(x, yTrue, 'k-', 'LineWidth', 2, 'DisplayName', 'True Total Spectrum');
hold on;
plot(x, y_fit, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Fitted Model');

% Plot individual true vs fitted components
colors = lines(numPeaks);
for i = 1:numPeaks
    plot(x, yIndividualTrue(:, i), ':', 'Color', colors(i,:), 'LineWidth', 1.2, ...
        'HandleVisibility', 'off');
    
    % Reconstruct individual fitted component curve for visualization
    sig_fit = fitResult.sigmas(i);
    c_fit   = fitResult.centers(i);
    a_fit   = fitResult.areas(i);
    y_peak_fit = (a_fit / (sig_fit * sqrt(2*pi))) * exp(-0.5 * ((x - c_fit)/sig_fit).^2);
    
    plot(x, y_peak_fit, '-', 'Color', colors(i,:), 'LineWidth', 1.0, ...
        'DisplayName', sprintf('Fit: %s', peakIDs{i}));
end

set(gca, 'XDir', 'reverse'); % Traditional XPS Binding Energy display (high to low)
xlabel('Binding Energy (eV)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Intensity (a.u.)', 'FontSize', 11, 'FontWeight', 'bold');
title('Phase 0C: 6-Peak Synthetic C1s Overlapping Deconvolution', 'FontSize', 12);
legend('Location', 'northeast');
grid on;