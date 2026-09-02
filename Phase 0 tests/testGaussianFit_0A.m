clear;
clc;
close all;
import xps.*   % <--- Imports all functions inside +xps

%% Known Gaussian parameters
trueCenter = 287.0;       % eV
trueFWHM   = 1.0;         % eV
trueArea   = 2.0;

%% Energy axis
x = linspace(280,295,1000)';

%% Convert FWHM to sigma
sigma = trueFWHM/(2*sqrt(2*log(2)));

%% Generate known Gaussian
y = trueArea/(sigma*sqrt(2*pi)) .* ...
    exp(-0.5*((x-trueCenter)/sigma).^2);

%% Plot the synthetic spectrum
figure;
plot(x,y,'k-','LineWidth',1.5);
xlabel('Binding energy (eV)');
ylabel('Intensity');
title('Synthetic Gaussian');
grid on;

%% Direct numerical integration
calculatedArea = trapz(x,y);
fprintf('\n===== Synthetic Gaussian Test =====\n');
fprintf('True center:       %.6f eV\n', trueCenter);
fprintf('True FWHM:         %.6f eV\n', trueFWHM);
fprintf('True area:         %.6f\n', trueArea);
fprintf('Numerical area:    %.6f\n', calculatedArea);
fprintf('Area error:        %.6e\n', calculatedArea-trueArea);

%% Create initial peak matrix for fitSpectrum
% peakInit format: [Center, Area, FWHM] for N peaks
peakInit = [286.8, calculatedArea, 1.0];

%% Run our actual fitting function using Name-Value pairs
[fitResult, y_fit] = xps.fitSpectrum(x, y, peakInit, ...
    'BackgroundType', 'none', ...
    'CenterBounds', 1.0, ...
    'FWHMBounds', [0.5, 1.5]);

%% Display result
fprintf('\n===== fitSpectrum Result =====\n');
fprintf('Fitted center:     %.6f eV\n', fitResult.centers(1));
fprintf('Fitted FWHM:       %.6f eV\n', fitResult.fwhms(1));
fprintf('Fitted area:       %.6f\n', fitResult.areas(1));

fprintf('\n===== Known vs fitted =====\n');
fprintf('Center error:      %.6e eV\n', ...
    fitResult.centers(1) - trueCenter);
fprintf('FWHM error:        %.6e eV\n', ...
    fitResult.fwhms(1) - trueFWHM);
fprintf('Area error:        %.6e\n', ...
    fitResult.areas(1) - trueArea);

fprintf('\n===== Fit quality =====\n');
fprintf('RMSE:              %.6e\n', fitResult.RMSE);
fprintf('R^2:               %.8f\n', fitResult.R2);