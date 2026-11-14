function interval = wilsonInterval(k,n,confidence)
%WILSONINTERVAL Two-sided Wilson binomial confidence interval.

arguments
    k (1,1) double {mustBeInteger,mustBeNonnegative}
    n (1,1) double {mustBeInteger,mustBePositive}
    confidence (1,1) double {mustBeGreaterThan(confidence,0), ...
        mustBeLessThan(confidence,1)} = 0.95
end
if k > n,error("xpsh:wilsonInterval:InvalidCount","k cannot exceed n.");end

z = -sqrt(2)*erfcinv(2*(1-(1-confidence)/2));
p = k/n;
d = 1+z^2/n;
center = (p+z^2/(2*n))/d;
halfWidth = z*sqrt(p*(1-p)/n+z^2/(4*n^2))/d;
interval = struct("successes",k,"trials",n,"observed_rate",p, ...
    "confidence",confidence,"lower",max(0,center-halfWidth), ...
    "upper",min(1,center+halfWidth),"center",center, ...
    "half_width",halfWidth);
end
