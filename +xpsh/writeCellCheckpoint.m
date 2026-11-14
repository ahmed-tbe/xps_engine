function written = writeCellCheckpoint(checkpointRoot,runFingerprint,cellDefinition)
%WRITECELLCHECKPOINT Persist an immutable summary after a completed cell.

arguments
    checkpointRoot (1,1) string
    runFingerprint (1,1) string
    cellDefinition (1,1) struct
end

trialIDs = xpsh.completedTrials(checkpointRoot,runFingerprint, ...
    string(cellDefinition.cell_key));
expected = (1:cellDefinition.trials).';
if ~isequal(trialIDs,expected)
    error("xpsh:writeCellCheckpoint:IncompleteCell", ...
        "Cell %s has %d/%d trial checkpoints.",cellDefinition.cell_key, ...
        numel(trialIDs),cellDefinition.trials);
end
xpsh.verifyCheckpointSeeds(checkpointRoot,runFingerprint,cellDefinition,trialIDs);

cellFolder = fullfile(checkpointRoot,cellDefinition.cell_key);
finalFile = fullfile(cellFolder,"cell_complete.mat");
if isfile(finalFile)
    existing = load(finalFile,"runFingerprint","cellKey","completedTrialIDs");
    if string(existing.runFingerprint) ~= runFingerprint || ...
            string(existing.cellKey) ~= string(cellDefinition.cell_key) || ...
            ~isequal(existing.completedTrialIDs,expected)
        error("xpsh:writeCellCheckpoint:FingerprintMismatch", ...
            "Existing cell checkpoint does not match this run.");
    end
    written = false;
    return
end

errorCount = 0; convergenceCount = 0; optimizerCalls = 0;
elapsedSeconds = 0;
for trialID = trialIDs.'
    value = load(fullfile(cellFolder,compose("trial_%04d.mat",trialID)),"payload");
    payload = value.payload;
    errorCount = errorCount + double(string(payload.status)=="error");
    if isfield(payload,"trial_converged")
        convergenceCount = convergenceCount + double(payload.trial_converged);
    end
    if isfield(payload,"optimizer_invocations")
        optimizerCalls = optimizerCalls + payload.optimizer_invocations;
    end
    if isfield(payload,"elapsed_seconds")
        elapsedSeconds = elapsedSeconds + payload.elapsed_seconds;
    end
end
completedTrialIDs = expected;
cellKey = string(cellDefinition.cell_key);
summary = struct("cell_key",cellKey,"family_id",cellDefinition.family_id, ...
    "family_name",string(cellDefinition.family_name), ...
    "planned_trials",cellDefinition.trials, ...
    "completed_trials",numel(trialIDs),"error_trials",errorCount, ...
    "successful_trials",numel(trialIDs)-errorCount, ...
    "converged_trials",convergenceCount, ...
    "convergence_wilson_95",xpsh.wilsonInterval(convergenceCount,numel(trialIDs)), ...
    "optimizer_invocations",optimizerCalls, ...
    "elapsed_seconds",elapsedSeconds,"next_eligible_trial_id",NaN, ...
    "status",conditionalStatus(errorCount));

temporary = string(tempname(cellFolder))+".mat";
cleanup = onCleanup(@()deleteIfPresent(temporary)); %#ok<NASGU>
save(temporary,"runFingerprint","cellKey","completedTrialIDs","summary","-v7");
[ok,message] = movefile(temporary,finalFile);
if ~ok,error("xpsh:writeCellCheckpoint:AtomicRenameFailed","%s",message);end
xpsh.writeJsonAtomic(fullfile(cellFolder,"cell_complete.json"),summary);
written = true;
end

function value = conditionalStatus(errorCount)
if errorCount==0,value="complete";else,value="complete_with_recorded_errors";end
end

function deleteIfPresent(filename)
if isfile(filename),delete(filename);end
end
