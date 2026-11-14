function profile = loadSensitivityProfile(filename)
%LOADSENSITIVITYPROFILE Load and validate a versioned sensitivity profile.

arguments
    filename (1,1) string
end

if ~isfile(filename)
    error("xps:loadSensitivityProfile:MissingFile", ...
        "Sensitivity profile not found: %s",filename);
end

profile = jsondecode(fileread(filename));
required = ["profile_id","profile_version","S_C","S_F", ...
    "ratio_definition","ratio_value","status", ...
    "source_provenance","intended_application"];
for i = 1:numel(required)
    if ~isfield(profile,required(i))
        error("xps:loadSensitivityProfile:InvalidSchema", ...
            "Sensitivity profile is missing required field '%s'.",required(i));
    end
end

if ~isscalar(profile.S_C) || ~isfinite(profile.S_C) || profile.S_C <= 0 || ...
        ~isscalar(profile.S_F) || ~isfinite(profile.S_F) || profile.S_F <= 0
    error("xps:loadSensitivityProfile:InvalidFactor", ...
        "S_C and S_F must be positive finite scalars.");
end

expectedRatio = profile.S_F/profile.S_C;
if ~isscalar(profile.ratio_value) || ~isfinite(profile.ratio_value) || ...
        abs(profile.ratio_value-expectedRatio) > ...
        10*eps(max(1,abs(expectedRatio)))
    error("xps:loadSensitivityProfile:InvalidRatio", ...
        "ratio_value must equal S_F/S_C.");
end

profile.source_file = filename;
end
