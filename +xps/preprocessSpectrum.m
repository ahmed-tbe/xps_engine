function P = preprocessSpectrum(S, settings)
%PREPROCESSSPECTRUM Initial preprocessing from the tuning report.
%
% - maximum-intensity normalization (when configured)
% - smooth AsLS background
% - fit the unsmoothed spectrum
%
% P.scale is the raw maximum intensity used for yNorm = y/P.scale. Thus a
% fitted area in P.y_fit units must be multiplied by P.scale to return to
% the raw-intensity scale (provided the background subtraction is treated
% consistently). Cross-region elemental quantification must not blindly
% divide independently normalized C1s and F1s areas.

x = S.energyFit;
y = S.intensityFit;

if strcmpi(settings.normalization,"max")
    scale = max(y);
    if scale == 0
        error("Cannot max-normalize a zero spectrum.");
    end
    yNorm = y/scale;
else
    scale = 1;
    yNorm = y;
end

switch lower(settings.background)
    case "asls"
        bkg = xps.estimateAsLS(yNorm, ...
            settings.asls_lambda, settings.asls_p, settings.asls_iterations);
    otherwise
        error("Background '%s' is not implemented in this milestone.", ...
            settings.background);
end

P.energy = x;
P.raw = y;
P.normalized = yNorm;
P.background = bkg;
P.y_fit = yNorm - bkg;
P.scale = scale;
P.original = S;
end
