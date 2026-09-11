function [background, info] = estimateBackground(x, y, settings)
%ESTIMATEBACKGROUND Dispatch a configured XPS background estimator.
%
% The method and effective parameters are returned so every analysis can
% report and persist the exact preprocessing choice.

x = x(:);
y = y(:);
if numel(x) ~= numel(y)
    error("xps:estimateBackground:SizeMismatch", ...
        "Energy and intensity must have the same length.");
end
if ~isfield(settings, "background")
    error("xps:estimateBackground:MissingMethod", ...
        "Preprocessing settings must specify a background method.");
end

method = lower(string(settings.background));
switch method
    case "linear"
        opts = struct("n_pts", settingOr(settings, "linear_n_points", 5));
        [background, parameters] = xps_backgrounds(x, y, "linear", opts);

    case "shirley"
        opts = struct( ...
            "n_pts", settingOr(settings, "shirley_n_points", 5), ...
            "max_iter", settingOr(settings, "shirley_max_iterations", 50), ...
            "tol", settingOr(settings, "shirley_tolerance", 1e-5));
        [background, parameters] = xps_backgrounds(x, y, "shirley", opts);

    case "asls"
        lambda = settingOr(settings, "asls_lambda", 1e6);
        p = settingOr(settings, "asls_p", 0.01);
        iterations = settingOr(settings, "asls_iterations", 20);
        background = xps.estimateAsLS(y, lambda, p, iterations);
        parameters = struct("type", "asls", "lambda", lambda, ...
            "p", p, "iterations", iterations);

    case "tougaard"
        opts = struct("B", settingOr(settings, "tougaard_B", 2866), ...
            "C", settingOr(settings, "tougaard_C", 1643));
        [background, parameters] = xps_backgrounds(x, y, "tougaard", opts);

    otherwise
        error("xps:estimateBackground:UnsupportedMethod", ...
            "Background '%s' is not supported.", method);
end

background = background(:);
info = struct("method", method, "parameters", parameters);
end

function value = settingOr(settings, name, defaultValue)
if isfield(settings, name) && ~isempty(settings.(name))
    value = settings.(name);
else
    value = defaultValue;
end
end
