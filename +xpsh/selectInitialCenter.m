function [center,metadata] = selectInitialCenter(truthCenter,halfWidth, ...
        allowedBounds,configuredInitialCenter,unitDraw)
%SELECTINITIALCENTER Deterministic legal center for moderate-start fixtures.
%
% If [truthCenter-halfWidth,truthCenter+halfWidth] intersects the legal
% bounds, retain the v1.0.0 rule: sample uniformly from that intersection.
% If the intersection is empty, do not use privileged shifted-truth
% knowledge. Use the configured nominal initial center, projected onto the
% inclusive legal bounds only as a defensive schema safeguard.

arguments
    truthCenter (1,1) double {mustBeFinite}
    halfWidth (1,1) double {mustBeFinite,mustBeNonnegative}
    allowedBounds (1,2) double {mustBeFinite}
    configuredInitialCenter (1,1) double {mustBeFinite}
    unitDraw (1,1) double {mustBeFinite}
end
lower=allowedBounds(1); upper=allowedBounds(2);
if ~(lower<upper)
    error("xpsh:selectInitialCenter:InvalidBounds", ...
        "Center bounds must be strictly increasing.");
end
if unitDraw<0 || unitDraw>1
    error("xpsh:selectInitialCenter:InvalidUnitDraw", ...
        "unitDraw must be in the inclusive interval [0,1].");
end
intersectionLower=max(lower,truthCenter-halfWidth);
intersectionUpper=min(upper,truthCenter+halfWidth);
if intersectionLower<=intersectionUpper
    center=intersectionLower+(intersectionUpper-intersectionLower)*unitDraw;
    rule="truth_interval_intersection_uniform";
else
    center=min(max(configuredInitialCenter,lower),upper);
    rule="configured_nominal_center_disjoint_truth_interval";
end
% Guard floating-point roundoff without widening the legal bounds.
center=min(max(center,lower),upper);
metadata=struct("rule",rule,"legal_bounds_eV",allowedBounds, ...
    "truth_interval_eV",[truthCenter-halfWidth,truthCenter+halfWidth], ...
    "intersection_eV",[intersectionLower,intersectionUpper], ...
    "intersection_exists",intersectionLower<=intersectionUpper, ...
    "configured_initial_center_eV",configuredInitialCenter, ...
    "unit_draw",unitDraw);
end
