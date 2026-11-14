function result = residualAutocorrelation(residual,observed)
%RESIDUALAUTOCORRELATION Lag-1 rule including effectively-zero variance.

residual = residual(:); observed = observed(:);
if numel(residual) ~= numel(observed) || isempty(residual)
    error("xpsh:residualAutocorrelation:InvalidInput", ...
        "Residual and observed vectors must be nonempty and equal length.");
end
d = residual-mean(residual);
D = sum(d.^2);
tau = 100*eps(1)*max(1,sum((observed-mean(observed)).^2));
effectivelyZero = D <= tau;
if effectivelyZero || numel(d) < 2
    rho1 = 0;
else
    rho1 = sum(d(1:end-1).*d(2:end))/D;
end
result = struct("rho1",rho1, ...
    "ResidualVarianceEffectivelyZero",effectivelyZero, ...
    "variance_sum",D,"threshold",tau);
end
