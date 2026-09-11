function scaling = buildQuantificationScaling(Cpre, Fpre, acquisitionConfig)
%BUILDQUANTIFICATIONSCALING Assemble explicit cross-region area scaling.
%
% Definitions:
%   recorded raw area = fitted normalized area * software normalization scale
%   physical area     = recorded raw area / acquisition scale factor
%
% Sensitivity factors are intentionally not applied here; they remain an
% independent input to xps.calculateComposition.

arguments
    Cpre (1,1) struct
    Fpre (1,1) struct
    acquisitionConfig (1,1) struct
end

scaling.definition = ...
    "physical_area = fitted_area * software_normalization_scale / acquisition_scale_factor";
scaling.C1s = regionScaling(Cpre, acquisitionConfig, "C1s");
scaling.F1s = regionScaling(Fpre, acquisitionConfig, "F1s");
scaling.validForCrossRegion = scaling.C1s.acquisitionScaleKnown && ...
    scaling.F1s.acquisitionScaleKnown;

if scaling.validForCrossRegion
    scaling.status = "valid: software and acquisition scaling are explicit for both regions";
else
    scaling.status = "not physically validated: acquisition scaling is unknown for one or both regions";
end
end

function out = regionScaling(pre, acquisitionConfig, regionName)
if isfield(pre, "softwareNormalizationScale")
    softwareScale = pre.softwareNormalizationScale;
elseif isfield(pre, "scale")
    softwareScale = pre.scale;
else
    error("xps:buildQuantificationScaling:MissingSoftwareScale", ...
        "%s preprocessing result has no software normalization scale.", regionName);
end

if ~isscalar(softwareScale) || ~isfinite(softwareScale) || softwareScale <= 0
    error("xps:buildQuantificationScaling:InvalidSoftwareScale", ...
        "%s software normalization scale must be positive and finite.", regionName);
end

if ~isfield(acquisitionConfig, regionName)
    error("xps:buildQuantificationScaling:MissingAcquisitionRegion", ...
        "Acquisition configuration is missing %s.", regionName);
end
cfg = acquisitionConfig.(regionName);
known = isfield(cfg, "known") && logical(cfg.known);

if known
    if ~isfield(cfg, "scale_factor") || isempty(cfg.scale_factor) || ...
            ~isscalar(cfg.scale_factor) || ~isfinite(cfg.scale_factor) || ...
            cfg.scale_factor <= 0
        error("xps:buildQuantificationScaling:InvalidAcquisitionScale", ...
            "%s acquisition scale is marked known but is not positive and finite.", ...
            regionName);
    end
    acquisitionScale = cfg.scale_factor;
    physicalMultiplier = softwareScale/acquisitionScale;
else
    acquisitionScale = NaN;
    physicalMultiplier = NaN;
end

provenance = "unspecified";
if isfield(cfg, "provenance")
    provenance = string(cfg.provenance);
end

out = struct( ...
    "softwareNormalizationScale", softwareScale, ...
    "acquisitionScaleKnown", known, ...
    "acquisitionScale", acquisitionScale, ...
    "acquisitionProvenance", provenance, ...
    "recordedRawAreaMultiplier", softwareScale, ...
    "physicalAreaMultiplier", physicalMultiplier);
end
