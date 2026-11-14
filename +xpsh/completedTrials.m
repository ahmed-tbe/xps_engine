function trialIDs = completedTrials(rootFolder,runFingerprint,cellKey)
%COMPLETEDTRIALS Return verified completed trial IDs for deterministic resume.

arguments
    rootFolder (1,1) string
    runFingerprint (1,1) string
    cellKey (1,1) string
end
cellFolder = fullfile(rootFolder,cellKey);
if ~isfolder(cellFolder),trialIDs=zeros(0,1);return;end
files = dir(fullfile(cellFolder,"trial_*.mat"));
trialIDs = zeros(numel(files),1);
for i = 1:numel(files)
    value = load(fullfile(files(i).folder,files(i).name), ...
        "runFingerprint","cellKey","trialID");
    if string(value.runFingerprint) ~= runFingerprint || ...
            string(value.cellKey) ~= cellKey
        error("xpsh:completedTrials:FingerprintMismatch", ...
            "Checkpoint '%s' belongs to another run.",files(i).name);
    end
    trialIDs(i) = value.trialID;
end
trialIDs = sort(unique(trialIDs));
end
