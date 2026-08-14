function z = estimateAsLS(y, lambda, p, niter)
%ESTIMATEASLS Asymmetric least-squares baseline.
%
% Based on the standard Eilers/Boelens-style AsLS formulation.
% This is a preprocessing baseline, not a peak-fitting component.

y = y(:);
n = numel(y);

D = spdiags(ones(n-2,1)*[1 -2 1], 0:2, n-2, n);
w = ones(n,1);

for k = 1:niter
    W = spdiags(w,0,n,n);
    z = (W + lambda*(D'*D)) \ (w.*y);
    w = p*(y > z) + (1-p)*(y <= z);
end
end
