function report = executePhase0HExtensionPlan(plan,outputFolder,projectFolder,manifest,options)
%EXECUTEPHASE0HEXTENSIONPLAN Execute/resume trial IDs 101:400 only.
arguments
    plan (1,1) struct
    outputFolder (1,1) string
    projectFolder (1,1) string
    manifest (1,1) struct
    options (1,1) struct = struct()
end
if ~isfield(options,"MaxNewTrials"),options.MaxNewTrials=Inf;end
if ~isfield(options,"TrialExecutor"),options.TrialExecutor=@xpsh.executeTrial;end
if ~isfield(options,"Plotting"),options.Plotting=struct("enabled",false);end
if options.Plotting.enabled
    error("executePhase0HExtensionPlan:PlottingMustBeDisabled", ...
        "Extension optimizer execution requires plotting.enabled=false.");
end
root=fullfile(outputFolder,"checkpoints");if ~isfolder(root),mkdir(root);end
logFile=fullfile(outputFolder,"run.log");guard=xpsh.enterNonGraphicalMode; %#ok<NASGU>
started=tic;newTrials=0;skipped=0;errors=0;completedCells=0;stop=false;
xpsh.appendLog(logFile,compose("run-mode=%s fingerprint=%s trial-range=101:400 checkpoint-root=%s", ...
    string(manifest.run_mode),string(manifest.run_fingerprint),root));
for i=1:numel(plan.cells)
    c=plan.cells(i);completed=xpsh.completedTrials(root,string(manifest.run_fingerprint),string(c.cell_key));
    if any(completed<101|completed>400)
        error("executePhase0HExtensionPlan:UnexpectedTrialID", ...
            "Extension folder contains a trial outside 101:400.");
    end
    xpsh.verifyCheckpointSeeds(root,string(manifest.run_fingerprint),c,completed);
    skipped=skipped+numel(completed);
    missing=setdiff((c.extension_first_trial:c.extension_last_trial).',completed,"stable");
    for trialID=missing.'
        if newTrials>=options.MaxNewTrials,stop=true;break;end
        one=tic;seeds=xpsh.trialSeeds(c,trialID);figures=findall(groot,"Type","figure");
        try
            fixture=xpsh.generateFixture(c,trialID,projectFolder);
            validation=xpsh.validateFixture(fixture);
            if ~validation.valid
                error("executePhase0HExtensionPlan:InvalidFixture","%s",strjoin(validation.errors," | "));
            end
            payload=options.TrialExecutor(fixture,projectFolder);
            xpsh.assertNoNewFigures(figures);
            if ~isfield(payload,"status"),payload.status="success";end
        catch exception
            closeNewFigures(figures);payload=errorPayload(c,trialID,seeds,exception,toc(one));errors=errors+1;
        end
        payload.seeds=seeds;payload.cell_key=string(c.cell_key);payload.trial_id=trialID;
        payload.plotting_enabled=false;payload.seed_namespace=string(plan.seed_namespace);
        payload.checkpoint_written_at=string(datetime("now","TimeZone","America/Chicago", ...
            "Format","yyyy-MM-dd'T'HH:mm:ssXXX"));
        if ~isfield(payload,"elapsed_seconds")||~isfinite(payload.elapsed_seconds),payload.elapsed_seconds=toc(one);end
        file=fullfile(root,c.cell_key,compose("trial_%04d.mat",trialID));
        xpsh.writeCheckpoint(root,string(manifest.run_fingerprint),string(c.cell_key),trialID,payload);
        newTrials=newTrials+1;
        xpsh.appendLog(logFile,compose(["family=%d/%s cell=%s (%d/%d) trial=%d/%d " + ...
            "extension-complete=%d/%d status=%s elapsed=%.3fs run-elapsed=%.3fs checkpoint=%s"], ...
            c.family_id,string(c.family_name),string(c.cell_key),i,numel(plan.cells),trialID, ...
            c.extension_last_trial,trialID-c.extension_first_trial+1, ...
            c.extension_trials,string(payload.status),payload.elapsed_seconds,toc(started),file));
    end
    now=xpsh.completedTrials(root,string(manifest.run_fingerprint),string(c.cell_key));
    if numel(now)==c.extension_trials
        written=writePhase0HExtensionCellCheckpoint(root,string(manifest.run_fingerprint),c);
        completedCells=completedCells+1;
        xpsh.appendLog(logFile,compose("cell=%s extension-complete=%d/%d final-N=%d new-cell-checkpoint=%d", ...
            string(c.cell_key),numel(now),c.extension_trials,c.final_trial_count,written));
    end
    if stop,break;end
end
xpsh.assertNoNewFigures(guard.existing_figures);
report=struct("status",conditional(stop),"new_trials_executed",newTrials, ...
    "previous_trials_skipped",skipped,"recorded_trial_errors",errors, ...
    "completed_cells_seen",completedCells,"elapsed_seconds",toc(started), ...
    "checkpoint_root",root,"log_file",logFile,"plotting_enabled",false, ...
    "run_fingerprint",string(manifest.run_fingerprint));
end
function payload=errorPayload(c,id,seeds,e,elapsed)
payload=struct("schema_id","phase0h_trial_checkpoint","schema_version","1.0.0", ...
    "status","error","cell_key",string(c.cell_key),"trial_id",id,"seeds",seeds, ...
    "settings",c.settings,"trial_converged",false,"optimizer_invocations",0, ...
    "elapsed_seconds",elapsed,"plotting_enabled",false, ...
    "error",struct("identifier",string(e.identifier),"message",string(e.message), ...
    "report",string(getReport(e,"extended","hyperlinks","off"))));
end
function closeNewFigures(existing)
current=findall(groot,"Type","figure");new=current(~ismember(current,existing));if ~isempty(new),close(new);end
end
function value=conditional(stop),if stop,value="paused_at_max_new_trials";else,value="extension_execution_pass_complete";end,end
