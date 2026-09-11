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
required = ["reference_id", "reference_version", "usage", ...
    "provenance", "direct_references"];
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

peaks = reference.direct_references.C1s_normal_emission.peaks;
if iscell(peaks)
    fractions = cellfun(@(p) p.fraction_percent, peaks);
    ids = string(cellfun(@(p) p.id, peaks, "UniformOutput", false));
else
    fractions = [peaks.fraction_percent];
    ids = string({peaks.id});
end

if numel(unique(ids)) ~= numel(ids) || abs(sum(fractions)-100) > 1e-10
    error("xps:loadReference:InvalidC1sFractions", ...
        "C1s reference IDs must be unique and fractions must sum to 100%%.");
end

reference.source_file = filename;
end
