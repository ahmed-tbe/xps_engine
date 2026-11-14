function profile = loadCompositionModelProfile(filename)
%LOADCOMPOSITIONMODELPROFILE Load primary composition-model definitions.

arguments
    filename (1,1) string
end

if ~isfile(filename)
    error("xps:loadCompositionModelProfile:MissingFile", ...
        "Composition model profile not found: %s",filename);
end

profile = jsondecode(fileread(filename));
required = ["profile_id","profile_version","models"];
for i = 1:numel(required)
    if ~isfield(profile,required(i))
        error("xps:loadCompositionModelProfile:InvalidSchema", ...
            "Composition profile is missing required field '%s'.",required(i));
    end
end
if ~isfield(profile.models,"c1s_main_cf") || ...
        ~isfield(profile.models,"c1s_f1s_semi")
    error("xps:loadCompositionModelProfile:InvalidSchema", ...
        "Both primary model definitions are required.");
end

main = profile.models.c1s_main_cf;
semi = profile.models.c1s_f1s_semi;
requireFields(main,["model_id","model_version","equation_id", ...
    "equation_text","numerator_peak_id","numerator_chemical_label", ...
    "denominator_definition"]);
requireFields(semi,["model_id","model_version","equation_id", ...
    "equation_text","numerator_chemical_assignment", ...
    "numerator_chemical_label","allowed_center_range_eV", ...
    "denominator_definition","excluded_primary_numerator_assignments"]);
range = semi.allowed_center_range_eV;
if ~isnumeric(range) || numel(range) ~= 2 || ...
        any(~isfinite(range)) || range(1) >= range(2)
    error("xps:loadCompositionModelProfile:InvalidCenterRange", ...
        "Semi-covalent allowed_center_range_eV must be [lower upper].");
end

profile.source_file = filename;
end

function requireFields(value,required)
for i = 1:numel(required)
    if ~isfield(value,required(i))
        error("xps:loadCompositionModelProfile:InvalidSchema", ...
            "Model definition is missing required field '%s'.",required(i));
    end
end
end
