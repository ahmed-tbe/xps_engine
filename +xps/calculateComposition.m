function comp = calculateComposition(c1sPeaks,f1sPeaks,SC,SF,alpha,scaling)
%CALCULATECOMPOSITION Legacy and candidate composition calculations.
%
% IMPORTANT:
%   F/C is a ratio, not an atomic percentage.
%   F at.% = (F/C)/(1+F/C)*100
%
% The first milestone locks alpha=0 and the legacy C1s expression.
% The C1s-only ratios are invariant to one common C1s scale. Cross-region
% outputs require an explicit scaling structure produced by
% xps.buildQuantificationScaling. Missing acquisition factors invalidate
% cross-region outputs instead of silently assuming unity.

if nargin < 3 || isempty(SC), SC = 1.0; end
if nargin < 4 || isempty(SF), SF = 4.4118; end
if nargin < 5 || isempty(alpha), alpha = 0; end
if nargin < 6 || isempty(scaling), scaling = struct(); end

if ~isscalar(SC) || ~isfinite(SC) || SC <= 0 || ...
        ~isscalar(SF) || ~isfinite(SF) || SF <= 0
    error("xps:calculateComposition:InvalidSensitivityFactor", ...
        "Sensitivity factors must be positive and finite.");
end

ids = string({c1sPeaks.id});
A = @(id) c1sPeaks(ids==id).area;

A_sp2 = A("sp2_C_C");
A_CF  = A("C_F");
A_amb = A("C_CF23_C_O");
A_CF2 = A("CF2");
A_CF3 = A("CF3");
A_Ctotal = sum([c1sPeaks.area]);
A_Cfilm = A_Ctotal;  % explicit milestone-1 assumption

% Locked legacy C1s model
legacyFC = ((A_Ctotal-A_sp2)/A_Ctotal)*(1/3);
comp.legacy = ratioFields(legacyFC);

% Weighted C1s candidate
weightedFC = (A_CF + alpha*A_amb + 2*A_CF2 + 3*A_CF3)/A_Cfilm;
comp.weighted = ratioFields(weightedFC);
comp.weighted.alpha = alpha;

% F1s fit-scale areas
AfCarbon = sum([f1sPeaks([f1sPeaks.include_in_carbon_bound_F]).area]);
AfTotal  = sum([f1sPeaks([f1sPeaks.include_in_total_F]).area]);

% Cross-region quantification: reverse software normalization first, then
% acquisition scaling, then apply the independent sensitivity factors.
[scalingValid, scalingStatus] = validateScaling(scaling);
if scalingValid
    cPhysicalMultiplier = scaling.C1s.softwareNormalizationScale / ...
        scaling.C1s.acquisitionScale;
    fPhysicalMultiplier = scaling.F1s.softwareNormalizationScale / ...
        scaling.F1s.acquisitionScale;
    A_Cphysical = A_Cfilm*cPhysicalMultiplier;
    AfCarbonPhysical = AfCarbon*fPhysicalMultiplier;
    AfTotalPhysical = AfTotal*fPhysicalMultiplier;
    carbonBoundFC = (AfCarbonPhysical/SF)/(A_Cphysical/SC);
    totalFFC = (AfTotalPhysical/SF)/(A_Cphysical/SC);
else
    cPhysicalMultiplier = NaN;
    fPhysicalMultiplier = NaN;
    A_Cphysical = NaN;
    AfCarbonPhysical = NaN;
    AfTotalPhysical = NaN;
    carbonBoundFC = NaN;
    totalFFC = NaN;
end

comp.carbonBound = ratioFields(carbonBoundFC);
comp.totalF = ratioFields(totalFFC);

comp.areas = struct( ...
    "A_Ctotal",A_Ctotal, ...
    "A_Cfilm",A_Cfilm, ...
    "A_sp2",A_sp2, ...
    "A_CF",A_CF, ...
    "A_ambiguous",A_amb, ...
    "A_CF2",A_CF2, ...
    "A_CF3",A_CF3, ...
    "A_F_carbon_bound",AfCarbon, ...
    "A_F_total",AfTotal, ...
    "A_Cfilm_physical",A_Cphysical, ...
    "A_F_carbon_bound_physical",AfCarbonPhysical, ...
    "A_F_total_physical",AfTotalPhysical);

comp.sensitivityFactors = struct("SC",SC,"SF",SF);
comp.scaling = scaling;
comp.scalingMultipliers = struct( ...
    "C1s_fit_to_physical", cPhysicalMultiplier, ...
    "F1s_fit_to_physical", fPhysicalMultiplier);
comp.crossRegionValid = scalingValid;
comp.crossRegionAreaScaleStatus = scalingStatus;
end

function out = ratioFields(FC)
out.F_over_C = FC;
if isfinite(FC) && FC > 0
    out.F_atpct = FC/(1+FC)*100;
    out.C_over_F = 1/FC;
    out.CxF = sprintf("C%.3gF",1/FC);
    out.valid = true;
else
    out.F_atpct = NaN;
    out.C_over_F = NaN;
    out.CxF = "not_valid";
    out.valid = false;
end
end

function [valid, status] = validateScaling(scaling)
valid = isstruct(scaling) && isfield(scaling,"C1s") && ...
    isfield(scaling,"F1s") && ...
    regionIsValid(scaling.C1s) && regionIsValid(scaling.F1s);
if valid
    status = "valid: software normalization restored and acquisition scaling supplied for both regions";
else
    status = "not physically validated: explicit C1s and F1s acquisition scaling is required";
end
end

function valid = regionIsValid(region)
valid = isstruct(region) && ...
    isfield(region,"softwareNormalizationScale") && ...
    isscalar(region.softwareNormalizationScale) && ...
    isfinite(region.softwareNormalizationScale) && ...
    region.softwareNormalizationScale > 0 && ...
    isfield(region,"acquisitionScaleKnown") && ...
    isscalar(region.acquisitionScaleKnown) && ...
    logical(region.acquisitionScaleKnown) && ...
    isfield(region,"acquisitionScale") && ...
    isscalar(region.acquisitionScale) && ...
    isfinite(region.acquisitionScale) && region.acquisitionScale > 0;
end
