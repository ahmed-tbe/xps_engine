function verifyCheckpointSeeds(checkpointRoot,runFingerprint,cellDefinition,trialIDs)
%VERIFYCHECKPOINTSEEDS Reject altered seed records before resume.

for trialID = trialIDs(:).'
    filename = fullfile(checkpointRoot,cellDefinition.cell_key, ...
        compose("trial_%04d.mat",trialID));
    value = load(filename,"runFingerprint","cellKey","trialID","payload");
    if string(value.runFingerprint) ~= runFingerprint || ...
            string(value.cellKey) ~= string(cellDefinition.cell_key) || ...
            value.trialID ~= trialID
        error("xpsh:verifyCheckpointSeeds:IdentityMismatch", ...
            "Checkpoint identity mismatch in %s.",filename);
    end
    if ~isfield(value.payload,"seeds") || ...
            ~isequaln(value.payload.seeds,xpsh.trialSeeds(cellDefinition,trialID))
        error("xpsh:verifyCheckpointSeeds:SeedMismatch", ...
            "Stored seeds do not match the frozen schedule in %s.",filename);
    end
end
end
