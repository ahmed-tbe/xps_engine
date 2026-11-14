function tests = testPhase0HHarness
%TESTPHASE0HHARNESS Dry-run and non-graphical execution tests for Phase 0H.

tests = functiontests(localfunctions);
end

function testInventoryTrialAndOptimizerCounts(testCase)
plan = xpsh.buildPlan(projectFolder);
verifyEqual(testCase,plan.cell_count,92);
verifyEqual(testCase,plan.initial_trial_count,9200);
verifyEqual(testCase,plan.expected_optimizer_invocations,26200);
T = xpsh.inventoryTable(plan);
expectedFamilyCounts = [3,4,2,4,24,3,7,9,3,2,6,10,4,4,3,4];
actual = zeros(1,16);
for i=1:16,actual(i)=nnz(T.FamilyID==i);end
verifyEqual(testCase,actual,expectedFamilyCounts);
verifyEqual(testCase,sum(T.InitialOptimizerInvocations),26200);
verifyEqual(testCase,sum(T.InitialOptimizerInvocations(T.FamilyID==12)),0);
end

function testSeedScheduleIsDeterministicAndUnique(testCase)
plan=xpsh.buildPlan(projectFolder);
schedule=xpsh.seedSchedule(plan);
verifyEqual(testCase,height(schedule),9200);
verifyEqual(testCase,xpsh.seedFor(16,4,100,61),1600410061);
verifyEqual(testCase,numel(unique(schedule.Seed_C_noise)),height(schedule));
schedule2=xpsh.seedSchedule(plan);
verifyEqual(testCase,schedule,schedule2);
end

function testAllCellsGenerateAndValidateWithoutFitting(testCase)
plan=xpsh.buildPlan(projectFolder);
for i=1:numel(plan.cells)
    fixture=xpsh.generateFixture(plan.cells(i),1,projectFolder);
    result=xpsh.validateFixture(fixture);
    verifyTrue(testCase,fixture.no_fitting_performed,plan.cells(i).cell_key);
    verifyTrue(testCase,result.valid,strjoin(result.errors," | "));
end
end

function testIndependentBackgroundGenerators(testCase)
x=linspace(0,10,101).';
for method=["zero","linear","quadratic","shirley","tougaard"]
    [b,meta]=xpsh.generateBackground(x,zeros(size(x)),method);
    verifyEqual(testCase,b,zeros(size(x)),"AbsTol",0);
    verifyFalse(testCase,meta.production_estimator_called);
end
[b,~]=xpsh.generateBackground(x,ones(size(x)),"shirley");
verifyEqual(testCase,b,0.15*(1-x/10),"AbsTol",1e-12);
[b,~]=xpsh.generateBackground(x,ones(size(x)),"tougaard");
verifyEqual(testCase,b(1),0,"AbsTol",1e-14);
verifyGreaterThanOrEqual(testCase,min(b),-1e-14);
verifyEqual(testCase,max(b),0.15,"AbsTol",1e-12);
end

function testStatisticsAndResidualRules(testCase)
w=xpsh.wilsonInterval(95,100);
verifyEqual(testCase,w.observed_rate,0.95,"AbsTol",0);
verifyLessThan(testCase,w.lower,0.95);
verifyGreaterThan(testCase,w.upper,0.95);
s=xpsh.summarizeValues((1:100).');
verifyEqual(testCase,[s.p2_5,s.p95,s.p97_5],[3,95,98]);
verifyEqual(testCase,s.worst,100);
r=xpsh.residualAutocorrelation(zeros(10,1),ones(10,1));
verifyTrue(testCase,r.ResidualVarianceEffectivelyZero);
verifyEqual(testCase,r.rho1,0);
end

function testCheckpointResumeAndFingerprintRejection(testCase)
folder=string(tempname(tempdir)); mkdir(folder);
cleanup=onCleanup(@()deleteFolder(folder)); %#ok<NASGU>
fingerprint="test-fingerprint"; cellKey="F01_N1";
verifyTrue(testCase,xpsh.writeCheckpoint(folder,fingerprint,cellKey,1,struct("x",1)));
verifyTrue(testCase,xpsh.writeCheckpoint(folder,fingerprint,cellKey,3,struct("x",3)));
verifyFalse(testCase,xpsh.writeCheckpoint(folder,fingerprint,cellKey,1,struct("x",9)));
verifyEqual(testCase,xpsh.completedTrials(folder,fingerprint,cellKey),[1;3]);
verifyError(testCase,@()xpsh.completedTrials(folder,"wrong",cellKey), ...
    "xpsh:completedTrials:FingerprintMismatch");
end

function testSummarySchema(testCase)
T=xpsh.trialResultSchema;
verifyEqual(testCase,height(T),0);
verifyEqual(testCase,width(T),24);
verifyTrue(testCase,all(ismember(["TrialConverged", ...
    "PeakTruthAcceptable_A","CompositionTruthAcceptable_A", ...
    "DeployableOverallQCValid","ExactBoundHit"], ...
    string(T.Properties.VariableNames))));
end

function testPositionWindowIsConfigurationDriven(testCase)
model=xps.loadCompositionModelProfile(fullfile(projectFolder,"config", ...
    "composition","ruoff_primary_models_v1.json"));
verifyEqual(testCase,model.models.c1s_f1s_semi.allowed_center_range_eV(:).', ...
    [686.7 686.9],"AbsTol",0);
source=fileread(fullfile(projectFolder,"+xps","calculateComposition.m"));
verifyFalse(testCase,contains(source,"[686.7 686.9]"));
verifyTrue(testCase,contains(source,"loadCompositionModelProfile"));
end

function testFrozenPlanHash(testCase)
lock=jsondecode(fileread(fullfile(projectFolder, ...
    "PHASE_0H_PLAN_LOCK_v1.0.0.json")));
actual=xpsh.sha256File(fullfile(projectFolder, ...
    "PHASE_0H_TEST_PLAN_v1.0.0.md"));
verifyEqual(testCase,actual,string(lock.sha256));
end

function testExecutionPathFitsWithoutCreatingFigures(testCase)
plan=xpsh.buildPlan(projectFolder);
fixture=xpsh.generateFixture(plan.cells(1),1,projectFolder);
before=numel(findall(groot,"Type","figure"));
payload=xpsh.executeTrial(fixture,projectFolder);
after=numel(findall(groot,"Type","figure"));
verifyEqual(testCase,payload.status,"success");
verifyEqual(testCase,payload.optimizer_invocations,2);
verifyFalse(testCase,payload.plotting_enabled);
verifyEqual(testCase,after,before);
end

function testExecutionResumeErrorIsolationAndCellCheckpoint(testCase)
base=xpsh.buildPlan(projectFolder);
cellDef=base.cells(1);
cellDef.family_id=31;cellDef.family_name="UnitExecution";
cellDef.cell_index=1;cellDef.cell_id="U1";cellDef.cell_key="UNIT_U1";
cellDef.trials=2;cellDef.starts=1;cellDef.pipelines_per_trial=1;
cellDef.regions_per_pipeline=2;cellDef.optimizer_invocations_per_trial=2;
plan=base;plan.cells=cellDef;plan.cell_count=1;
plan.trials_per_cell=2;plan.initial_trial_count=2;
plan.expected_optimizer_invocations=4;
folder=string(tempname(tempdir));mkdir(folder);
cleanup=onCleanup(@()deleteFolder(folder)); %#ok<NASGU>
manifest=struct("run_mode","smoke","run_fingerprint","unit-fingerprint");
options=struct("MaxNewTrials",Inf,"TrialExecutor",@unitTrialExecutor, ...
    "Plotting",struct("enabled",false));
first=xpsh.executePlan(plan,folder,projectFolder,manifest,options);
root=fullfile(folder,"checkpoints");
verifyEqual(testCase,xpsh.completedTrials(root,"unit-fingerprint","UNIT_U1"),[1;2]);
verifyTrue(testCase,isfile(fullfile(root,"UNIT_U1","cell_complete.mat")));
one=load(fullfile(root,"UNIT_U1","trial_0001.mat"),"payload");
two=load(fullfile(root,"UNIT_U1","trial_0002.mat"),"payload");
verifyEqual(testCase,one.payload.status,"error");
verifyEqual(testCase,two.payload.status,"success");
verifyEqual(testCase,one.payload.seeds,xpsh.trialSeeds(cellDef,1));
files=[fullfile(root,"UNIT_U1","trial_0001.mat"); ...
    fullfile(root,"UNIT_U1","trial_0002.mat"); ...
    fullfile(root,"UNIT_U1","cell_complete.mat")];
before=arrayfun(@(i)xpsh.sha256File(files(i)),1:numel(files)).';
second=xpsh.executePlan(plan,folder,projectFolder,manifest,options);
after=arrayfun(@(i)xpsh.sha256File(files(i)),1:numel(files)).';
verifyEqual(testCase,first.new_trials_executed,2);
verifyEqual(testCase,second.new_trials_executed,0);
verifyEqual(testCase,before,after);
end

function testExecutionManifestAndPlottingPolicy(testCase)
plan=xpsh.buildPlan(projectFolder);
manifest=xpsh.createManifest(plan,projectFolder,"formal");
verifyEqual(testCase,manifest.plan_sha256,xpsh.sha256File(plan.plan_document));
verifyGreaterThan(testCase,strlength(manifest.code_config_fingerprint),0);
verifyFalse(testCase,manifest.execution.plotting_enabled);
verifyEqual(testCase,manifest.run_mode,"formal");
sources=[fullfile(projectFolder,"+xpsh","executePlan.m"); ...
    fullfile(projectFolder,"+xpsh","executeTrial.m"); ...
    fullfile(projectFolder,"runPhase0HFormal.m")];
for source=sources.'
    text=fileread(source);
    verifyFalse(testCase,contains(text,"plotFitComponents("));
    verifyEmpty(testCase,regexp(text,'(?m)^\s*figure\s*\(','once'));
end
end

function payload=unitTrialExecutor(fixture,~)
if fixture.trial_id==1
    error("testPhase0HHarness:ExpectedUnitFailure","intentional trial failure");
end
payload=struct("status","success","trial_converged",true, ...
    "optimizer_invocations",0,"elapsed_seconds",0,"plotting_enabled",false);
end

function folder=projectFolder
folder=string(fileparts(mfilename("fullpath")));
end

function deleteFolder(folder)
if isfolder(folder),rmdir(folder,"s");end
end
