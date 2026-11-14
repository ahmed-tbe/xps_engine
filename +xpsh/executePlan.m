function report = executePlan(plan,outputFolder,projectFolder,manifest,options)
%EXECUTEPLAN Execute/resume cells with no graphics and atomic checkpoints.

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
if ~isscalar(options.MaxNewTrials) || options.MaxNewTrials<0
    error("xpsh:executePlan:InvalidTrialLimit","MaxNewTrials must be nonnegative.");
end
if ~isfield(options.Plotting,"enabled") || options.Plotting.enabled
    error("xpsh:executePlan:PlottingMustBeDisabled", ...
        "Phase 0H optimizer execution requires plotting.enabled=false.");
end

checkpointRoot = fullfile(outputFolder,"checkpoints");
if ~isfolder(checkpointRoot),mkdir(checkpointRoot);end
logFile = fullfile(outputFolder,"run.log");
guard = xpsh.enterNonGraphicalMode; %#ok<NASGU>
runStarted = tic;
newTrials = 0; skippedTrials = 0; recordedErrors = 0;
completedCells = 0; stopRequested = false;

xpsh.appendLog(logFile,compose( ...
    "run-mode=%s start/resume fingerprint=%s checkpoint-root=%s", ...
    string(manifest.run_mode),string(manifest.run_fingerprint),checkpointRoot));

for c = 1:numel(plan.cells)
    cellDefinition = plan.cells(c);
    completed = xpsh.completedTrials(checkpointRoot, ...
        string(manifest.run_fingerprint),string(cellDefinition.cell_key));
    xpsh.verifyCheckpointSeeds(checkpointRoot,string(manifest.run_fingerprint), ...
        cellDefinition,completed);
    skippedTrials = skippedTrials+numel(completed);
    missing = setdiff((1:cellDefinition.trials).',completed,"stable");

    for trialID = missing.'
        if newTrials >= options.MaxNewTrials
            stopRequested = true;
            break
        end
        trialStarted = tic;
        seeds = xpsh.trialSeeds(cellDefinition,trialID);
        existingFigures = findall(groot,"Type","figure");
        try
            fixture = xpsh.generateFixture(cellDefinition,trialID,projectFolder);
            validation = xpsh.validateFixture(fixture);
            if ~validation.valid
                error("xpsh:executePlan:InvalidFixture","%s", ...
                    strjoin(validation.errors," | "));
            end
            payload = options.TrialExecutor(fixture,projectFolder);
            xpsh.assertNoNewFigures(existingFigures);
            if ~isfield(payload,"status"),payload.status="success";end
        catch exception
            createdFigureCount=closeNewFigures(existingFigures);
            if createdFigureCount>0
                plotException=MException( ...
                    "xpsh:executePlan:ForbiddenFigureCreated", ...
                    "Trial created %d forbidden figure(s).",createdFigureCount);
                plotException=addCause(plotException,exception);
                exception=plotException;
            end
            payload = errorPayload(cellDefinition,trialID,seeds,exception,toc(trialStarted));
            recordedErrors = recordedErrors+1;
        end
        payload.seeds = seeds;
        payload.cell_key = string(cellDefinition.cell_key);
        payload.trial_id = trialID;
        payload.plotting_enabled = false;
        payload.checkpoint_written_at = string(datetime("now", ...
            "TimeZone","America/Chicago","Format","yyyy-MM-dd'T'HH:mm:ssXXX"));
        if ~isfield(payload,"elapsed_seconds") || ~isfinite(payload.elapsed_seconds)
            payload.elapsed_seconds = toc(trialStarted);
        end
        checkpointFile = fullfile(checkpointRoot,cellDefinition.cell_key, ...
            compose("trial_%04d.mat",trialID));
        xpsh.writeCheckpoint(checkpointRoot,string(manifest.run_fingerprint), ...
            string(cellDefinition.cell_key),trialID,payload);
        newTrials = newTrials+1;
        xpsh.appendLog(logFile,compose([ ...
            "family=%d/%s cell=%s (%d/%d) trial=%d/%d status=%s " + ...
            "elapsed=%.3fs run-elapsed=%.3fs checkpoint=%s"], ...
            cellDefinition.family_id,string(cellDefinition.family_name), ...
            string(cellDefinition.cell_key),c,numel(plan.cells),trialID, ...
            cellDefinition.trials,string(payload.status),payload.elapsed_seconds, ...
            toc(runStarted),checkpointFile));
    end

    nowCompleted = xpsh.completedTrials(checkpointRoot, ...
        string(manifest.run_fingerprint),string(cellDefinition.cell_key));
    if numel(nowCompleted)==cellDefinition.trials
        summaryWritten = xpsh.writeCellCheckpoint(checkpointRoot, ...
            string(manifest.run_fingerprint),cellDefinition);
        completedCells = completedCells+1;
        cellCheckpoint = fullfile(checkpointRoot,cellDefinition.cell_key, ...
            "cell_complete.mat");
        xpsh.appendLog(logFile,compose( ...
            "family=%d/%s cell=%s complete=%d/%d cell-checkpoint=%s new=%d", ...
            cellDefinition.family_id,string(cellDefinition.family_name), ...
            string(cellDefinition.cell_key),numel(nowCompleted), ...
            cellDefinition.trials,cellCheckpoint,summaryWritten));
    end
    if stopRequested,break;end
end

xpsh.assertNoNewFigures(guard.existing_figures);
report = struct("status",conditionalStatus(stopRequested), ...
    "new_trials_executed",newTrials,"previous_trials_skipped",skippedTrials, ...
    "recorded_trial_errors",recordedErrors,"completed_cells_seen",completedCells, ...
    "elapsed_seconds",toc(runStarted),"checkpoint_root",checkpointRoot, ...
    "log_file",logFile,"plotting_enabled",false, ...
    "run_fingerprint",string(manifest.run_fingerprint));
end

function payload = errorPayload(cellDefinition,trialID,seeds,exception,elapsed)
payload=struct("schema_id","phase0h_trial_checkpoint", ...
    "schema_version","1.0.0","status","error", ...
    "cell_key",string(cellDefinition.cell_key),"trial_id",trialID, ...
    "seeds",seeds,"settings",cellDefinition.settings, ...
    "trial_converged",false,"optimizer_invocations",0, ...
    "elapsed_seconds",elapsed,"plotting_enabled",false, ...
    "error",struct("identifier",string(exception.identifier), ...
    "message",string(exception.message), ...
    "report",string(getReport(exception,"extended","hyperlinks","off"))));
end

function count=closeNewFigures(existing)
current=findall(groot,"Type","figure");
new=current(~ismember(current,existing));
count=numel(new);
if ~isempty(new),close(new);end
end

function value = conditionalStatus(stopped)
if stopped,value="paused_at_max_new_trials";else,value="execution_pass_complete";end
end
