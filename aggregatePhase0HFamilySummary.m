function familySummary = aggregatePhase0HFamilySummary(trialSummary)
%AGGREGATEPHASE0HFAMILYSUMMARY Stable reporting-only family aggregation.
%
% The output schema is constructed as a table from preallocated columns so
% every row has exactly the same variables and MATLAB types.

required = ["FamilyID","FamilyName","Status","TrialConverged", ...
    "OptimizerInvocations","ElapsedSeconds"];
missing = setdiff(required,string(trialSummary.Properties.VariableNames));
if ~isempty(missing)
    error("aggregatePhase0HFamilySummary:MissingVariables", ...
        "Trial summary is missing: %s.",strjoin(missing,", "));
end

familyIDs = unique(trialSummary.FamilyID,"stable");
nFamilies = numel(familyIDs);
FamilyID = zeros(nFamilies,1,"like",trialSummary.FamilyID);
FamilyName = strings(nFamilies,1);
Trials = zeros(nFamilies,1);
ErrorTrials = zeros(nFamilies,1);
ConvergedTrials = zeros(nFamilies,1);
ConvergenceRate = zeros(nFamilies,1);
WilsonLower95 = zeros(nFamilies,1);
WilsonUpper95 = zeros(nFamilies,1);
OptimizerInvocations = zeros(nFamilies,1);
ElapsedSeconds = zeros(nFamilies,1);

for i = 1:nFamilies
    use = trialSummary.FamilyID == familyIDs(i);
    n = nnz(use);
    k = nnz(trialSummary.TrialConverged(use));
    interval = xpsh.wilsonInterval(k,n);
    FamilyID(i) = familyIDs(i);
    FamilyName(i) = string(trialSummary.FamilyName(find(use,1)));
    Trials(i) = n;
    ErrorTrials(i) = nnz(string(trialSummary.Status(use)) == "error");
    ConvergedTrials(i) = k;
    ConvergenceRate(i) = k/n;
    WilsonLower95(i) = interval.lower;
    WilsonUpper95(i) = interval.upper;
    OptimizerInvocations(i) = sum(trialSummary.OptimizerInvocations(use));
    ElapsedSeconds(i) = sum(trialSummary.ElapsedSeconds(use));
end

familySummary = table(FamilyID,FamilyName,Trials,ErrorTrials, ...
    ConvergedTrials,ConvergenceRate,WilsonLower95,WilsonUpper95, ...
    OptimizerInvocations,ElapsedSeconds);
end
