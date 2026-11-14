function written = writePhase0HExtensionCellCheckpoint(root,runFingerprint,cellDef)
%WRITEPHASE0HEXTENSIONCELLCHECKPOINT Finalize one 101:400 extension cell.
ids=xpsh.completedTrials(root,runFingerprint,string(cellDef.cell_key));
expected=(cellDef.extension_first_trial:cellDef.extension_last_trial).';
if ~isequal(ids,expected)
    error("writePhase0HExtensionCellCheckpoint:Incomplete", ...
        "Cell %s has %d/%d extension trials.",cellDef.cell_key,numel(ids),numel(expected));
end
xpsh.verifyCheckpointSeeds(root,runFingerprint,cellDef,ids);
folder=fullfile(root,cellDef.cell_key);file=fullfile(folder,"cell_complete.mat");
if isfile(file)
    v=load(file,"runFingerprint","cellKey","completedTrialIDs");
    if string(v.runFingerprint)~=runFingerprint || ...
            string(v.cellKey)~=string(cellDef.cell_key) || ...
            ~isequal(v.completedTrialIDs,expected)
        error("writePhase0HExtensionCellCheckpoint:FingerprintMismatch", ...
            "Existing cell completion checkpoint is incompatible.");
    end
    written=false;return
end
errors=0;converged=0;calls=0;elapsed=0;
for trialID=ids.'
    v=load(fullfile(folder,compose("trial_%04d.mat",trialID)),"payload");p=v.payload;
    errors=errors+double(string(p.status)=="error");
    converged=converged+double(isfield(p,"trial_converged")&&p.trial_converged);
    if isfield(p,"optimizer_invocations"),calls=calls+p.optimizer_invocations;end
    if isfield(p,"elapsed_seconds"),elapsed=elapsed+p.elapsed_seconds;end
end
completedTrialIDs=expected;cellKey=string(cellDef.cell_key);
summary=struct("cell_key",cellKey,"family_id",cellDef.family_id, ...
    "family_name",string(cellDef.family_name),"gate",string(cellDef.gate), ...
    "first_trial_id",cellDef.extension_first_trial, ...
    "last_trial_id",cellDef.extension_last_trial, ...
    "extension_trials",numel(ids),"final_combined_N",cellDef.final_trial_count, ...
    "error_trials",errors,"successful_trials",numel(ids)-errors, ...
    "converged_trials",converged, ...
    "convergence_wilson_95",xpsh.wilsonInterval(converged,numel(ids)), ...
    "optimizer_invocations",calls,"elapsed_seconds",elapsed, ...
    "status",conditional(errors));
temporary=string(tempname(folder))+".mat";
cleanup=onCleanup(@()deleteIfPresent(temporary)); %#ok<NASGU>
save(temporary,"runFingerprint","cellKey","completedTrialIDs","summary","-v7");
[ok,message]=movefile(temporary,file);if ~ok,error("writePhase0HExtensionCellCheckpoint:Rename","%s",message);end
xpsh.writeJsonAtomic(fullfile(folder,"cell_complete.json"),summary);written=true;
end
function value=conditional(errors),if errors==0,value="complete";else,value="complete_with_recorded_errors";end,end
function deleteIfPresent(file),if isfile(file),delete(file);end,end
