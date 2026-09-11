function P = preprocessSpectrum(S, settings)
%PREPROCESSSPECTRUM Initial preprocessing from the tuning report.
%
% - maximum-intensity normalization (when configured)
% - configured background estimator (AsLS, linear, Shirley, or Tougaard)
% - fit the unsmoothed spectrum
%
% P.softwareNormalizationScale is the numerical divisor used for
% yNorm = y/P.softwareNormalizationScale. A fitted area must be multiplied
% by that value to return to recorded raw-intensity units. This does not
% correct experimental/acquisition scaling or XPS sensitivity factors.

x = S.energyFit;
y = S.intensityFit;

normalizationMethod = lower(string(settings.normalization));
switch normalizationMethod
    case "max"
        scale = max(y);
        if ~isfinite(scale) || scale <= 0
            error("xps:preprocessSpectrum:InvalidScale", ...
                "Cannot max-normalize a spectrum with nonpositive/nonfinite maximum.");
        end
        yNorm = y/scale;
    case "none"
        scale = 1;
        yNorm = y;
    otherwise
        error("xps:preprocessSpectrum:UnsupportedNormalization", ...
            "Normalization '%s' is not supported.", normalizationMethod);
end

[bkg, backgroundInfo] = xps.estimateBackground(x, yNorm, settings);

P.energy = x;
P.raw = y;
P.normalized = yNorm;
P.background = bkg;
P.y_fit = yNorm - bkg;
P.normalization_method = normalizationMethod;
P.softwareNormalizationScale = scale;
P.scale = scale;
P.background_method = backgroundInfo.method;
P.background_parameters = backgroundInfo.parameters;
P.preprocessing_settings = settings;
P.original = S;
end
