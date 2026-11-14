function reference = loadReference(filename)
%LOADREFERENCE Load and validate a reference-only JSON record.
%
% Reference data are reporting/evaluation inputs. This function does not
% modify a fit configuration and the optimizer never receives its output.

arguments
    filename (1,1) string
end

if ~isfile(filename)
    error("xps:loadReference:MissingFile", ...
        "Reference file not found: %s", filename);
end

reference = jsondecode(fileread(filename));
required = ["reference_id", "reference_version", "sample_id", "usage", ...
    "provenance", "direct_references", "project_benchmark_inputs", ...
    "model_applied_to_reference", "raw_data_files"];
for i = 1:numel(required)
    if ~isfield(reference, required(i))
        error("xps:loadReference:InvalidSchema", ...
            "Reference file is missing required field '%s'.", required(i));
    end
end

if string(reference.usage) ~= "reference_only_never_optimizer_input"
    error("xps:loadReference:InvalidUsage", ...
        "Reference file must be marked as reference-only.");
end

if ~isfield(reference.direct_references,"C1s_normal_emission") || ...
        ~isfield(reference.direct_references.C1s_normal_emission, ...
        "fractions_complete")
    error("xps:loadReference:InvalidSchema", ...
        "C1s_normal_emission must state fractions_complete.");
end

c1s = reference.direct_references.C1s_normal_emission;
if logical(c1s.fractions_complete)
    peaks = c1s.peaks;
    if iscell(peaks)
        fractions = cellfun(@(p) p.fraction_percent, peaks);
        ids = string(cellfun(@(p) p.id, peaks, "UniformOutput", false));
    else
        fractions = [peaks.fraction_percent];
        ids = string({peaks.id});
    end
    if isempty(peaks) || numel(unique(ids)) ~= numel(ids) || ...
            abs(sum(fractions)-100) > 1e-10
        error("xps:loadReference:InvalidC1sFractions", ...
            "Complete C1s reference IDs must be unique and fractions must sum to 100%%.");
    end
elseif ~isfield(c1s,"availability_note") || isempty(c1s.availability_note)
    error("xps:loadReference:MissingAvailabilityNote", ...
        "An incomplete C1s reference must explain which data are unavailable.");
end

main = reference.direct_references.main_C_F_fraction;
if ~isscalar(main.fraction) || ~isfinite(main.fraction) || ...
        main.fraction < 0 || main.fraction > 1 || string(main.peak_id) ~= "C_F"
    error("xps:loadReference:InvalidMainCFFraction", ...
        "main_C_F_fraction must be a fraction in [0,1] for peak ID C_F.");
end

if ~isfield(reference.direct_references, ...
        "model_specific_fluorine_atomic_percent")
    error("xps:loadReference:MissingModelSpecificReferences", ...
        "Model-specific fluorine atomic-percent references are required.");
end
modelRefs = reference.direct_references. ...
    model_specific_fluorine_atomic_percent;
requiredModels = ["ruoff_c1s_main_cf_v1", ...
    "ruoff_c1s_f1s_semi_sf3p95_v1"];
for modelID = requiredModels
    if ~isfield(modelRefs,modelID)
        error("xps:loadReference:MissingModelReference", ...
            "Missing fluorine reference for model '%s'.",modelID);
    end
    validateModelReference(modelRefs.(modelID),modelID);
end

reference.source_file = filename;
end

function validateModelReference(value,modelID)
required = ["reference_type","unit","provenance"];
for field = required
    if ~isfield(value,field)
        error("xps:loadReference:InvalidModelReference", ...
            "Reference '%s' is missing '%s'.",modelID,field);
    end
end
if string(value.unit) ~= "atomic_percent_F" || isempty(value.provenance)
    error("xps:loadReference:InvalidModelReference", ...
        "Reference '%s' must have atomic-percent units and provenance.",modelID);
end
switch string(value.reference_type)
    case "scalar"
        valid = isfield(value,"value") && isscalar(value.value) && ...
            isfinite(value.value) && value.value >= 0 && value.value <= 100;
    case "range"
        valid = isfield(value,"lower") && isfield(value,"upper") && ...
            isscalar(value.lower) && isscalar(value.upper) && ...
            isfinite(value.lower) && isfinite(value.upper) && ...
            value.lower >= 0 && value.upper <= 100 && ...
            value.lower <= value.upper;
    otherwise
        valid = false;
end
if ~valid
    error("xps:loadReference:InvalidModelReference", ...
        "Reference '%s' has an invalid scalar/range definition.",modelID);
end
end
