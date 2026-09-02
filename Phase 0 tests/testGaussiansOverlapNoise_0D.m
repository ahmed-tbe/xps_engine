clear;
clc;
close all;
import xps.*

%% ============================================================
%  Phase 0D: 6-Peak Overlapping Deconvolution with Monte Carlo Noise
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

peakHeight = max(yTrue);

%% ============================================================
%  Build Base Peak Configuration Matrix for xps.fitSpectrum
% =============================================================
% peakInit format: [Center, Area, FWHM] for N peaks
peakInit = zeros(numPeaks, 3);
for i = 1:numPeaks
    peakInit(i, 1) = truePeaksData(i, 1) + 0.1;  % Center with +0.1 eV offset test
    peakInit(i, 2) = truePeaksData(i, 3);        % Area (true area as initial guess)
    peakInit(i, 3) = truePeaksData(i, 2);        % FWHM
end

%% ============================================================
%  Monte Carlo Noise Simulation Settings
% =============================================================
noiseLevels = [0.01, 0.03, 0.05]; % 1%, 3%, 5% std dev relative to max height
numTrials   = 10;                 % 10 Monte Carlo realizations per level
rng(42);                          % Set random seed for statistical repeatability

fprintf('\n========================================================================\n');
fprintf('   PHASE 0D: 6-PEAK OVERLAPPING DECONVOLUTION (MONTE CARLO NOISE TEST)   \n');
fprintf('========================================================================\n');

%% ============================================================
%  Main Monte Carlo Loop
% =============================================================
for nIdx = 1:length(noiseLevels)
    noiseFrac = noiseLevels(nIdx);
    
    % Matrices to store trial results: [Trial, Peak]
    fittedAreas   = zeros(numTrials, numPeaks);
    fittedCenters = zeros(numTrials, numPeaks);
    fittedFWHMs   = zeros(numTrials, numPeaks);
    fittedR2      = zeros(numTrials, 1);
    
    for t = 1:numTrials
        % Add Gaussian white noise
        noise = noiseFrac * peakHeight * randn(size(yTrue));
        yNoisy = yTrue + noise;
        
        % Run Fit using updated function signature and Name-Value pairs
        [fitResult, y_fit] = xps.fitSpectrum(x, yNoisy, peakInit, ...
            'BackgroundType', 'none', ...
            'CenterBounds', 0.5, ...
            'FWHMBounds', [0.5, 2.0]);
        
        % Store statistics
        for i = 1:numPeaks
            fittedAreas(t, i)   = fitResult.areas(i);
            fittedCenters(t, i) = fitResult.centers(i);
            fittedFWHMs(t, i)   = fitResult.fwhms(i);
        end
        fittedR2(t) = fitResult.R2;
    end
    
    % Compute Mean and Std Dev across Monte Carlo runs
    meanArea = mean(fittedAreas, 1);
    stdArea  = std(fittedAreas, 0, 1);
    
    meanCenter = mean(fittedCenters, 1);
    stdCenter  = std(fittedCenters, 0, 1);
    
    meanFWHM = mean(fittedFWHMs, 1);
    stdFWHM  = std(fittedFWHMs, 0, 1);
    
    areaPercentError = 100 * (meanArea - truePeaksData(:, 3)') ./ truePeaksData(:, 3)';
    
    %% Report Results for Current Noise Level
    fprintf('\n------------------------------------------------------------------------\n');
    fprintf(' Noise Level: %.1f%% Peak Height | Average R^2: %.5f (across %d trials)\n', ...
        100 * noiseFrac, mean(fittedR2), numTrials);
    fprintf('------------------------------------------------------------------------\n');
    fprintf('%-10s | %-10s | %-18s | %-18s | %-10s\n', ...
        'Peak ID', 'True Area', 'Recovered Area (Mean ± Std)', 'Area Error (%)', 'Center Shift');
    fprintf('%s\n', repmat('-', 1, 80));
    
    for i = 1:numPeaks
        fprintf('%-10s | %-10.4f | %6.4f ± %-8.4f | %-17.2f%% | %+.4f eV\n', ...
            peakIDs{i}, truePeaksData(i, 3), meanArea(i), stdArea(i), ...
            areaPercentError(i), meanCenter(i) - truePeaksData(i, 1));
    end
    
    %% Plot Visual Inspection for Representative Trial (Trial last saved in loop)
    figure('Color', 'w', 'Position', [100 + (nIdx-1)*50, 100 + (nIdx-1)*50, 900, 480]);
    plot(x, yNoisy, 'k.', 'MarkerSize', 4, 'DisplayName', 'Noisy Data');
    hold on;
    plot(x, yTrue, 'b-', 'LineWidth', 1.2, 'DisplayName', 'True Spectrum');
    plot(x, y_fit, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Fitted Model');
    
    % Plot individual fitted components from fitResult struct arrays
    colors = lines(numPeaks);
    for i = 1:numPeaks
        sig_fit = fitResult.sigmas(i);
        c_fit   = fitResult.centers(i);
        a_fit   = fitResult.areas(i);
        y_peak_fit = (a_fit / (sig_fit * sqrt(2*pi))) * exp(-0.5 * ((x - c_fit)/sig_fit).^2);
        
        plot(x, y_peak_fit, '-', 'Color', colors(i,:), 'LineWidth', 1.2, ...
            'DisplayName', sprintf('Fit: %s', peakIDs{i}));
    end
    
    set(gca, 'XDir', 'reverse'); % Traditional XPS Binding Energy display
    xlabel('Binding Energy (eV)', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('Intensity (a.u.)', 'FontSize', 11, 'FontWeight', 'bold');
    title(sprintf('Phase 0D: Sample Fit at %.1f%% Noise (R^2 = %.4f)', ...
        100 * noiseFrac, fitResult.R2), 'FontSize', 12);
    legend('Location', 'northeast');
    grid on;
end