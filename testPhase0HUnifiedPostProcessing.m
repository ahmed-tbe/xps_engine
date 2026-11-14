function tests = testPhase0HUnifiedPostProcessing
%TESTPHASE0HUNIFIEDPOSTPROCESSING Deterministic derived-metric/gate tests.
tests=functiontests(localfunctions);
end

function testCompositionOnlyScaleGateAndSchemas(testCase)
project=string(fileparts(mfilename("fullpath")));
fullPlan=xpsh.buildPlan(project);
idx=find(string({fullPlan.cells.cell_key})=="F12_R3",1);
cellDef=fullPlan.cells(idx);
fixture=xpsh.generateFixture(cellDef,1,project);
payload=xpsh.executeTrial(fixture,project);
[trial,peaks,composition,pair]=analyzePhase0HUnifiedTrial( ...
    payload,cellDef,"unit_test","unit_test_fingerprint");

verifyEmpty(testCase,peaks);
verifyEqual(testCase,numel(composition),6);
verifyFalse(testCase,pair.Applicable);
verifyTrue(testCase,trial.CompositionTruthAcceptable_A);
verifyTrue(testCase,trial.DeployableCompositionQCValid);

trialTable=struct2table(repmat(trial,100,1));
compositionTable=struct2table(repmat(composition(:),100,1));
peakTable=table(strings(0,1),VariableNames="CellKey");
pairTable=table(strings(0,1),VariableNames="CellKey");
plan=struct("cells",cellDef);
actual=summarizePhase0HUnifiedResults(plan,trialTable,peakTable, ...
    compositionTable,pairTable);
verifyEqual(testCase,actual.cellSummary.GateStatus,"pass");
verifyTrue(testCase,actual.cellSummary.GatePass);
verifyTrue(testCase,actual.cellSummary.ScaleCriterionPass);
verifyEmpty(testCase,actual.extensionCells);
end

function testWilsonBorderlineExtensionDoesNotExecuteAnything(testCase)
project=string(fileparts(mfilename("fullpath")));
fullPlan=xpsh.buildPlan(project);
idx=find(string({fullPlan.cells.cell_key})=="F12_R3",1);
cellDef=fullPlan.cells(idx); cellDef.gate="C";
fixture=xpsh.generateFixture(fullPlan.cells(idx),1,project);
payload=xpsh.executeTrial(fixture,project);
[trial,~,composition,~]=analyzePhase0HUnifiedTrial( ...
    payload,cellDef,"unit_test","unit_test_fingerprint");

trials=repmat(trial,100,1);
for i=1:100
    trials(i).CompositionTruthAcceptable_B=false;
    trials(i).OverallTruthAcceptable_B=false;
    trials(i).DeployableCompositionQCValid=false;
    trials(i).DeployableOverallQCValid=false;
end
trials(1).DeployableCompositionQCValid=true;
trials(1).DeployableOverallQCValid=true;
trialTable=struct2table(trials);
compositionTable=struct2table(repmat(composition(:),100,1));
emptyByCell=table(strings(0,1),VariableNames="CellKey");
plan=struct("cells",cellDef);
actual=summarizePhase0HUnifiedResults(plan,trialTable,emptyByCell, ...
    compositionTable,emptyByCell);

verifyEqual(testCase,actual.cellSummary.GateStatus,"pass");
verifyTrue(testCase,actual.cellSummary.ExtensionRecommended);
verifyTrue(testCase,contains(actual.cellSummary.ExtensionReasons, ...
    "Composition deployable false-valid"));
verifyEqual(testCase,height(actual.extensionCells),1);
end
