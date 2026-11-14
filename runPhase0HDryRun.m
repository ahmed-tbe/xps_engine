function report = runPhase0HDryRun(outputFolder)
%RUNPHASE0HDRYRUN Validate the Phase 0H harness without fitting any trial.

arguments
    outputFolder (1,1) string = ""
end
projectFolder = string(fileparts(mfilename("fullpath")));
if strlength(outputFolder)==0
    outputFolder = fullfile(projectFolder,"results","phase0h_dry_run_v1_0_0");
end
if ~isfolder(outputFolder),mkdir(outputFolder);end

plan = xpsh.buildPlan(projectFolder);
inventory = xpsh.inventoryTable(plan);
seedSchedule = xpsh.seedSchedule(plan);
manifest = xpsh.createManifest(plan,projectFolder);

% Load every frozen configuration/reference dependency before generation.
configurationValidation = validateConfigurationFiles(projectFolder,plan,manifest);

fixtures = cell(plan.cell_count,1);
fixtureValid = false(plan.cell_count,1);
fixtureErrors = strings(plan.cell_count,1);
cTruthCount = zeros(plan.cell_count,1);
fTruthCount = zeros(plan.cell_count,1);
variantCount = zeros(plan.cell_count,1);
for i = 1:plan.cell_count
    try
        fixtures{i} = xpsh.generateFixture(plan.cells(i),1,projectFolder);
        validation = xpsh.validateFixture(fixtures{i});
        fixtureValid(i) = validation.valid;
        fixtureErrors(i) = strjoin(validation.errors," | ");
        cTruthCount(i) = validation.C1s_truth_peak_count;
        fTruthCount(i) = validation.F1s_truth_peak_count;
        variantCount(i) = validation.fit_variant_count;
    catch exception
        fixtureErrors(i) = string(getReport(exception,"extended", ...
            "hyperlinks","off"));
    end
end
fixtureValidation = table(inventory.CellKey,fixtureValid,fixtureErrors, ...
    cTruthCount,fTruthCount,variantCount, ...
    VariableNames=["CellKey","Valid","Errors","C1sTruthPeakCount", ...
    "F1sTruthPeakCount","FitVariantCount"]);
if ~all(fixtureValid)
    bad = fixtureValidation(~fixtureValid,:);
    disp(bad);
    error("runPhase0HDryRun:FixtureValidationFailed", ...
        "%d of %d generated fixtures failed validation.", ...
        height(bad),height(fixtureValidation));
end

backgroundValidation = validateBackgroundGenerators;
statisticsValidation = validateStatisticsFunctions;
checkpointValidation = validateCheckpointResume(outputFolder, ...
    manifest.run_fingerprint,inventory.CellKey(1));
schema = xpsh.trialResultSchema;

assert(height(inventory)==92,"Dry-run inventory must contain 92 cells.");
assert(height(seedSchedule)==9200,"Seed schedule must contain 9,200 rows.");
assert(plan.expected_optimizer_invocations==26200, ...
    "Expected optimizer invocation count changed.");
assert(height(schema)==0 && width(schema)==24, ...
    "Trial-result schema must be a zero-row, 24-column table.");

manifest.configuration_validation_passed = configurationValidation.passed;
manifest.fixture_validation_passed = all(fixtureValid);
manifest.background_validation_passed = backgroundValidation.passed;
manifest.statistics_validation_passed = statisticsValidation.passed;
manifest.checkpoint_resume_validation_passed = checkpointValidation.passed;
manifest.dry_run_completed = true;

manifestFile = fullfile(outputFolder,"manifest.json");
writeText(manifestFile,jsonencode(manifest,PrettyPrint=true));
writetable(inventory,fullfile(outputFolder,"cell_inventory.csv"));
writetable(seedSchedule,fullfile(outputFolder,"seed_schedule.csv"));
writetable(fixtureValidation,fullfile(outputFolder,"fixture_validation.csv"));
save(fullfile(outputFolder,"dry_run_fixtures.mat"),"fixtures","-v7.3");

familyIDs = unique(inventory.FamilyID,"stable");
familyName = strings(numel(familyIDs),1);
cellCount = zeros(numel(familyIDs),1);
initialTrials = zeros(numel(familyIDs),1);
optimizerInvocations = zeros(numel(familyIDs),1);
for i = 1:numel(familyIDs)
    rows = inventory.FamilyID==familyIDs(i);
    familyName(i)=inventory.FamilyName(find(rows,1));
    cellCount(i)=nnz(rows);
    initialTrials(i)=sum(inventory.InitialTrials(rows));
    optimizerInvocations(i)=sum(inventory.InitialOptimizerInvocations(rows));
end
familySummary = table(familyIDs,familyName,cellCount,initialTrials, ...
    optimizerInvocations,VariableNames=["FamilyID","FamilyName", ...
    "CellCount","InitialTrials","ExpectedOptimizerInvocations"]);

report = struct("report_id","phase0h_harness_dry_run_v1", ...
    "passed",true, ...
    "status","passed_no_monte_carlo_no_fitting", ...
    "manifest",manifest,"inventory",inventory, ...
    "familySummary",familySummary,"seedSchedule",seedSchedule, ...
    "fixtureValidation",fixtureValidation, ...
    "configurationValidation",configurationValidation, ...
    "backgroundValidation",backgroundValidation, ...
    "statisticsValidation",statisticsValidation, ...
    "checkpointValidation",checkpointValidation, ...
    "trialResultSchema",schema,"outputFolder",outputFolder);
save(fullfile(outputFolder,"dry_run_report.mat"),"report","-v7.3");

fprintf("\nPhase 0H harness dry-run PASSED (no fitting performed)\n");
fprintf("Plan: %s v%s; SHA-256 %s\n",manifest.plan_id, ...
    manifest.plan_version,manifest.plan_sha256);
fprintf("Cells: %d; initial trials: %d; generated fixtures: %d\n", ...
    plan.cell_count,plan.initial_trial_count,numel(fixtures));
fprintf("Expected optimizer invocations for future initial run: %d\n", ...
    plan.expected_optimizer_invocations);
disp(familySummary);
fprintf("Artifacts: %s\n",outputFolder);
end

function result = validateConfigurationFiles(projectFolder,plan,manifest)
cfg = jsondecode(fileread(fullfile(projectFolder,"config","test", ...
    "ruoff_like_sample_A_synthetic_v1.json")));
model = xps.loadCompositionModelProfile(fullfile(projectFolder,"config", ...
    "composition","ruoff_primary_models_v1.json"));
ruoff = xps.loadSensitivityProfile(fullfile(projectFolder,"config", ...
    "sensitivity","ruoff_reproduction_sf3p95_v1.json"));
thermo = xps.loadSensitivityProfile(fullfile(projectFolder,"config", ...
    "sensitivity","thermo_k_alpha_sf4p118_v1.json"));
for sampleID = ["A","B","C"]
    xps.loadReference(fullfile(projectFolder,"reference", ...
        "sample_"+sampleID+"_ruoff_v1.json"));
end
range = model.models.c1s_f1s_semi.allowed_center_range_eV;
passed = string(cfg.usage)=="test_only_not_a_production_candidate" && ...
    isequal(double(range(:).'),[686.7 686.9]) && ...
    ruoff.S_F==3.95 && thermo.S_F==4.118 && ...
    plan.cell_count==92 && manifest.plan_sha256== ...
    xpsh.sha256File(plan.plan_document);
result = struct("passed",passed,"base_config_profile",string(cfg.profile_name), ...
    "composition_profile_id",string(model.profile_id), ...
    "semi_position_range_eV",double(range(:).'), ...
    "ruoff_profile_id",string(ruoff.profile_id), ...
    "thermo_profile_id",string(thermo.profile_id));
assert(passed,"runPhase0HDryRun:ConfigurationValidation", ...
    "Configuration validation failed.");
end

function result = validateBackgroundGenerators
x = linspace(0,10,101).'; zero=zeros(size(x)); constant=ones(size(x));
methods=["zero","linear","quadratic","shirley","tougaard"];
zeroPass=true;
for method=methods
    [b,meta]=xpsh.generateBackground(x,zero,method);
    zeroPass=zeroPass && isequal(b,zero) && ~meta.production_estimator_called;
end
[shirley,shirleyMeta]=xpsh.generateBackground(x,constant,"shirley");
expected=0.15*(1-(x-x(1))/(x(end)-x(1)));
shirleyPass=max(abs(shirley-expected))<1e-12;
[tougaard,tougaardMeta]=xpsh.generateBackground(x,constant,"tougaard");
tougaardPass=abs(tougaard(1))<1e-14 && all(tougaard>=-1e-14) && ...
    abs(max(tougaard)-0.15)<1e-12;
result=struct("passed",zeroPass&&shirleyPass&&tougaardPass, ...
    "zero_signal_all_methods",zeroPass,"shirley_constant_limit",shirleyPass, ...
    "tougaard_nonnegative_limit",tougaardPass, ...
    "shirley_generator_id",shirleyMeta.generator_id, ...
    "tougaard_generator_id",tougaardMeta.generator_id);
assert(result.passed,"runPhase0HDryRun:BackgroundValidation", ...
    "Independent background validation failed.");
end

function result = validateStatisticsFunctions
w=xpsh.wilsonInterval(95,100);
s=xpsh.summarizeValues((1:100).');
r=xpsh.residualAutocorrelation(zeros(10,1),ones(10,1));
passed=abs(w.observed_rate-0.95)<eps && w.lower<0.95 && w.upper>0.95 && ...
    s.p95==95 && s.p2_5==3 && s.p97_5==98 && ...
    r.ResidualVarianceEffectivelyZero && r.rho1==0;
result=struct("passed",passed,"wilson_95_of_100",w, ...
    "nearest_rank_1_to_100",s,"zero_variance_residual",r);
assert(passed,"runPhase0HDryRun:StatisticsValidation", ...
    "Statistics validation failed.");
end

function result = validateCheckpointResume(outputFolder,fingerprint,cellKey)
fingerprintDigest=xpsh.sha256Text(fingerprint);
suffix=extractBefore(fingerprintDigest,13);
folder=fullfile(outputFolder,"checkpoint_mock_"+suffix);
payload=struct("status","mock_complete");
first=xpsh.writeCheckpoint(folder,fingerprint,cellKey,1,payload);
xpsh.writeCheckpoint(folder,fingerprint,cellKey,3,payload);
duplicate=xpsh.writeCheckpoint(folder,fingerprint,cellKey,1,payload);
completed=xpsh.completedTrials(folder,fingerprint,cellKey);
mismatchRejected=false;
try
    xpsh.completedTrials(folder,fingerprint+"_wrong",cellKey);
catch exception
    mismatchRejected=exception.identifier=="xpsh:completedTrials:FingerprintMismatch";
end
passed=isequal(completed,[1;3]) && ~duplicate && mismatchRejected;
result=struct("passed",passed,"first_checkpoint_written",first, ...
    "duplicate_skipped",~duplicate,"completed_trials",completed, ...
    "fingerprint_mismatch_rejected",mismatchRejected,"folder",folder);
assert(passed,"runPhase0HDryRun:CheckpointValidation", ...
    "Checkpoint/resume validation failed.");
end

function writeText(filename,value)
fid=fopen(filename,"wt");
if fid<0,error("runPhase0HDryRun:WriteFailed","Cannot write %s",filename);end
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,"%s",value);
end
