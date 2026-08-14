clear;
clc;
close all;
import xps.*

%% ============================================================
%  Known Gaussian parameters
% =============================================================
trueCenter = 287.0;       % eV
trueFWHM   = 1.0;         % eV
trueArea   = 2.0;

%% Energy axis
x = linspace(280,295,1000)';

%% Generate the true Gaussian
sigma = trueFWHM/(2*sqrt(2*log(2)));
yTrue = trueArea/(sigma*sqrt(2*pi)) .* ...
    exp(-0.5*((x-trueCenter)/sigma).^2);

%% Peak height
peakHeight = max(yTrue);
fprintf('\n===== TRUE GAUSSIAN =====\n');
fprintf('Center:       %.6f eV\n', trueCenter);
fprintf('FWHM:         %.6f eV\n', trueFWHM);
fprintf('Area:         %.6f\n', trueArea);
fprintf('Peak height:  %.6f\n', peakHeight);

%% ============================================================
%  Noise levels
% =============================================================
noiseLevels = [0.01 0.03 0.05];

% Make results reproducible
rng(1);

for k = 1:numel(noiseLevels)
    noiseFraction = noiseLevels(k);
    
    %% Generate Gaussian noise
    noise = noiseFraction * peakHeight * randn(size(yTrue));
    
    %% Noisy spectrum
    yNoisy = yTrue + noise;
    
    %% Create initial peak matrix for fitSpectrum
    % peakInit format: [Center, Area, FWHM] for N peaks
    % Using the initial guess properties previously defined in regionCfg
    peakInit = [286.8, trueArea, 1.0];
    
    %% Run fit using the updated function signature and Name-Value pairs
    [fitResult, y_fit] = xps.fitSpectrum(x, yNoisy, peakInit, ...
        'BackgroundType', 'none', ...
        'CenterBounds', 1.0, ...         % Derived from bounds span [286.0 288.0] -> +/- 1.0 eV around 287.0 (or init 286.8)
        'FWHMBounds', [0.5, 1.5]);
    
    %% Extract fitted values
    fittedCenter = fitResult.centers(1);
    fittedFWHM   = fitResult.fwhms(1);
    fittedArea   = fitResult.areas(1);
    
    %% Errors
    centerError = fittedCenter - trueCenter;
    fwhmError   = fittedFWHM - trueFWHM;
    areaError   = fittedArea - trueArea;
    
    centerPercentError = 100 * centerError / trueCenter;
    fwhmPercentError   = 100 * fwhmError / trueFWHM;
    areaPercentError   = 100 * areaError / trueArea;
    
    %% Report
    fprintf('\n============================================\n');
    fprintf('Noise level: %.1f%% of peak height\n', ...
        100*noiseFraction);
    fprintf('============================================\n');
    fprintf('\nFitted values:\n');
    fprintf('Center:       %.6f eV\n', fittedCenter);
    fprintf('FWHM:         %.6f eV\n', fittedFWHM);
    fprintf('Area:         %.6f\n', fittedArea);
    
    fprintf('\nErrors:\n');
    fprintf('Center error: %.6e eV (%.4f%%)\n', ...
        centerError, centerPercentError);
    fprintf('FWHM error:   %.6e eV (%.4f%%)\n', ...
        fwhmError, fwhmPercentError);
    fprintf('Area error:   %.6e (%.4f%%)\n', ...
        areaError, areaPercentError);
    
    fprintf('\nFit quality:\n');
    fprintf('RMSE:         %.6e\n', fitResult.RMSE);
    fprintf('R^2:          %.8f\n', fitResult.R2);
    
    %% Plot
    figure;
    plot(x,yNoisy,'k.','MarkerSize',5);
    hold on;
    plot(x,yTrue,'b-','LineWidth',1.5);
    plot(x,y_fit,'r-','LineWidth',1.5);
    xlabel('Binding energy (eV)');
    ylabel('Intensity');
    title(sprintf('Gaussian fit with %.1f%% noise', ...
        100*noiseFraction));
    legend('Noisy data','True Gaussian','Fitted Gaussian');
    grid on;
end