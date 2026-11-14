function tests = testPhase0HPostProcessing
%TESTPHASE0HPOSTPROCESSING Reporting-only aggregation regression tests.
tests=functiontests(localfunctions);
end

function testLegacyFieldlessStructAggregationReproducesFailure(testCase)
rows=repmat(struct(),2,1);
didFail=false;
try
    rows(1)=struct("FamilyID",1,"FamilyName","Noise","Trials",2); %#ok<NASGU>
catch exception
    didFail=contains(lower(string(exception.message)), ...
        "dissimilar structures");
end
verifyTrue(testCase,didFail, ...
    "The regression fixture must reproduce MATLAB's dissimilar-struct failure.");
end

function testStableFamilyAggregationSchemaAndValues(testCase)
FamilyID=[1;1;2];
FamilyName=["Noise";"Noise";"Overlap"];
Status=["success";"error";"success"];
TrialConverged=[true;false;true];
OptimizerInvocations=[2;0;10];
ElapsedSeconds=[1.25;0.25;4.5];
trials=table(FamilyID,FamilyName,Status,TrialConverged, ...
    OptimizerInvocations,ElapsedSeconds);

actual=aggregatePhase0HFamilySummary(trials);
verifyEqual(testCase,string(actual.Properties.VariableNames), ...
    ["FamilyID","FamilyName","Trials","ErrorTrials", ...
    "ConvergedTrials","ConvergenceRate","WilsonLower95", ...
    "WilsonUpper95","OptimizerInvocations","ElapsedSeconds"]);
verifyEqual(testCase,actual.FamilyID,[1;2]);
verifyEqual(testCase,actual.FamilyName,["Noise";"Overlap"]);
verifyEqual(testCase,actual.Trials,[2;1]);
verifyEqual(testCase,actual.ErrorTrials,[1;0]);
verifyEqual(testCase,actual.ConvergedTrials,[1;1]);
verifyEqual(testCase,actual.ConvergenceRate,[0.5;1],"AbsTol",0);
verifyEqual(testCase,actual.OptimizerInvocations,[2;10]);
verifyEqual(testCase,actual.ElapsedSeconds,[1.5;4.5],"AbsTol",0);
expected=xpsh.wilsonInterval(1,2);
verifyEqual(testCase,actual.WilsonLower95(1),expected.lower,"AbsTol",1e-14);
verifyEqual(testCase,actual.WilsonUpper95(1),expected.upper,"AbsTol",1e-14);
end

function testPostprocessingProvenanceIsSeparate(testCase)
p=phase0HPostprocessingProvenance(string(fileparts(mfilename("fullpath"))));
verifyEqual(testCase,string(p.postprocessing_version),"1.0.1");
verifyEqual(testCase,strlength(string(p.postprocessing_sha256)),64);
verifyEqual(testCase,numel(p.files),4);
end
