function report = runPhase0HExecutionAmendment(action,outputFolder)
%RUNPHASE0HEXECUTIONAMENDMENT Execute/resume only the 11 amended cells.
%
% Do not call until the amendment dry run has been reviewed and approved.

arguments
    action (1,1) string {mustBeMember(action,["start","resume"])} = "start"
    outputFolder (1,1) string = ""
end
projectFolder=string(fileparts(mfilename("fullpath")));
if strlength(outputFolder)==0
    outputFolder=fullfile(projectFolder,"results", ...
        "phase0h_execution_amendment_v1_0_1");
end
formalFolder=fullfile(projectFolder,"results","phase0h_formal_v1_0_0");
integrityBefore=xpsh.formalRunIntegritySnapshot(formalFolder);
plan=xpsh.buildAmendmentPlan(projectFolder);
manifest=xpsh.prepareAmendmentRun(plan,outputFolder,projectFolder, ...
    "amendment",action);
options=struct("MaxNewTrials",Inf,"TrialExecutor",@xpsh.executeTrial, ...
    "Plotting",struct("enabled",false));
execution=xpsh.executePlan(plan,outputFolder,projectFolder,manifest,options);
status=xpsh.inspectRun(plan,outputFolder,manifest,string(manifest.run_fingerprint));
integrityAfter=xpsh.formalRunIntegritySnapshot(formalFolder);
if ~isequaln(integrityBefore,integrityAfter)
    error("runPhase0HExecutionAmendment:OriginalFormalRunChanged", ...
        "The immutable v1.0.0 integrity snapshot changed during execution.");
end
report=struct("execution",execution,"status",status,"manifest",manifest, ...
    "original_formal_integrity",integrityAfter);
fprintf("Amendment status: %s; %d/%d trials; %d/%d cells.\n", ...
    status.run_status,status.completed_trials,status.planned_trials, ...
    status.completed_cells,status.planned_cells);
end
