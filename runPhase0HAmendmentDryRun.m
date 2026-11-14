function report = runPhase0HAmendmentDryRun(outputFolder)
%RUNPHASE0HAMENDMENTDRYRUN Validate the isolated amendment before execution.
%
% No amended Monte Carlo checkpoints are created. F10_G2 fixtures are
% validated for all 100 original trials. One composition-only execution per
% Family 12 cell validates the corrected adapter with zero optimizer calls.

arguments
    outputFolder (1,1) string = ""
end
projectFolder=string(fileparts(mfilename("fullpath")));
if strlength(outputFolder)==0
    outputFolder=fullfile(projectFolder,"results", ...
        "phase0h_execution_amendment_v1_0_1_dry_run");
end
formalFolder=fullfile(projectFolder,"results","phase0h_formal_v1_0_0");
assertSeparateOutput(outputFolder,formalFolder);
if isfolder(outputFolder) && ~isempty(dir(fullfile(outputFolder,"*")))
    error("runPhase0HAmendmentDryRun:OutputNotEmpty", ...
        "Dry-run output must be new or empty: %s",outputFolder);
end
integrityBefore=xpsh.formalRunIntegritySnapshot(formalFolder);
plan=xpsh.buildAmendmentPlan(projectFolder);
manifest=xpsh.createAmendmentManifest(plan,projectFolder, ...
    "amendment_dry_run");

% Exact frozen-seed reuse across every one of the 1,100 amended trials.
seedSchedule=xpsh.seedSchedule(plan);
originalSeeds=readtable(fullfile(formalFolder,"seed_schedule.csv"), ...
    TextType="string",VariableNamingRule="preserve");
originalSubset=originalSeeds(ismember(originalSeeds.CellKey, ...
    string({plan.cells.cell_key})),:);
seedScheduleMatchesOriginal=tablesEqual(seedSchedule,originalSubset);
if ~seedScheduleMatchesOriginal
    error("runPhase0HAmendmentDryRun:SeedMismatch", ...
        "Amendment seed schedule differs from frozen v1.0.0 seeds.");
end

% Validate all 100 formerly vulnerable charging fixtures.
charging=plan.cells(string({plan.cells.cell_key})=="F10_G2");
chargingValid=false(charging.trials,1);
chargingErrors=strings(charging.trials,1);
disjointFallback=false(charging.trials,1);
for trialID=1:charging.trials
    fixture=xpsh.generateFixture(charging,trialID,projectFolder);
    validation=xpsh.validateFixture(fixture);
    chargingValid(trialID)=validation.valid;
    chargingErrors(trialID)=strjoin(validation.errors," | ");
    disjointFallback(trialID)=hasDisjointPrimaryInterval(fixture);
end
if ~all(chargingValid)
    error("runPhase0HAmendmentDryRun:ChargingFixtureInvalid", ...
        "%d F10_G2 fixtures remain invalid.",nnz(~chargingValid));
end

% Validate one fixture and corrected zero-optimizer execution per F12 cell.
family12=plan.cells([plan.cells.family_id]==12);
family12Key=string({family12.cell_key}).';
family12FixtureValid=false(numel(family12),1);
family12AdapterValid=false(numel(family12),1);
family12Status=strings(numel(family12),1);
family12OptimizerCalls=zeros(numel(family12),1);
family12Fixtures=cell(numel(family12),1);
guard=xpsh.enterNonGraphicalMode;
for i=1:numel(family12)
    fixture=xpsh.generateFixture(family12(i),1,projectFolder);
    family12Fixtures{i}=fixture;
    validation=xpsh.validateFixture(fixture);
    family12FixtureValid(i)=validation.valid;
    cPeaks=xpsh.truthAsFittedPeaks(fixture.C1s.truth_peaks);
    fPeaks=xpsh.truthAsFittedPeaks(fixture.F1s.truth_peaks);
    family12AdapterValid(i)=all(string({cPeaks.assignment})== ...
        string({fixture.C1s.truth_peaks.label})) && ...
        all(string({fPeaks.assignment})==string({fixture.F1s.truth_peaks.label}));
    payload=xpsh.executeTrial(fixture,projectFolder);
    family12Status(i)=string(payload.status);
    family12OptimizerCalls(i)=payload.optimizer_invocations;
end
xpsh.assertNoNewFigures(guard.existing_figures);
if ~all(family12FixtureValid & family12AdapterValid & ...
        family12Status=="success" & family12OptimizerCalls==0)
    error("runPhase0HAmendmentDryRun:Family12ValidationFailed", ...
        "At least one Family 12 dry-run adapter execution failed.");
end

% Prove fixture and fitted-result equivalence for unaffected representatives.
narrowness=validateUnaffectedPaths(projectFolder,formalFolder);
if ~all(narrowness.FixtureIdentical) || ...
        ~all(narrowness.ResultIdentical | narrowness.AdapterOnly)
    error("runPhase0HAmendmentDryRun:UnaffectedPathChanged", ...
        "An unaffected representative differs from v1.0.0.");
end

integrityAfter=xpsh.formalRunIntegritySnapshot(formalFolder);
formalUnchanged=isequaln(integrityBefore,integrityAfter);
if ~formalUnchanged
    error("runPhase0HAmendmentDryRun:OriginalFormalRunChanged", ...
        "Immutable v1.0.0 output changed during amendment validation.");
end

chargingValidation=table((1:charging.trials).',chargingValid, ...
    chargingErrors,disjointFallback,VariableNames=["TrialID","Valid", ...
    "Errors","UsedDisjointFallback"]);
family12Validation=table(family12Key,family12FixtureValid, ...
    family12AdapterValid,family12Status,family12OptimizerCalls, ...
    VariableNames=["CellKey","FixtureValid","AdapterValid", ...
    "ExecutionStatus","OptimizerInvocations"]);
checks=struct("affected_cell_count",plan.cell_count==11, ...
    "amended_trial_count",plan.initial_trial_count==1100, ...
    "expected_optimizer_invocations",plan.expected_optimizer_invocations==200, ...
    "all_original_seeds_reused",seedScheduleMatchesOriginal, ...
    "all_F10_G2_fixtures_valid",all(chargingValid), ...
    "all_F12_adapters_valid",all(family12AdapterValid), ...
    "all_F12_optimizer_calls_zero",all(family12OptimizerCalls==0), ...
    "unaffected_fixtures_identical",all(narrowness.FixtureIdentical), ...
    "unaffected_results_identical", ...
        all(narrowness.ResultIdentical | narrowness.AdapterOnly), ...
    "no_plotting",numel(findall(groot,"Type","figure"))== ...
        numel(guard.existing_figures), ...
    "original_formal_run_unchanged",formalUnchanged);
passed=all(cell2mat(struct2cell(checks)));
if ~passed
    error("runPhase0HAmendmentDryRun:ValidationFailed", ...
        "One or more dry-run checks failed.");
end

if ~isfolder(outputFolder),mkdir(outputFolder);end
manifest.dry_run_completed=true;
manifest.dry_run_checks=checks;
xpsh.writeJsonAtomic(fullfile(outputFolder,"manifest.json"),manifest);
writetable(xpsh.inventoryTable(plan),fullfile(outputFolder,"cell_inventory.csv"));
writetable(seedSchedule,fullfile(outputFolder,"seed_schedule.csv"));
writetable(chargingValidation,fullfile(outputFolder,"F10_G2_fixture_validation.csv"));
writetable(family12Validation,fullfile(outputFolder,"F12_adapter_validation.csv"));
writetable(narrowness,fullfile(outputFolder,"unaffected_path_regression.csv"));
report=struct("report_id","phase0h_execution_amendment_dry_run_v1_0_1", ...
    "passed",passed,"status","passed_no_amendment_monte_carlo", ...
    "manifest",manifest,"plan",plan,"checks",checks, ...
    "chargingValidation",chargingValidation, ...
    "family12Validation",family12Validation,"narrowness",narrowness, ...
    "seedSchedule",seedSchedule,"original_formal_integrity",integrityAfter, ...
    "output_folder",outputFolder);
save(fullfile(outputFolder,"amendment_dry_run_report.mat"),"report","-v7.3");
fprintf("Phase 0H amendment dry run PASSED: 11 cells, 1,100 original " + ...
    "seeds, 200 future optimizer calls. No amendment trials executed.\n");
fprintf("Disjoint-start fallback used in F10_G2 trial(s): %s\n", ...
    mat2str(find(disjointFallback).'));
fprintf("Artifacts: %s\n",outputFolder);
end

function tf=hasDisjointPrimaryInterval(fixture)
truth=fixture.C1s.truth_peaks;
fit=fixture.fit_variants(1).C1s_peaks;
t=find(string({truth.id})=="sp2_C_C",1);
f=find(string({fit.id})=="sp2_C_C",1);
lo=max(fit(f).center_bounds_eV(1),truth(t).center_eV-0.25);
hi=min(fit(f).center_bounds_eV(2),truth(t).center_eV+0.25);
tf=lo>hi;
end

function equal=tablesEqual(actual,expected)
equal=isequal(string(actual.Properties.VariableNames), ...
    string(expected.Properties.VariableNames)) && height(actual)==height(expected);
if ~equal,return;end
for name=string(actual.Properties.VariableNames)
    a=actual.(name);e=expected.(name);
    if isstring(a) || iscellstr(a) || iscategorical(a)
        equal=equal && isequal(string(a),string(e));
    else
        equal=equal && isequal(double(a),double(e));
    end
    if ~equal,return;end
end
end

function T=validateUnaffectedPaths(projectFolder,formalFolder)
representatives=["F01_N2";"F09_Q1";"F10_G1";"F12_R3"];
adapterOnly=[false;false;false;true];
base=xpsh.buildPlan(projectFolder);
oldDry=load(fullfile(projectFolder,"results","phase0h_dry_run_v1_0_0", ...
    "dry_run_fixtures.mat"),"fixtures");
FixtureIdentical=false(numel(representatives),1);
ResultIdentical=false(numel(representatives),1);
for i=1:numel(representatives)
    index=find(string({base.cells.cell_key})==representatives(i),1);
    current=xpsh.generateFixture(base.cells(index),1,projectFolder);
    FixtureIdentical(i)=isequaln(current,oldDry.fixtures{index});
    if adapterOnly(i),continue;end
    before=numel(findall(groot,"Type","figure"));
    currentPayload=xpsh.executeTrial(current,projectFolder);
    after=numel(findall(groot,"Type","figure"));
    if after~=before
        error("runPhase0HAmendmentDryRun:UnexpectedFigure", ...
            "Regression execution created a figure for %s.",representatives(i));
    end
    stored=load(fullfile(formalFolder,"checkpoints",representatives(i), ...
        "trial_0001.mat"),"payload");
    ResultIdentical(i)=isequaln(canonicalPayload(currentPayload), ...
        canonicalPayload(stored.payload));
end
T=table(representatives,FixtureIdentical,ResultIdentical,adapterOnly, ...
    VariableNames=["CellKey","FixtureIdentical","ResultIdentical","AdapterOnly"]);
end

function payload=canonicalPayload(payload)
for field=["elapsed_seconds","checkpoint_written_at"]
    if isfield(payload,field),payload=rmfield(payload,field);end
end
if ~isfield(payload,"variants"),return;end
for v=1:numel(payload.variants)
    for region=["C1s","F1s"]
        if ~isfield(payload.variants(v),region),continue;end
        fit=payload.variants(v).(region);
        if isfield(fit,"attempts") && isfield(fit.attempts,"runtime_seconds")
            fit.attempts=rmfield(fit.attempts,"runtime_seconds");
        end
        payload.variants(v).(region)=fit;
    end
end
end

function assertSeparateOutput(outputFolder,formalFolder)
formal=lower(string(char(java.io.File(formalFolder).getCanonicalPath())));
output=lower(string(char(java.io.File(outputFolder).getCanonicalPath())));
if output==formal || startsWith(output,formal+string(filesep))
    error("runPhase0HAmendmentDryRun:FormalOutputIsImmutable", ...
        "Dry-run output may not be inside the formal run folder.");
end
end
