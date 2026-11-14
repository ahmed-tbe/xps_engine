function written = writeCheckpoint(rootFolder,runFingerprint,cellKey,trialID,payload)
%WRITECHECKPOINT Atomically persist one immutable Phase 0H trial checkpoint.

arguments
    rootFolder (1,1) string
    runFingerprint (1,1) string
    cellKey (1,1) string
    trialID (1,1) double {mustBeInteger,mustBePositive}
    payload
end
if isempty(regexp(cellKey,'^[A-Za-z0-9_.-]+$','once'))
    error("xpsh:writeCheckpoint:UnsafeCellKey","Unsafe cell key '%s'.",cellKey);
end
cellFolder = fullfile(rootFolder,cellKey);
if ~isfolder(cellFolder),mkdir(cellFolder);end
finalFile = fullfile(cellFolder,compose("trial_%04d.mat",trialID));
if isfile(finalFile)
    existing = load(finalFile,"runFingerprint","trialID");
    if string(existing.runFingerprint) ~= runFingerprint || ...
            existing.trialID ~= trialID
        error("xpsh:writeCheckpoint:FingerprintMismatch", ...
            "Existing checkpoint does not match this run fingerprint/trial.");
    end
    written = false;
    return
end
temporaryFile = string(tempname(cellFolder))+".mat";
cleanup = onCleanup(@()deleteIfPresent(temporaryFile)); %#ok<NASGU>
save(temporaryFile,"runFingerprint","cellKey","trialID","payload","-v7");
[ok,message] = movefile(temporaryFile,finalFile);
if ~ok
    error("xpsh:writeCheckpoint:AtomicRenameFailed","%s",message);
end
written = true;
end

function deleteIfPresent(filename)
if isfile(filename),delete(filename);end
end
