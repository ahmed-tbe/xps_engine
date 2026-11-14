function report = runPhase0HExtensionDryRun(outputFolder)
%RUNPHASE0HEXTENSIONDRYRUN Validate the 101:400 extension without fitting.
%
% Generates only boundary fixtures plus a two-record dummy checkpoint test.
% It never calls an optimizer and never writes to any accepted source run.

arguments
    outputFolder (1,1) string = ""
end
projectFolder=string(fileparts(mfilename("fullpath")));
if strlength(outputFolder)==0
    outputFolder=fullfile(projectFolder,"results", ...
        "phase0h_borderline_extension_v1_0_0_dry_run");
end
if folderHasEntries(outputFolder)
    error("runPhase0HExtensionDryRun:OutputNotEmpty", ...
        "Dry-run output must be new or empty: %s",outputFolder);
end
if ~isfolder(outputFolder),mkdir(outputFolder);end

parents=parentFolders(projectFolder);
before=snapshots(parents);
plan=buildPhase0HExtensionPlan(projectFolder);
manifest=createPhase0HExtensionManifest(plan,projectFolder,"extension_dry_run");

% Exact schedule determinism, uniqueness, and isolation from trials 1:100.
schedule=phase0HExtensionSeedSchedule(plan);
scheduleAgain=phase0HExtensionSeedSchedule(plan);
deterministic=isequaln(schedule,scheduleAgain);
baseSchedule=xpsh.seedSchedule(xpsh.buildPlan(projectFolder));
extensionSeeds=allSeedValues(schedule);
baseSeeds=allSeedValues(baseSchedule);
extensionSeedsUnique=numel(unique(extensionSeeds))==numel(extensionSeeds);
noSeedOverlap=isempty(intersect(extensionSeeds,baseSeeds));
rowKeys=schedule.CellKey+":"+string(schedule.TrialID);
uniqueTrialKeys=numel(unique(rowKeys))==height(schedule);

% Generate and validate trial 101 and 400 of every selected cell.
guard=xpsh.enterNonGraphicalMode; %#ok<NASGU>
n=2*numel(plan.cells); FamilyID=zeros(n,1); CellKey=strings(n,1);
TrialID=zeros(n,1); FixtureValid=false(n,1); SeedRecordMatches=false(n,1);
C1sTruthPeakCount=zeros(n,1); F1sTruthPeakCount=zeros(n,1);
C1sFitPeakCount=zeros(n,1); F1sFitPeakCount=zeros(n,1);
C1sAcquisitionFactor=zeros(n,1); F1sAcquisitionFactor=zeros(n,1);
C1sBackgroundMethod=strings(n,1); F1sBackgroundMethod=strings(n,1);
ChargingShift_eV=zeros(n,1); ValidationErrors=strings(n,1); cursor=0;
for i=1:numel(plan.cells)
    c=plan.cells(i);
    for trialID=[c.extension_first_trial c.extension_last_trial]
        cursor=cursor+1; fixture=xpsh.generateFixture(c,trialID,projectFolder);
        validation=xpsh.validateFixture(fixture);
        FamilyID(cursor)=c.family_id; CellKey(cursor)=string(c.cell_key);
        TrialID(cursor)=trialID; FixtureValid(cursor)=validation.valid;
        ValidationErrors(cursor)=strjoin(validation.errors," | ");
        SeedRecordMatches(cursor)=isequaln(fixture.seeds,xpsh.trialSeeds(c,trialID));
        C1sTruthPeakCount(cursor)=numel(fixture.C1s.truth_peaks);
        F1sTruthPeakCount(cursor)=numel(fixture.F1s.truth_peaks);
        C1sFitPeakCount(cursor)=numel(fixture.fit_variants(1).C1s_peaks);
        F1sFitPeakCount(cursor)=numel(fixture.fit_variants(1).F1s_peaks);
        C1sAcquisitionFactor(cursor)=fixture.C1s.generation_acquisition_scale;
        F1sAcquisitionFactor(cursor)=fixture.F1s.generation_acquisition_scale;
        C1sBackgroundMethod(cursor)=string(fixture.C1s.background_truth_metadata.method);
        F1sBackgroundMethod(cursor)=string(fixture.F1s.background_truth_metadata.method);
        ChargingShift_eV(cursor)=fixture.charging_shift_eV;
    end
end
boundaryFixtures=table(FamilyID,CellKey,TrialID,FixtureValid, ...
    SeedRecordMatches,C1sTruthPeakCount,F1sTruthPeakCount,C1sFitPeakCount, ...
    F1sFitPeakCount,C1sAcquisitionFactor,F1sAcquisitionFactor, ...
    C1sBackgroundMethod,F1sBackgroundMethod,ChargingShift_eV,ValidationErrors);
xpsh.assertNoNewFigures(guard.existing_figures);

% Tiny dummy execution proves atomic checkpoint/resume/skip semantics while
% explicitly avoiding the optimizer and formal extension statistics.
mockPlan=plan; mockPlan.cells=plan.cells(1); mockPlan.cell_count=1;
mockPlan.cells.extension_first_trial=101;
mockPlan.cells.extension_last_trial=102;
mockPlan.cells.extension_trials=2;
mockPlan.cells.final_trial_count=102;
mockPlan.new_trial_count=2;
mockPlan.expected_optimizer_invocations=0;
mockFolder=fullfile(outputFolder,"checkpoint_resume_mock");
mockManifest=manifest;
mockManifest.run_mode="extension_smoke";
mockManifest.run_fingerprint=manifest.run_fingerprint+":dry-run-dummy";
mockOptions=struct("MaxNewTrials",1,"TrialExecutor",@dummyExecutor, ...
    "Plotting",struct("enabled",false));
first=executePhase0HExtensionPlan(mockPlan,mockFolder,projectFolder, ...
    mockManifest,mockOptions);
second=executePhase0HExtensionPlan(mockPlan,mockFolder,projectFolder, ...
    mockManifest,struct("MaxNewTrials",Inf,"TrialExecutor",@dummyExecutor, ...
    "Plotting",struct("enabled",false)));
third=executePhase0HExtensionPlan(mockPlan,mockFolder,projectFolder, ...
    mockManifest,struct("MaxNewTrials",Inf,"TrialExecutor",@dummyExecutor, ...
    "Plotting",struct("enabled",false)));
ids=xpsh.completedTrials(fullfile(mockFolder,"checkpoints"), ...
    string(mockManifest.run_fingerprint),string(mockPlan.cells.cell_key));
resumeVerified=first.new_trials_executed==1 && ...
    second.new_trials_executed==1 && second.previous_trials_skipped==1 && ...
    third.new_trials_executed==0 && third.previous_trials_skipped==2 && ...
    isequal(ids,[101;102]) && isfile(fullfile(mockFolder,"checkpoints", ...
    mockPlan.cells.cell_key,"cell_complete.mat"));

after=snapshots(parents);
parentsUnchanged=isequaln(before,after);
checks=struct( ...
    "selected_cells_exactly_42",plan.cell_count==42, ...
    "new_trials_exactly_12600",plan.new_trial_count==12600, ...
    "optimizer_invocations_exactly_40200",plan.expected_optimizer_invocations==40200, ...
    "seed_rows_exactly_12600",height(schedule)==12600, ...
    "trial_ids_exactly_101_to_400",all(schedule.TrialID>=101 & schedule.TrialID<=400), ...
    "seed_schedule_deterministic",deterministic, ...
    "seed_values_unique",extensionSeedsUnique, ...
    "trial_seed_keys_unique",uniqueTrialKeys, ...
    "no_seed_overlap_with_initial_100",noSeedOverlap, ...
    "boundary_fixtures_exactly_84",height(boundaryFixtures)==84, ...
    "all_boundary_fixtures_valid",all(boundaryFixtures.FixtureValid), ...
    "all_boundary_seed_records_match",all(boundaryFixtures.SeedRecordMatches), ...
    "plotting_disabled",numel(findall(groot,"Type","figure"))== ...
        numel(guard.existing_figures), ...
    "checkpoint_resume_and_skip_verified",resumeVerified, ...
    "parents_immutable",parentsUnchanged, ...
    "provenance_links_frozen_plan",string(manifest.plan_sha256)== ...
        "1f932b278de41dc14154191833f45b5fcf55f3b5a01edd7a661ddcbcf2f556bf", ...
    "provenance_links_accepted_unified", ...
        strlength(string(manifest.parent_results.accepted_unified_summary_sha256))==64);
passed=all(cell2mat(struct2cell(checks)));
if ~passed
    error("runPhase0HExtensionDryRun:ValidationFailed", ...
        "One or more extension dry-run checks failed.");
end

manifest.dry_run_completed=true;
manifest.dry_run_checks=checks;
xpsh.writeJsonAtomic(fullfile(outputFolder,"manifest.json"),manifest);
writetable(extensionInventoryForReport(plan),fullfile(outputFolder,"cell_inventory.csv"));
writetable(schedule,fullfile(outputFolder,"seed_schedule.csv"));
writetable(boundaryFixtures,fullfile(outputFolder,"boundary_fixture_validation.csv"));
checkpointResume=struct("first",first,"second",second,"third",third, ...
    "completed_trial_ids",ids,"verified",resumeVerified);
xpsh.writeJsonAtomic(fullfile(outputFolder,"checkpoint_resume_validation.json"), ...
    checkpointResume);
report=struct("report_id","phase0h_borderline_extension_dry_run_v1_0_0", ...
    "status","passed_no_extension_trials_executed","passed",passed, ...
    "plan",plan,"manifest",manifest,"checks",checks, ...
    "boundaryFixtures",boundaryFixtures,"checkpointResume",checkpointResume, ...
    "parent_integrity",{after},"output_folder",outputFolder);
save(fullfile(outputFolder,"extension_dry_run_report.mat"),"report","-v7.3");
fprintf(["Phase 0H extension dry run PASSED: 42 cells, 12,600 new trials, " + ...
    "40,200 future optimizer invocations. No extension optimizer trial executed.\n"]);
fprintf("Artifacts: %s\n",outputFolder);
end

function payload=dummyExecutor(fixture,~)
payload=struct("schema_id","phase0h_extension_dummy_checkpoint", ...
    "schema_version","1.0.0","status","success", ...
    "trial_converged",true,"optimizer_invocations",0, ...
    "elapsed_seconds",0,"plotting_enabled",false, ...
    "fixture_trial_id",fixture.trial_id);
end

function values=allSeedValues(T)
names=string(T.Properties.VariableNames);
names=names(startsWith(names,"Seed_"));
values=reshape(table2array(T(:,cellstr(names))),[],1);
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

function T=extensionInventoryForReport(plan)
n=numel(plan.cells); FamilyID=zeros(n,1); FamilyName=strings(n,1);
CellKey=strings(n,1); Gate=strings(n,1); FirstTrialID=zeros(n,1);
LastTrialID=zeros(n,1); NewTrials=zeros(n,1); FinalN=zeros(n,1);
Starts=zeros(n,1); PipelinesPerTrial=zeros(n,1);
OptimizerInvocationsPerTrial=zeros(n,1); ExpectedOptimizerInvocations=zeros(n,1);
for i=1:n
    c=plan.cells(i); FamilyID(i)=c.family_id; FamilyName(i)=string(c.family_name);
    CellKey(i)=string(c.cell_key); Gate(i)=string(c.gate);
    FirstTrialID(i)=c.extension_first_trial; LastTrialID(i)=c.extension_last_trial;
    NewTrials(i)=c.extension_trials; FinalN(i)=c.final_trial_count;
    Starts(i)=c.starts; PipelinesPerTrial(i)=c.pipelines_per_trial;
    OptimizerInvocationsPerTrial(i)=c.optimizer_invocations_per_trial;
    ExpectedOptimizerInvocations(i)=c.extension_optimizer_invocations;
end
T=table(FamilyID,FamilyName,CellKey,Gate,FirstTrialID,LastTrialID, ...
    NewTrials,FinalN,Starts,PipelinesPerTrial,OptimizerInvocationsPerTrial, ...
    ExpectedOptimizerInvocations);
end

function tf=folderHasEntries(folder)
if ~isfolder(folder),tf=false;return;end
items=dir(folder);names=string({items.name});
tf=any(names~="." & names~="..");
end
