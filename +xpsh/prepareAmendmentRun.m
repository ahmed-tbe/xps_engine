function manifest = prepareAmendmentRun(plan,outputFolder,projectFolder, ...
        runMode,action)
%PREPAREAMENDMENTRUN Create or verify an isolated amendment manifest.

arguments
    plan (1,1) struct
    outputFolder (1,1) string
    projectFolder (1,1) string
    runMode (1,1) string {mustBeMember(runMode,["amendment","amendment_smoke"])}
    action (1,1) string {mustBeMember(action,["start","resume"])}
end
current=xpsh.createAmendmentManifest(plan,projectFolder,runMode);
manifestFile=fullfile(outputFolder,"manifest.json");
if action=="start"
    if isfolder(outputFolder) && ~isempty(dir(fullfile(outputFolder,"*")))
        error("xpsh:prepareAmendmentRun:OutputNotEmpty", ...
            "Start requires a new or empty amendment output: %s",outputFolder);
    end
    if ~isfolder(outputFolder),mkdir(outputFolder);end
    xpsh.writeJsonAtomic(manifestFile,current);
    writetable(xpsh.inventoryTable(plan),fullfile(outputFolder,"cell_inventory.csv"));
    writetable(xpsh.seedSchedule(plan),fullfile(outputFolder,"seed_schedule.csv"));
    manifest=current;
    return
end
if ~isfile(manifestFile)
    error("xpsh:prepareAmendmentRun:MissingManifest", ...
        "Cannot resume because %s does not exist.",manifestFile);
end
manifest=jsondecode(fileread(manifestFile));
fields=["run_fingerprint","amended_execution_fingerprint", ...
    "code_config_fingerprint","plan_sha256","run_mode"];
for field=fields
    if ~isfield(manifest,field)
        error("xpsh:prepareAmendmentRun:InvalidManifest", ...
            "Stored amendment manifest is missing %s.",field);
    end
end
if string(manifest.run_mode)~=runMode || ...
        string(manifest.run_fingerprint)~=string(current.run_fingerprint) || ...
        string(manifest.amended_execution_fingerprint)~= ...
            string(current.amended_execution_fingerprint) || ...
        string(manifest.code_config_fingerprint)~= ...
            string(current.code_config_fingerprint)
    error("xpsh:prepareAmendmentRun:FingerprintMismatch", ...
        "Amendment code/config differs; preserve output and start a new version.");
end
end
