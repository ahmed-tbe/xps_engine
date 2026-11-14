function manifest = preparePhase0HExtensionRun(plan,outputFolder,projectFolder,action)
%PREPAREPHASE0HEXTENSIONRUN Create or verify the isolated extension run.
arguments
    plan (1,1) struct
    outputFolder (1,1) string
    projectFolder (1,1) string
    action (1,1) string {mustBeMember(action,["start","resume"])}
end
current=createPhase0HExtensionManifest(plan,projectFolder,"extension");
manifestFile=fullfile(outputFolder,"manifest.json");
if action=="start"
    if isfolder(outputFolder)&&~isempty(dir(fullfile(outputFolder,"*")))
        error("preparePhase0HExtensionRun:OutputNotEmpty", ...
            "Extension start requires a new or empty folder: %s",outputFolder);
    end
    if ~isfolder(outputFolder),mkdir(outputFolder);end
    xpsh.writeJsonAtomic(manifestFile,current);
    writetable(extensionInventory(plan),fullfile(outputFolder,"cell_inventory.csv"));
    writetable(phase0HExtensionSeedSchedule(plan), ...
        fullfile(outputFolder,"seed_schedule.csv"));
    manifest=current;return
end
if ~isfile(manifestFile)
    error("preparePhase0HExtensionRun:MissingManifest", ...
        "Cannot resume because %s does not exist.",manifestFile);
end
manifest=jsondecode(fileread(manifestFile));
if string(manifest.run_mode)~="extension" || ...
        string(manifest.run_fingerprint)~=string(current.run_fingerprint) || ...
        string(manifest.extension_execution_fingerprint)~= ...
            string(current.extension_execution_fingerprint) || ...
        manifest.cell_count~=42 || manifest.extension_trial_count~=12600
    error("preparePhase0HExtensionRun:FingerprintMismatch", ...
        "Stored extension manifest differs from current approved execution code.");
end
end

function T=extensionInventory(plan)
n=numel(plan.cells);FamilyID=zeros(n,1);FamilyName=strings(n,1);
CellIndex=zeros(n,1);CellKey=strings(n,1);Gate=strings(n,1);
FirstTrialID=zeros(n,1);LastTrialID=zeros(n,1);NewTrials=zeros(n,1);
FinalN=zeros(n,1);OptimizerInvocationsPerTrial=zeros(n,1);
ExpectedOptimizerInvocations=zeros(n,1);
for i=1:n
    c=plan.cells(i);FamilyID(i)=c.family_id;FamilyName(i)=string(c.family_name);
    CellIndex(i)=c.cell_index;CellKey(i)=string(c.cell_key);Gate(i)=string(c.gate);
    FirstTrialID(i)=c.extension_first_trial;LastTrialID(i)=c.extension_last_trial;
    NewTrials(i)=c.extension_trials;FinalN(i)=c.final_trial_count;
    OptimizerInvocationsPerTrial(i)=c.optimizer_invocations_per_trial;
    ExpectedOptimizerInvocations(i)=c.extension_optimizer_invocations;
end
T=table(FamilyID,FamilyName,CellIndex,CellKey,Gate,FirstTrialID, ...
    LastTrialID,NewTrials,FinalN,OptimizerInvocationsPerTrial, ...
    ExpectedOptimizerInvocations);
end
