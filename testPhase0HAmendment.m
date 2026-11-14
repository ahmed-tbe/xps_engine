function tests = testPhase0HAmendment
%TESTPHASE0HAMENDMENT Deterministic tests for amendment-only harness fixes.
tests=functiontests(localfunctions);
end

function testInitialCenterNormalOverlap(testCase)
[center,meta]=xpsh.selectInitialCenter(5,0.5,[4 6],5.1,0.25);
verifyEqual(testCase,center,4.75,"AbsTol",0);
verifyEqual(testCase,meta.rule,"truth_interval_intersection_uniform");
verifyTrue(testCase,meta.intersection_exists);
verifyGreaterThanOrEqual(testCase,center,4);
verifyLessThanOrEqual(testCase,center,6);
end

function testInitialCenterPartialOverlap(testCase)
[center,meta]=xpsh.selectInitialCenter(3.9,0.5,[4 6],5.1,0.25);
verifyEqual(testCase,center,4.1,"AbsTol",1e-14);
verifyEqual(testCase,meta.intersection_eV,[4 4.4],"AbsTol",1e-14);
verifyTrue(testCase,meta.intersection_exists);
verifyGreaterThanOrEqual(testCase,center,4);
verifyLessThanOrEqual(testCase,center,6);
end

function testInitialCenterDisjointUsesNominal(testCase)
[center,meta]=xpsh.selectInitialCenter(3,0.5,[4 6],5.1,0.99);
verifyEqual(testCase,center,5.1,"AbsTol",0);
verifyEqual(testCase,meta.rule, ...
    "configured_nominal_center_disjoint_truth_interval");
verifyFalse(testCase,meta.intersection_exists);
verifyGreaterThan(testCase,center,4);
verifyLessThan(testCase,center,6);
end

function testInitialCenterDeterministicForFixedSeedAndAlwaysLegal(testCase)
seed=100200111;
state=rng;cleanup=onCleanup(@()rng(state));
rng(seed,"twister");u1=rand;
rng(seed,"twister");u2=rand;
c1=xpsh.selectInitialCenter(5.8,0.5,[4 6],5.1,u1);
c2=xpsh.selectInitialCenter(5.8,0.5,[4 6],5.1,u2);
verifyEqual(testCase,c1,c2,"AbsTol",0);
for truthCenter=[3,3.9,5,6.1,7]
    center=xpsh.selectInitialCenter(truthCenter,0.5,[4 6],5.1,u1);
    verifyGreaterThanOrEqual(testCase,center,4);
    verifyLessThanOrEqual(testCase,center,6);
end
end

function testTruthLabelAdapter(testCase)
truth=struct("id","p1","label","generated truth label", ...
    "center_eV",5,"FWHM_eV",0.6,"physical_area",2.5);
actual=xpsh.truthAsFittedPeaks(truth);
verifyEqual(testCase,actual.id,"p1");
verifyEqual(testCase,actual.assignment,"generated truth label");
verifyEqual(testCase,actual.center_eV,5);
verifyEqual(testCase,actual.FWHM_eV,0.6);
verifyEqual(testCase,actual.area,2.5);
verifyFalse(testCase,isfield(truth,"assignment"));
end

function testAmendmentPlanAndOriginalSeeds(testCase)
project=projectFolder;
plan=xpsh.buildAmendmentPlan(project);
verifyEqual(testCase,plan.cell_count,11);
verifyEqual(testCase,plan.initial_trial_count,1100);
verifyEqual(testCase,plan.expected_optimizer_invocations,200);
verifyEqual(testCase,string({plan.cells.cell_key}).', ...
    ["F10_G2";"F12_R1";"F12_R2";"F12_R3";"F12_R4";"F12_R5"; ...
    "F12_T1";"F12_T2";"F12_T3";"F12_T4";"F12_T5"]);
family12=plan.cells([plan.cells.family_id]==12);
verifyEqual(testCase,sum([family12.optimizer_invocations_per_trial]),0);
actual=xpsh.seedSchedule(plan);
original=readtable(fullfile(project,"results","phase0h_formal_v1_0_0", ...
    "seed_schedule.csv"),TextType="string",VariableNamingRule="preserve");
expected=original(ismember(original.CellKey,string({plan.cells.cell_key})),:);
verifyTrue(testCase,tablesEqual(actual,expected));
end

function testFormerInvalidChargingFixturesAreNowLegal(testCase)
project=projectFolder;
plan=xpsh.buildAmendmentPlan(project);
cellDef=plan.cells(string({plan.cells.cell_key})=="F10_G2");
for trialID=[24 32 34]
    fixture=xpsh.generateFixture(cellDef,trialID,project);
    validation=xpsh.validateFixture(fixture);
    verifyTrue(testCase,validation.valid,strjoin(validation.errors," | "));
end
end

function testFamily12CompositionOnlyExecutionUsesNoOptimizer(testCase)
project=projectFolder;
plan=xpsh.buildAmendmentPlan(project);
cellDef=plan.cells(string({plan.cells.cell_key})=="F12_R3");
fixture=xpsh.generateFixture(cellDef,1,project);
before=numel(findall(groot,"Type","figure"));
payload=xpsh.executeTrial(fixture,project);
after=numel(findall(groot,"Type","figure"));
verifyEqual(testCase,payload.status,"success");
verifyTrue(testCase,payload.trial_converged);
verifyEqual(testCase,payload.optimizer_invocations,0);
verifyEqual(testCase,after,before);
end

function testAmendmentManifestReferencesOriginalProvenance(testCase)
project=projectFolder;
plan=xpsh.buildAmendmentPlan(project);
manifest=xpsh.createAmendmentManifest(plan,project,"amendment_dry_run");
verifyEqual(testCase,manifest.original_frozen_plan.plan_sha256, ...
    "1f932b278de41dc14154191833f45b5fcf55f3b5a01edd7a661ddcbcf2f556bf");
verifyEqual(testCase,manifest.original_execution.code_config_fingerprint, ...
    "93c6ad3a88ba0245be2043c06ca20c0adb62033989f051a6e71e340d31e292b4");
verifyTrue(testCase,manifest.original_execution.immutable);
verifyTrue(testCase,manifest.amendment.original_seeds_reused);
verifyEqual(testCase,numel(manifest.amendment.affected_cells),11);
verifyEqual(testCase,strlength(manifest.amended_execution_fingerprint),64);
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

function folder=projectFolder
folder=string(fileparts(mfilename("fullpath")));
end
