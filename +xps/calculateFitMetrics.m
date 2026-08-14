function M = calculateFitMetrics(y,yhat,k)
%CALCULATEFITMETRICS Basic fit-quality metrics.
y = y(:); yhat = yhat(:);
r = y-yhat;
n = numel(y);

M.RMSE = sqrt(mean(r.^2));
SSE = sum(r.^2);
SST = sum((y-mean(y)).^2);
M.R2 = 1-SSE/SST;
M.n = n;
M.k = k;
M.residual = r;

% Information criteria. These are only meaningful for comparing fits made
% to the same data under compatible likelihood assumptions.
sigma2 = max(SSE/n,eps);
M.AIC = n*log(sigma2)+2*k;
M.BIC = n*log(sigma2)+k*log(n);

if n-k-1 > 0
    M.AICc = M.AIC + (2*k*(k+1))/(n-k-1);
else
    M.AICc = NaN;
end
end
