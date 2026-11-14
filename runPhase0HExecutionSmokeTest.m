function report = runPhase0HExecutionSmokeTest(outputFolder)
%RUNPHASE0HEXECUTIONSMOKETEST Execute a tiny, non-formal optimizer smoke run.
%
% Smoke cells use family IDs 31/32, a separate output folder, and are never
% included in the frozen 9,200-trial schedule or its statistics.

arguments
    outputFolder (1,1) string = ""
end
projectFolder=string(fileparts(mfilename("fullpath")));
if strlength(outputFolder)==0
    stamp=string(datetime("now","Format","yyyyMMdd_HHmmss_SSS"));
    outputFolder=fullfile(string(tempdir),"phase0h_execution_smoke_"+stamp);
end
plan=smokePlan(xpsh.buildPlan(projectFolder));
if any([plan.cells.family_id] <= 16)
    error("runPhase0HExecutionSmokeTest:FormalSeedCollision", ...
        "Smoke cells must use seed family IDs outside the formal 1-16 block.");
end

figureCountBefore=numel(findall(groot,"Type","figure"));
manifest=xpsh.prepareRun(plan,outputFolder,projectFolder,"smoke","start");
options=struct("MaxNewTrials",2,"TrialExecutor",@xpsh.executeTrial, ...
    "Plotting",struct("enabled",false));
first=xpsh.executePlan(plan,outputFolder,projectFolder,manifest,options);

firstCellFolder=fullfile(outputFolder,"checkpoints",plan.cells(1).cell_key);
protectedFiles=[fullfile(firstCellFolder,"trial_0001.mat"); ...
    fullfile(firstCellFolder,"trial_0002.mat"); ...
    fullfile(firstCellFolder,"cell_complete.mat")];
hashBefore=strings(numel(protectedFiles),1);
for i=1:numel(protectedFiles),hashBefore(i)=xpsh.sha256File(protectedFiles(i));end

manifest=xpsh.prepareRun(plan,outputFolder,projectFolder,"smoke","resume");
options.MaxNewTrials=Inf;
second=xpsh.executePlan(plan,outputFolder,projectFolder,manifest,options);
hashAfter=strings(numel(protectedFiles),1);
for i=1:numel(protectedFiles),hashAfter(i)=xpsh.sha256File(protectedFiles(i));end

manifest=xpsh.prepareRun(plan,outputFolder,projectFolder,"smoke","resume");
third=xpsh.executePlan(plan,outputFolder,projectFolder,manifest,options);
status=xpsh.inspectRun(plan,outputFolder,manifest,string(manifest.run_fingerprint));
figureCountAfter=numel(findall(groot,"Type","figure"));

optimizerCalls=countOptimizerCalls(outputFolder,plan,manifest);
checks=struct("separate_smoke_output",~contains(outputFolder,"phase0h_formal"), ...
    "independent_seed_namespace",all([plan.cells.family_id]>16), ...
    "optimizer_invoked",optimizerCalls==plan.expected_optimizer_invocations, ...
    "checkpoint_resume_preserved_first_cell",isequal(hashBefore,hashAfter), ...
    "completed_trials_not_rerun",third.new_trials_executed==0, ...
    "all_smoke_cells_complete",status.run_status=="complete", ...
    "no_open_figure_increase",figureCountAfter==figureCountBefore, ...
    "plotting_disabled",~first.plotting_enabled && ~second.plotting_enabled);
passed=all(cell2mat(struct2cell(checks)));
report=struct("report_id","phase0h_execution_smoke_v1", ...
    "status",conditionalStatus(passed),"passed",passed, ...
    "formal_results",false,"include_in_formal_statistics",false, ...
    "output_folder",outputFolder,"plan",plan,"manifest",manifest, ...
    "first_pass",first,"resume_pass",second,"completed_resume_pass",third, ...
    "run_status",status,"optimizer_invocations",optimizerCalls, ...
    "figure_count_before",figureCountBefore,"figure_count_after",figureCountAfter, ...
    "checks",checks);
save(fullfile(outputFolder,"smoke_report.mat"),"report","-v7");
xpsh.writeJsonAtomic(fullfile(outputFolder,"smoke_report.json"), ...
    struct("report_id",report.report_id,"status",report.status, ...
    "formal_results",false,"include_in_formal_statistics",false, ...
    "optimizer_invocations",optimizerCalls,"checks",checks, ...
    "output_folder",outputFolder));
if ~passed
    error("runPhase0HExecutionSmokeTest:ValidationFailed", ...
        "One or more execution smoke checks failed.");
end
fprintf(["Phase 0H execution smoke PASSED: %d cells, %d trials, %d " + ...
    "optimizer calls, no figure increase. Output: %s\n"], ...
    plan.cell_count,plan.initial_trial_count,optimizerCalls,outputFolder);
end

function plan=smokePlan(base)
first=base.cells(2); % finite-noise nominal cell
second=base.cells(find([base.cells.family_id]==10,1)); % charging-shift cell
first.family_id=31; first.family_name="SmokeNominal"; first.cell_index=1;
first.cell_id="S1"; first.cell_key="SMOKE_S1"; first.trials=2;
first.starts=1; first.pipelines_per_trial=1; first.regions_per_pipeline=2;
first.optimizer_invocations_per_trial=2;
second.family_id=32; second.family_name="SmokeCharging"; second.cell_index=1;
second.cell_id="S2"; second.cell_key="SMOKE_S2"; second.trials=2;
second.starts=2; second.pipelines_per_trial=1; second.regions_per_pipeline=2;
second.optimizer_invocations_per_trial=4;
plan=base;
plan.plan_id="phase_0h_execution_smoke_test";
plan.cells=[first;second];
plan.cell_count=2; plan.trials_per_cell=2; plan.initial_trial_count=4;
plan.expected_optimizer_invocations=12;
plan.optimizer_count_definition= ...
    "Smoke-only: one 1-start and one 2-start C1s+F1s cell, two trials each.";
plan.seed_formula=base.seed_formula+"; smoke family IDs 31 and 32";
end

function count=countOptimizerCalls(outputFolder,plan,manifest)
count=0;
root=fullfile(outputFolder,"checkpoints");
for c=1:numel(plan.cells)
    ids=xpsh.completedTrials(root,string(manifest.run_fingerprint), ...
        string(plan.cells(c).cell_key));
    for id=ids.'
        value=load(fullfile(root,plan.cells(c).cell_key, ...
            compose("trial_%04d.mat",id)),"payload");
        count=count+value.payload.optimizer_invocations;
    end
end
end

function value=conditionalStatus(passed)
if passed,value="passed";else,value="failed";end
end
