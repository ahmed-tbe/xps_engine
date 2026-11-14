function tests = testPhase0HExtension
%TESTPHASE0HEXTENSION Deterministic tests for the 101:400 extension path.
tests=functiontests(localfunctions);
end

function testPlanUsesExactAcceptedSelectionAndCounts(testCase)
plan=buildPhase0HExtensionPlan(projectFolder);
verifyEqual(testCase,plan.cell_count,42);
verifyEqual(testCase,plan.new_trial_count,12600);
verifyEqual(testCase,plan.expected_optimizer_invocations,40200);
verifyEqual(testCase,plan.first_trial_id,101);
verifyEqual(testCase,plan.last_trial_id,400);
verifyEqual(testCase,plan.remaining_unextended_cells,50);
verifyTrue(testCase,all([plan.cells.extension_trials]==300));
verifyTrue(testCase,all([plan.cells.final_trial_count]==400));
end

function testExtensionSeedsAreDeterministicUniqueAndDisjoint(testCase)
project=projectFolder; plan=buildPhase0HExtensionPlan(project);
actual=phase0HExtensionSeedSchedule(plan);
repeat=phase0HExtensionSeedSchedule(plan);
verifyEqual(testCase,actual,repeat);
verifyEqual(testCase,height(actual),12600);
verifyTrue(testCase,all(actual.TrialID>=101 & actual.TrialID<=400));
extension=seedValues(actual);
initial=seedValues(xpsh.seedSchedule(xpsh.buildPlan(project)));
verifyEqual(testCase,numel(unique(extension)),numel(extension));
verifyEmpty(testCase,intersect(extension,initial));
end

function testBoundaryFixturesAreValidAndNonGraphical(testCase)
project=projectFolder;plan=buildPhase0HExtensionPlan(project);
cellDef=plan.cells(1); before=findall(groot,"Type","figure");
for trialID=[101 400]
    fixture=xpsh.generateFixture(cellDef,trialID,project);
    validation=xpsh.validateFixture(fixture);
    verifyTrue(testCase,validation.valid,strjoin(validation.errors," | "));
    verifyEqual(testCase,fixture.seeds,xpsh.trialSeeds(cellDef,trialID));
end
verifyEqual(testCase,findall(groot,"Type","figure"),before);
end

function testManifestLinksFrozenParentsAndDisablesPlotting(testCase)
project=projectFolder;plan=buildPhase0HExtensionPlan(project);
manifest=createPhase0HExtensionManifest(plan,project,"extension_dry_run");
verifyEqual(testCase,manifest.plan_sha256, ...
    "1f932b278de41dc14154191833f45b5fcf55f3b5a01edd7a661ddcbcf2f556bf");
verifyEqual(testCase,manifest.parent_results.original_execution_fingerprint, ...
    "93c6ad3a88ba0245be2043c06ca20c0adb62033989f051a6e71e340d31e292b4");
verifyEqual(testCase,manifest.parent_results.amended_execution_fingerprint, ...
    "60ddb98176b263595a54ae115980c96dcb7e696dc64e2cd05b759aef2e2a55e6");
verifyFalse(testCase,manifest.execution.plotting_enabled);
verifyEqual(testCase,manifest.extension_trial_count,12600);
verifyEqual(testCase,strlength(manifest.extension_execution_fingerprint),64);
end

function testCheckpointResumeSkipsCompletedExtensionTrial(testCase)
project=projectFolder;plan=buildPhase0HExtensionPlan(project);
temp=string(tempname);mkdir(temp);cleanup=onCleanup(@()removeTemp(temp)); %#ok<NASGU>
plan.cells=plan.cells(1);plan.cell_count=1;plan.cells.extension_first_trial=101;
plan.cells.extension_last_trial=102;plan.cells.extension_trials=2;
plan.new_trial_count=2;plan.expected_optimizer_invocations=0;
manifest=struct("run_mode","extension_smoke", ...
    "run_fingerprint","phase0h-extension-unit-test");
one=executePhase0HExtensionPlan(plan,temp,project,manifest, ...
    struct("MaxNewTrials",1,"TrialExecutor",@dummyExecutor, ...
    "Plotting",struct("enabled",false)));
two=executePhase0HExtensionPlan(plan,temp,project,manifest, ...
    struct("MaxNewTrials",Inf,"TrialExecutor",@dummyExecutor, ...
    "Plotting",struct("enabled",false)));
three=executePhase0HExtensionPlan(plan,temp,project,manifest, ...
    struct("MaxNewTrials",Inf,"TrialExecutor",@dummyExecutor, ...
    "Plotting",struct("enabled",false)));
verifyEqual(testCase,one.new_trials_executed,1);
verifyEqual(testCase,two.new_trials_executed,1);
verifyEqual(testCase,two.previous_trials_skipped,1);
verifyEqual(testCase,three.new_trials_executed,0);
verifyEqual(testCase,three.previous_trials_skipped,2);
ids=xpsh.completedTrials(fullfile(temp,"checkpoints"), ...
    manifest.run_fingerprint,string(plan.cells.cell_key));
verifyEqual(testCase,ids,[101;102]);
end

function testFailureBreakdownHasRequestedCategories(testCase)
cellSummary=table(1,"family","cell","B","fail",100,100,0,80,20,.8, ...
    0,0,false,false,true,true,VariableNames=["FamilyID","FamilyName", ...
    "CellKey","Gate","GateStatus","NPlanned","NUsable", ...
    "NExecutionError","NConverged","NNonconverged","ConvergenceRate", ...
    "NCompositionWithheld","NQCInvalid","PeakDistributionPass", ...
    "CompositionDistributionPass","PairCriterionPass","ScaleCriterionPass"]);
peak=table("cell","C1s","p","CenterAbsError_eV",false, ...
    VariableNames=["CellKey","Region","PeakID","Metric","Pass"]);
composition=table("cell","m","FAtAbsError_pp",false, ...
    VariableNames=["CellKey","ModelPath","Metric","Pass"]);
rates=table("cell","Overall","Deployable","B","FalseInvalid",2,10,.2, ...
    VariableNames=["CellKey","Dimension","QCType","TruthTier", ...
    "RateType","Events","Denominator","ObservedRate"]);
trial=table(repmat("cell",2,1),true(2,1),false(2,1),false(2,1), ...
    VariableNames=["CellKey","CompositionApplicable", ...
    "CompositionTruthAcceptable_B","DeployableCompositionQCValid"]);
actual=buildPhase0HFailureBreakdown(cellSummary,peak,composition,rates,trial);
verifyTrue(testCase,actual.ConvergenceFailure);
verifyTrue(testCase,actual.PeakCenterCriterion);
verifyTrue(testCase,actual.FAtPercentCriterion);
verifyTrue(testCase,actual.FalseInvalidCriterion);
verifyTrue(testCase,contains(actual.FailureReasons,"convergence failure"));
end

function payload=dummyExecutor(fixture,~)
payload=struct("status","success","trial_converged",true, ...
    "optimizer_invocations",0,"elapsed_seconds",0, ...
    "fixture_trial_id",fixture.trial_id);
end

function values=seedValues(T)
names=string(T.Properties.VariableNames);names=names(startsWith(names,"Seed_"));
values=reshape(table2array(T(:,cellstr(names))),[],1);
end

function removeTemp(folder)
if isfolder(folder),rmdir(folder,"s");end
end

function folder=projectFolder
folder=string(fileparts(mfilename("fullpath")));
end
