function manifest = prepareRun(plan,outputFolder,projectFolder,runMode,action)
%PREPARERUN Create or strictly verify an execution manifest.

arguments
    plan (1,1) struct
    outputFolder (1,1) string
    projectFolder (1,1) string
    runMode (1,1) string {mustBeMember(runMode,["formal","smoke"])}
    action (1,1) string {mustBeMember(action,["start","resume"])}
end

current = xpsh.createManifest(plan,projectFolder,runMode);
manifestFile = fullfile(outputFolder,"manifest.json");
if action == "start"
    if isfolder(outputFolder) && ~isempty(dir(fullfile(outputFolder,"*")))
        error("xpsh:prepareRun:OutputNotEmpty", ...
            "Start requires a new or empty output folder: %s",outputFolder);
    end
    if ~isfolder(outputFolder),mkdir(outputFolder);end
    xpsh.writeJsonAtomic(manifestFile,current);
    writetable(xpsh.inventoryTable(plan),fullfile(outputFolder,"cell_inventory.csv"));
    if runMode == "formal"
        writetable(xpsh.seedSchedule(plan),fullfile(outputFolder,"seed_schedule.csv"));
    end
    manifest = current;
    return
end

if ~isfile(manifestFile)
    error("xpsh:prepareRun:MissingManifest", ...
        "Cannot resume because %s does not exist.",manifestFile);
end
manifest = jsondecode(fileread(manifestFile));
required = ["run_fingerprint","plan_sha256","code_config_fingerprint", ...
    "run_mode","cell_count","initial_trial_count"];
for field = required
    if ~isfield(manifest,field)
        error("xpsh:prepareRun:InvalidManifest", ...
            "Stored manifest is missing %s.",field);
    end
end
if string(manifest.run_mode) ~= runMode || ...
        string(manifest.plan_sha256) ~= string(current.plan_sha256) || ...
        string(manifest.code_config_fingerprint) ~= ...
            string(current.code_config_fingerprint) || ...
        string(manifest.run_fingerprint) ~= string(current.run_fingerprint) || ...
        manifest.cell_count ~= plan.cell_count || ...
        manifest.initial_trial_count ~= plan.initial_trial_count
    error("xpsh:prepareRun:FingerprintMismatch", ...
        ["Run manifest does not match the current frozen plan/code/config. " + ...
        "Keep the existing results immutable and start a new output folder."]);
end
end
