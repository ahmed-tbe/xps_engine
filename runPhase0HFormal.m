function report = runPhase0HFormal(action,outputFolder)
%RUNPHASE0HFORMAL Start or resume the frozen 9,200-trial Phase 0H run.
%
% This execution path is strictly non-graphical. It never generates final
% summaries; use generatePhase0HSummaries only after every cell completes.

arguments
    action (1,1) string {mustBeMember(action,["start","resume"])} = "start"
    outputFolder (1,1) string = ""
end
projectFolder=string(fileparts(mfilename("fullpath")));
if strlength(outputFolder)==0
    outputFolder=fullfile(projectFolder,"results","phase0h_formal_v1_0_0");
end
plan=xpsh.buildPlan(projectFolder);
manifest=xpsh.prepareRun(plan,outputFolder,projectFolder,"formal",action);
options=struct("MaxNewTrials",Inf,"TrialExecutor",@xpsh.executeTrial, ...
    "Plotting",struct("enabled",false));
execution=xpsh.executePlan(plan,outputFolder,projectFolder,manifest,options);
status=xpsh.inspectRun(plan,outputFolder,manifest,string(manifest.run_fingerprint));
report=struct("execution",execution,"status",status,"manifest",manifest);
fprintf("Formal Phase 0H status: %s; %d/%d trials; %d/%d cells.\n", ...
    status.run_status,status.completed_trials,status.planned_trials, ...
    status.completed_cells,status.planned_cells);
end
