function report = runPhase0HExtension(action,outputFolder)
%RUNPHASE0HEXTENSION Start/resume only the approved 42-cell 101:400 run.
%
% This is the formal execution entry point. It never writes to the original,
% amendment, or accepted unified result directories.

arguments
    action (1,1) string {mustBeMember(action,["start","resume"])} = "start"
    outputFolder (1,1) string = ""
end
projectFolder=string(fileparts(mfilename("fullpath")));
if strlength(outputFolder)==0
    outputFolder=fullfile(projectFolder,"results", ...
        "phase0h_borderline_extension_v1_0_0");
end
parents=parentFolders(projectFolder);
before=snapshots(parents);
plan=buildPhase0HExtensionPlan(projectFolder);
manifest=preparePhase0HExtensionRun(plan,outputFolder,projectFolder,action);
options=struct("MaxNewTrials",Inf,"TrialExecutor",@xpsh.executeTrial, ...
    "Plotting",struct("enabled",false));
execution=executePhase0HExtensionPlan(plan,outputFolder,projectFolder, ...
    manifest,options);
status=inspectPhase0HExtensionRun(plan,outputFolder,manifest, ...
    string(manifest.run_fingerprint));
after=snapshots(parents);
if ~isequaln(before,after)
    error("runPhase0HExtension:ParentResultsChanged", ...
        "An immutable original/amendment/unified result directory changed.");
end
report=struct("execution",execution,"status",status,"manifest",manifest, ...
    "parent_result_integrity",{after});
fprintf("Extension status: %s; %d/%d new trials; %d/%d cells.\n", ...
    status.run_status,status.completed_new_trials,status.planned_new_trials, ...
    status.completed_cells,status.planned_cells);
end

function folders=parentFolders(projectFolder)
folders=[fullfile(projectFolder,"results","phase0h_formal_v1_0_0"); ...
    fullfile(projectFolder,"results","phase0h_execution_amendment_v1_0_1"); ...
    fullfile(projectFolder,"results","phase0h_unified_v1_0_1")];
end

function value=snapshots(folders)
value=cell(numel(folders),1);
for i=1:numel(folders),value{i}=phase0HResultIntegritySnapshot(folders(i));end
end
