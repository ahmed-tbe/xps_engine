function [fitResult, y_fit] = fitSpectrum(x, y, peakInit, varargin)
% FITSPECTRUM Fits Gaussian peak components to XPS spectral data.
% Core production fitter for the XPS analysis pipeline.
%
% INPUTS:
%   x        - Binding energy vector (eV)
%   y        - Intensity vector
%   peakInit - Matrix [N x 3]: [Center, Area, FWHM] for N peaks
%
% OPTIONAL PARAMETERS (Name-Value pairs):
%   'BackgroundType' - 'none' (default), 'constant', or 'linear'
%   'CenterBounds'   - Max shift allowed for center (+/- eV, default: 0.5)
%   'FWHMBounds'      - [minFWHM, maxFWHM] in eV (default: [0.4, 2.5])

    % --- 1. Parse Input Options ---
    p = inputParser;
    addRequired(p, 'x');
    addRequired(p, 'y');
    addRequired(p, 'peakInit');
    addParameter(p, 'BackgroundType', 'none', @(s) ismember(s, {'none', 'constant', 'linear'}));
    addParameter(p, 'CenterBounds', 0.5, @isnumeric);
    addParameter(p, 'FWHMBounds', [0.4, 2.5], @isnumeric);
    parse(p, x, y, peakInit, varargin{:});
    
    bkgType     = p.Results.BackgroundType;
    centerTol   = p.Results.CenterBounds;
    fwhmLimits  = p.Results.FWHMBounds;

    % Format vectors
    x = x(:);
    y = y(:);
    numPeaks = size(peakInit, 1);
    dx = mean(diff(x));

    % --- 2. Construct Initial Vector (x0), Lower (lb), and Upper (ub) Bounds ---
    % Base peak parameters: [Centers (1..N), Sigmas (N+1..2N), Areas (2N+1..3N)]
    x0 = zeros(3*numPeaks, 1);
    lb = zeros(3*numPeaks, 1);
    ub = zeros(3*numPeaks, 1);

    for i = 1:numPeaks
        x0(i)              = peakInit(i, 1);                          % Center
        x0(numPeaks + i)    = peakInit(i, 3) / (2 * sqrt(2*log(2)));  % Sigma
        x0(2*numPeaks + i)   = peakInit(i, 2);                        % Area

        lb(i)              = peakInit(i, 1) - centerTol;
        ub(i)              = peakInit(i, 1) + centerTol;
        lb(numPeaks + i)    = fwhmLimits(1) / (2 * sqrt(2*log(2)));
        ub(numPeaks + i)    = fwhmLimits(2) / (2 * sqrt(2*log(2)));
        lb(2*numPeaks + i)   = 0;
        ub(2*numPeaks + i)   = sum(y) * abs(dx) * 3; % Physical upper bound
    end

    % Append Background Parameters to State Vector
    switch bkgType
        case 'none'
            % No extra state parameters
        case 'constant'
            x0 = [x0; min(y)];
            lb = [lb; 0];
            ub = [ub; max(y)];
        case 'linear'
            x0 = [x0; min(y); 0]; % [b0 (offset), b1 (slope)]
            lb = [lb; 0; -10];
            ub = [ub; max(y); 10];
    end

    % --- 3. Non-Linear Least Squares Optimization ---
    opts = optimoptions('lsqcurvefit', ...
        'Display', 'off', ...
        'MaxFunctionEvaluations', 50000, ...
        'MaxIterations', 2000, ...
        'FunctionTolerance', 1e-8, ...
        'StepTolerance', 1e-8);

    p_opt = lsqcurvefit(@(p, xdata) evalSpectrumModel(p, xdata, numPeaks, bkgType), ...
                       x0, x, y, lb, ub, opts);

    % --- 4. Unpack Results ---
    y_fit = evalSpectrumModel(p_opt, x, numPeaks, bkgType);

    fitResult.numPeaks = numPeaks;
    fitResult.centers  = p_opt(1:numPeaks);
    fitResult.sigmas   = p_opt(numPeaks+1 : 2*numPeaks);
    fitResult.fwhms    = fitResult.sigmas * (2 * sqrt(2 * log(2)));
    fitResult.areas    = p_opt(2*numPeaks+1 : 3*numPeaks);
    
    % Total area normalized fractions (%)
    fitResult.areaPercents = (fitResult.areas / sum(fitResult.areas)) * 100;

    % Background Parameters
    fitResult.bkgType = bkgType;
    if strcmp(bkgType, 'constant')
        fitResult.bkgOffset = p_opt(3*numPeaks + 1);
        fitResult.bkgSlope  = 0;
        fitResult.y_bkg     = repmat(fitResult.bkgOffset, size(x));
    elseif strcmp(bkgType, 'linear')
        fitResult.bkgOffset = p_opt(3*numPeaks + 1);
        fitResult.bkgSlope  = p_opt(3*numPeaks + 2);
        fitResult.y_bkg     = fitResult.bkgOffset + fitResult.bkgSlope * (x - min(x));
    else
        fitResult.bkgOffset = 0;
        fitResult.bkgSlope  = 0;
        fitResult.y_bkg     = zeros(size(x));
    end

    % Goodness of Fit Statistics
    ss_res = sum((y - y_fit).^2);
    ss_tot = sum((y - mean(y)).^2);
    fitResult.R2   = 1 - (ss_res / ss_tot);
    fitResult.RMSE = sqrt(ss_res / length(y));
end

% --- Internal Model Evaluator ---
function y_eval = evalSpectrumModel(p, x, numPeaks, bkgType)
    y_eval = zeros(size(x));
    
    % Evaluate Background
    if strcmp(bkgType, 'constant')
        y_eval = y_eval + p(3*numPeaks + 1);
    elseif strcmp(bkgType, 'linear')
        b0 = p(3*numPeaks + 1);
        b1 = p(3*numPeaks + 2);
        y_eval = y_eval + b0 + b1 * (x - min(x));
    end
    
    % Add Gaussian Peak Components
    for i = 1:numPeaks
        c   = p(i);
        sig = p(numPeaks + i);
        a   = p(2*numPeaks + i);
        y_eval = y_eval + (a / (sig * sqrt(2*pi))) * exp(-0.5 * ((x - c)/sig).^2);
    end
end