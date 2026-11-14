function comp = calculateComposition(c1sPeaks,f1sPeaks,SC,SF,alpha,scaling, ...
        sensitivityProfile,modelProfile)
%CALCULATECOMPOSITION Primary and diagnostic XPS composition calculations.
%
% IMPORTANT:
%   F/C is a ratio, not an atomic percentage.
%   F at.% = (F/C)/(1+F/C)*100
%
% Primary models are selected by stable peak ID or chemical assignment;
% array position is never chemical identity. Cross-region outputs restore
% software normalization and acquisition scaling before applying the
% sensitivity factors. If acquisition scaling is unknown, those outputs
% are withheld rather than silently assuming unity.
%
% Backward-compatible aliases (weighted, legacy, carbonBound, totalF) are
% retained for callers written before result schema 1.0.0. New code should
% use comp.primary and comp.diagnostics.

if nargin < 3 || isempty(SC), SC = 1.0; end
if nargin < 4 || isempty(SF), SF = 4.4118; end
if nargin < 5 || isempty(alpha), alpha = 0; end
if nargin < 6 || isempty(scaling), scaling = struct(); end
if nargin < 7 || isempty(sensitivityProfile)
    sensitivityProfile = numericSensitivityProfile(SC,SF);
end
if nargin < 8 || isempty(modelProfile)
    modelProfile = defaultModelProfile();
end

validateSensitivityInputs(SC,SF,sensitivityProfile);
validateModelProfile(modelProfile);

cIds = string({c1sPeaks.id});
A_sp2 = uniqueAreaByID(c1sPeaks,cIds,"sp2_C_C");
A_CF  = uniqueAreaByID(c1sPeaks,cIds,"C_F");
A_amb = uniqueAreaByID(c1sPeaks,cIds,"C_CF23_C_O");
A_CF2 = uniqueAreaByID(c1sPeaks,cIds,"CF2");
A_CF3 = uniqueAreaByID(c1sPeaks,cIds,"CF3");
A_Ctotal = sum([c1sPeaks.area]);
A_Cfilm = A_Ctotal;  % explicit current-model assumption

[scalingValid,scalingStatus,scalingMetadata,cMultiplier,fMultiplier] = ...
    scalingDetails(scaling);
if scalingValid
    A_Cphysical = A_Cfilm*cMultiplier;
else
    A_Cphysical = NaN;
end

comp.schema_id = "xps_composition_result";
comp.schema_version = "1.0.0";

% Primary 1: Ruoff main C-F component divided by total fitted C1s area.
mainModel = modelProfile.models.c1s_main_cf;
mainFC = A_CF/A_Ctotal;
mainQC = qcRecord(true,strings(0,1));
comp.primary.c1s_main_cf = standardResult(mainModel,"quantitative",mainFC, ...
    string(mainModel.numerator_peak_id), ...
    string(mainModel.numerator_chemical_label),strings(0,1), ...
    scalingMetadata,sensitivityProfile,mainQC);

% Primary 2: only the semi-covalent F-C component in its approved window.
semiModel = modelProfile.models.c1s_f1s_semi;
[semiIndices,semiWarnings] = selectSemiCovalentPeak(f1sPeaks,semiModel);
semiSelectionValid = isscalar(semiIndices);
semiCrossValid = scalingValid && semiSelectionValid;
if semiCrossValid
    A_Fsemi = f1sPeaks(semiIndices).area;
    A_FsemiPhysical = A_Fsemi*fMultiplier;
    semiFC = (A_FsemiPhysical/SF)/(A_Cphysical/SC);
    semiStatus = "quantitative";
else
    A_Fsemi = NaN;
    A_FsemiPhysical = NaN;
    semiFC = NaN;
    semiStatus = "withheld";
    if ~scalingValid
        semiWarnings(end+1,1) = scalingStatus;
    end
end
if semiSelectionValid
    semiIDs = peakIDs(f1sPeaks(semiIndices));
else
    semiIDs = strings(0,1);
end
excludedIndices = setdiff(1:numel(f1sPeaks),semiIndices,"stable");
excludedIDs = peakIDs(f1sPeaks(excludedIndices));
semiQC = qcRecord(semiCrossValid,semiWarnings);
comp.primary.c1s_f1s_semi = standardResult(semiModel,semiStatus,semiFC, ...
    semiIDs,string(semiModel.numerator_chemical_label),excludedIDs, ...
    scalingMetadata,sensitivityProfile,semiQC);

% Diagnostic C1s models retained without changing their equations.
legacyFC = ((A_Ctotal-A_sp2)/A_Ctotal)*(1/3);
legacyModel = diagnosticModel("legacy_c1s_v1","legacy_non_sp2_one_third", ...
    "F/C = ((A(C,total)-A(sp2))/A(C,total))*(1/3)", ...
    "all non-sp2 C1s components","sum of all fitted C1s component areas");
comp.diagnostics.legacy_c1s = standardResult(legacyModel,"diagnostic-only", ...
    legacyFC,setdiff(cIds,"sp2_C_C","stable"),"legacy non-sp2 C1s", ...
    strings(0,1),scalingMetadata,sensitivityProfile,qcRecord(true,strings(0,1)));

weightedFC = (A_CF + alpha*A_amb + 2*A_CF2 + 3*A_CF3)/A_Cfilm;
weightedModel = diagnosticModel("weighted_c1s_v1","weighted_c1s_stoichiometry", ...
    "F/C = (A(C-F)+alpha*A(ambiguous)+2*A(CF2)+3*A(CF3))/A(C,film)", ...
    "C_F, C_CF23_C_O, CF2, CF3","sum of fitted film C1s component areas");
comp.diagnostics.weighted_c1s = standardResult(weightedModel, ...
    "diagnostic-only",weightedFC,["C_F";"C_CF23_C_O";"CF2";"CF3"], ...
    "weighted C1s components",strings(0,1),scalingMetadata, ...
    sensitivityProfile,qcRecord(true,strings(0,1)));
comp.diagnostics.weighted_c1s.alpha = alpha;

% Previous semi+covalent carbon-bound and total-F diagnostics are kept.
carbonIndices = logicalField(f1sPeaks,"include_in_carbon_bound_F");
totalIndices = logicalField(f1sPeaks,"include_in_total_F");
A_Fcarbon = sumAreas(f1sPeaks,carbonIndices);
A_Ftotal = sumAreas(f1sPeaks,totalIndices);
if scalingValid
    A_FcarbonPhysical = A_Fcarbon*fMultiplier;
    A_FtotalPhysical = A_Ftotal*fMultiplier;
    carbonFC = (A_FcarbonPhysical/SF)/(A_Cphysical/SC);
    totalFC = (A_FtotalPhysical/SF)/(A_Cphysical/SC);
else
    A_FcarbonPhysical = NaN;
    A_FtotalPhysical = NaN;
    carbonFC = NaN;
    totalFC = NaN;
end
crossQC = qcRecord(scalingValid,conditionalWarning(scalingValid,scalingStatus));
carbonModel = diagnosticModel("previous_carbon_bound_f1s_v1", ...
    "semi_plus_covalent_f1s_over_c1s", ...
    "F/C = (A(F,flagged carbon-bound)/S_F)/(A(C,total)/S_C)", ...
    "F1s peaks flagged include_in_carbon_bound_F", ...
    "restored total fitted C1s area");
comp.diagnostics.carbon_bound_f1s_previous = standardResult(carbonModel, ...
    "diagnostic-only",carbonFC,peakIDs(f1sPeaks(carbonIndices)), ...
    "previous carbon-bound F definition",peakIDs(f1sPeaks(~carbonIndices)), ...
    scalingMetadata,sensitivityProfile,crossQC);
totalModel = diagnosticModel("total_f1s_v1","total_f1s_over_c1s", ...
    "F/C = (A(F,total)/S_F)/(A(C,total)/S_C)", ...
    "F1s peaks flagged include_in_total_F","restored total fitted C1s area");
comp.diagnostics.total_f1s = standardResult(totalModel,"diagnostic-only", ...
    totalFC,peakIDs(f1sPeaks(totalIndices)),"total included F1s", ...
    peakIDs(f1sPeaks(~totalIndices)),scalingMetadata,sensitivityProfile,crossQC);

% Backward-compatible fields and aliases.
comp.legacy = comp.diagnostics.legacy_c1s;
comp.weighted = comp.diagnostics.weighted_c1s;
comp.carbonBound = comp.diagnostics.carbon_bound_f1s_previous;
comp.totalF = comp.diagnostics.total_f1s;
comp.deprecated_aliases = struct( ...
    "legacy","diagnostics.legacy_c1s", ...
    "weighted","diagnostics.weighted_c1s", ...
    "carbonBound","diagnostics.carbon_bound_f1s_previous", ...
    "totalF","diagnostics.total_f1s");

comp.areas = struct( ...
    "A_Ctotal",A_Ctotal,"A_Cfilm",A_Cfilm,"A_sp2",A_sp2, ...
    "A_CF",A_CF,"A_ambiguous",A_amb,"A_CF2",A_CF2,"A_CF3",A_CF3, ...
    "A_F_semi_primary",A_Fsemi,"A_F_carbon_bound",A_Fcarbon, ...
    "A_F_total",A_Ftotal,"A_Cfilm_physical",A_Cphysical, ...
    "A_F_semi_primary_physical",A_FsemiPhysical, ...
    "A_F_carbon_bound_physical",A_FcarbonPhysical, ...
    "A_F_total_physical",A_FtotalPhysical);
comp.sensitivityFactors = struct("SC",SC,"SF",SF, ...
    "profile_id",string(sensitivityProfile.profile_id), ...
    "profile_version",string(sensitivityProfile.profile_version));
comp.scaling = scaling;
comp.scalingMultipliers = struct("C1s_fit_to_physical",cMultiplier, ...
    "F1s_fit_to_physical",fMultiplier);
comp.crossRegionValid = scalingValid;
comp.crossRegionAreaScaleStatus = scalingStatus;
end

function result = standardResult(model,status,FC,numeratorIDs,numeratorLabels, ...
        excludedIDs,scalingMetadata,sensitivityProfile,QC)
result.model_id = string(model.model_id);
result.model_version = string(model.model_version);
result.status = string(status);
result.equation_id = string(model.equation_id);
result.equation_text = string(model.equation_text);
result.numerator_peak_ids = string(numeratorIDs(:));
result.numerator_chemical_labels = string(numeratorLabels(:));
result.excluded_peak_ids = string(excludedIDs(:));
result.denominator_definition = string(model.denominator_definition);
result.normalization_restoration = scalingMetadata.normalization_restoration;
result.acquisition_scaling = scalingMetadata.acquisition_scaling;
result.sensitivity_factors = sensitivityMetadata(sensitivityProfile);
ratio = ratioFields(FC);
result.F_over_C = ratio.F_over_C;
result.F_atpct = ratio.F_atpct;
result.C_over_F = ratio.C_over_F;
result.CxF = ratio.CxF;
result.valid = ratio.valid && status ~= "withheld";
result.uncertainty = struct("status","not_estimated","value",NaN, ...
    "unit","not_applicable");
result.QC = QC;
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

function [indices,warnings] = selectSemiCovalentPeak(peaks,model)
warnings = strings(0,1);
if isempty(peaks) || ~isfield(peaks,"chemical_assignment")
    indices = [];
    warnings(end+1,1) = ...
        "Primary semi-covalent F1s result withheld: chemical_assignment is unavailable.";
    return
end
assignments = string({peaks.chemical_assignment});
assignmentMatch = assignments == string(model.numerator_chemical_assignment);
centers = peakCenters(peaks);
limits = double(model.allowed_center_range_eV(:));
rangeMatch = centers >= limits(1) & centers <= limits(2);
indices = find(assignmentMatch & rangeMatch);
outside = find(assignmentMatch & ~rangeMatch);
if ~isempty(outside)
    warnings(end+1,1) = sprintf( ...
        "Semi-covalent F-C assignment outside approved %.3f-%.3f eV window: %s.", ...
        limits(1),limits(2),strjoin(peakIDs(peaks(outside)),", "));
end
if isempty(indices)
    warnings(end+1,1) = ...
        "Primary semi-covalent F1s result withheld: no unique in-window semi-covalent F-C peak.";
elseif numel(indices) > 1
    warnings(end+1,1) = ...
        "Primary semi-covalent F1s result withheld: multiple in-window semi-covalent F-C peaks.";
end
end

function centers = peakCenters(peaks)
if isfield(peaks,"center_eV")
    centers = [peaks.center_eV];
elseif isfield(peaks,"center")
    centers = [peaks.center];
else
    centers = nan(1,numel(peaks));
end
end

function ids = peakIDs(peaks)
if isempty(peaks)
    ids = strings(0,1);
elseif isfield(peaks,"id")
    ids = string({peaks.id}).';
else
    ids = repmat("unidentified_peak",numel(peaks),1);
end
end

function flags = logicalField(peaks,fieldName)
if isempty(peaks) || ~isfield(peaks,fieldName)
    flags = false(1,numel(peaks));
else
    flags = logical([peaks.(fieldName)]);
end
end

function value = sumAreas(peaks,indices)
if isempty(peaks) || ~any(indices)
    value = 0;
else
    value = sum([peaks(indices).area]);
end
end

function area = uniqueAreaByID(peaks,ids,id)
match = ids == id;
if nnz(match) ~= 1
    error("xps:calculateComposition:PeakIDSelection", ...
        "Expected exactly one C1s peak with ID '%s'; found %d.",id,nnz(match));
end
area = peaks(match).area;
end

function model = diagnosticModel(id,equationID,equationText,numerator,denominator)
model = struct("model_id",id,"model_version","1.0.0", ...
    "equation_id",equationID,"equation_text",equationText, ...
    "numerator_peak_id",numerator,"numerator_chemical_label",numerator, ...
    "denominator_definition",denominator);
end

function QC = qcRecord(pass,warnings)
QC = struct("pass",logical(pass),"warnings",string(warnings(:)));
end

function warning = conditionalWarning(valid,status)
if valid
    warning = strings(0,1);
else
    warning = string(status);
end
end

function metadata = sensitivityMetadata(profile)
metadata = struct( ...
    "profile_id",string(profile.profile_id), ...
    "profile_version",string(profile.profile_version), ...
    "S_C",double(profile.S_C),"S_F",double(profile.S_F), ...
    "ratio_SF_over_SC",double(profile.S_F/profile.S_C), ...
    "status",string(profile.status), ...
    "source_provenance",string(profile.source_provenance), ...
    "intended_application",string(profile.intended_application));
end

function profile = numericSensitivityProfile(SC,SF)
profile = struct("profile_id","unversioned_numeric_input", ...
    "profile_version","0.0.0","S_C",SC,"S_F",SF, ...
    "status","caller_supplied", ...
    "source_provenance","Sensitivity factors supplied directly to calculateComposition.", ...
    "intended_application","Backward-compatible caller-defined calculation.");
end

function profile = defaultModelProfile()
packageFolder = fileparts(mfilename("fullpath"));
projectFolder = fileparts(packageFolder);
profile = xps.loadCompositionModelProfile(fullfile(projectFolder,"config", ...
    "composition","ruoff_primary_models_v1.json"));
end

function validateSensitivityInputs(SC,SF,profile)
if ~isscalar(SC) || ~isfinite(SC) || SC <= 0 || ...
        ~isscalar(SF) || ~isfinite(SF) || SF <= 0
    error("xps:calculateComposition:InvalidSensitivityFactor", ...
        "Sensitivity factors must be positive and finite.");
end
required = ["profile_id","profile_version","S_C","S_F","status", ...
    "source_provenance","intended_application"];
for field = required
    if ~isfield(profile,field)
        error("xps:calculateComposition:InvalidSensitivityProfile", ...
            "Sensitivity profile is missing '%s'.",field);
    end
end
if abs(double(profile.S_C)-SC) > 1e-12 || abs(double(profile.S_F)-SF) > 1e-12
    error("xps:calculateComposition:SensitivityProfileMismatch", ...
        "Numeric sensitivity factors must match the selected versioned profile.");
end
end

function validateModelProfile(profile)
if ~isstruct(profile) || ~isfield(profile,"models") || ...
        ~isfield(profile.models,"c1s_main_cf") || ...
        ~isfield(profile.models,"c1s_f1s_semi")
    error("xps:calculateComposition:InvalidModelProfile", ...
        "Composition model profile must define both primary models.");
end
end

function [valid,status,metadata,cMultiplier,fMultiplier] = scalingDetails(scaling)
valid = isstruct(scaling) && isfield(scaling,"C1s") && ...
    isfield(scaling,"F1s") && regionIsValid(scaling.C1s) && ...
    regionIsValid(scaling.F1s);
if valid
    status = "valid: software normalization restored and acquisition scaling supplied for both regions";
    cMultiplier = scaling.C1s.softwareNormalizationScale / scaling.C1s.acquisitionScale;
    fMultiplier = scaling.F1s.softwareNormalizationScale / scaling.F1s.acquisitionScale;
else
    status = "not physically validated: explicit C1s and F1s acquisition scaling is required";
    cMultiplier = NaN;
    fMultiplier = NaN;
end

if isstruct(scaling) && isfield(scaling,"C1s")
    cNorm = safeField(scaling.C1s,"softwareNormalizationScale",NaN);
    cKnown = logical(safeField(scaling.C1s,"acquisitionScaleKnown",false));
    cAcq = safeField(scaling.C1s,"acquisitionScale",NaN);
else
    cNorm = NaN; cKnown = false; cAcq = NaN;
end
if isstruct(scaling) && isfield(scaling,"F1s")
    fNorm = safeField(scaling.F1s,"softwareNormalizationScale",NaN);
    fKnown = logical(safeField(scaling.F1s,"acquisitionScaleKnown",false));
    fAcq = safeField(scaling.F1s,"acquisitionScale",NaN);
else
    fNorm = NaN; fKnown = false; fAcq = NaN;
end
metadata.normalization_restoration = struct( ...
    "definition","physical_area = fitted_area * software_normalization_scale / acquisition_scale_factor", ...
    "C1s_software_normalization_scale",cNorm, ...
    "F1s_software_normalization_scale",fNorm, ...
    "C1s_fit_to_physical_multiplier",cMultiplier, ...
    "F1s_fit_to_physical_multiplier",fMultiplier);
metadata.acquisition_scaling = struct( ...
    "status",string(status),"valid",valid, ...
    "C1s_known",cKnown,"C1s_scale",cAcq, ...
    "F1s_known",fKnown,"F1s_scale",fAcq);
end

function value = safeField(s,fieldName,defaultValue)
if isstruct(s) && isfield(s,fieldName)
    value = s.(fieldName);
else
    value = defaultValue;
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
