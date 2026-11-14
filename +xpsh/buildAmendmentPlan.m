function plan = buildAmendmentPlan(projectFolder)
%BUILDAMENDMENTPLAN Select the 11 approved Phase 0H amendment cells.

arguments
    projectFolder (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
end
base=xpsh.buildPlan(projectFolder);
affectedKeys=["F10_G2";"F12_R1";"F12_R2";"F12_R3";"F12_R4"; ...
    "F12_R5";"F12_T1";"F12_T2";"F12_T3";"F12_T4";"F12_T5"];
allKeys=string({base.cells.cell_key}).';
[found,index]=ismember(affectedKeys,allKeys);
if ~all(found)
    error("xpsh:buildAmendmentPlan:MissingCell", ...
        "Frozen plan is missing amendment cell(s): %s.", ...
        strjoin(affectedKeys(~found),", "));
end
plan=base;
plan.original_plan_id=base.plan_id;
plan.original_plan_version=base.plan_version;
plan.original_plan_sha256=xpsh.sha256File(base.plan_document);
plan.amendment_id="phase0h_execution_amendment";
plan.amendment_version="1.0.1";
plan.cells=base.cells(index);
plan.cell_count=numel(plan.cells);
plan.trials_per_cell=100;
plan.initial_trial_count=sum([plan.cells.trials]);
plan.expected_optimizer_invocations=sum( ...
    [plan.cells.trials].*[plan.cells.optimizer_invocations_per_trial]);
plan.optimizer_count_definition= ...
    "Amendment: F10_G2 uses one C1s and one F1s optimizer call per trial; " + ...
    "all ten Family 12 composition-only cells use zero optimizer calls.";
plan.affected_cell_keys=affectedKeys;
plan.seed_policy= ...
    "Reuse frozen v1.0.0 family IDs, cell indices, trial IDs, stream IDs, " + ...
    "and seed formula exactly; do not create a new seed namespace.";
end
