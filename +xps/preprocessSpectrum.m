function P = preprocessSpectrum(S, settings)
%PREPROCESSSPECTRUM Initial preprocessing from the tuning report.
%
% - maximum-intensity normalization
% - smooth AsLS background
% - fit the unsmoothed spectrum
%
% Cross-region elemental quantification should NOT blindly use independently
% normalized C1s and F1s areas. That issue is intentionally left explicit
% for the later C1s/F1s milestone.

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
