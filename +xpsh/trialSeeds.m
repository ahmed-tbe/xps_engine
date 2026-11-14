function seeds = trialSeeds(cellDefinition,trialID)
%TRIALSEEDS Deterministic seed record for one Phase 0H trial.

arguments
    cellDefinition (1,1) struct
    trialID (1,1) double {mustBeInteger,mustBePositive}
end

names = ["C_noise","F_noise","C_center","F_center","C_area", ...
    "F_area","C_width","F_width","C_order","F_order", ...
    "C_acquisition","F_acquisition","charging_shift"];
streamIDs = [1,2,11,12,21,22,31,32,41,42,51,52,61];
for i = 1:numel(names)
    seeds.(names(i)) = xpsh.seedFor(cellDefinition.family_id, ...
        cellDefinition.cell_index,trialID,streamIDs(i));
end
end
