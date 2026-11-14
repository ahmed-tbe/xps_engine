function breakdown = buildPhase0HFailureBreakdown(cellSummary,peakSummary,compositionSummary,rateSummary,trialMetrics)
%BUILDPHASE0HFAILUREBREAKDOWN Attribute frozen-gate failures by criterion.
%
% This is reporting only. It reads the already-computed frozen metrics and
% does not alter a threshold or reinterpret Wilson intervals as gates.

n=height(cellSummary); rows=cell(n,1);
for i=1:n
    c=cellSummary(i,:); key=string(c.CellKey); gate=string(c.Gate);
    P=peakSummary(peakSummary.CellKey==key,:);
    C=compositionSummary(compositionSummary.CellKey==key,:);
    R=rateSummary(rateSummary.CellKey==key & rateSummary.QCType=="Deployable",:);
    T=trialMetrics(trialMetrics.CellKey==key,:);
    r=template(); r.FamilyID=c.FamilyID; r.FamilyName=string(c.FamilyName);
    r.CellKey=key; r.Gate=gate; r.GateStatus=string(c.GateStatus);

    r.ConvergenceFailure=convergenceFailed(c,gate);
    r.PeakCenterCriterion=metricFailed(P,"CenterAbsError_eV");
    r.FWHMCriterion=metricFailed(P,"FWHMRelativeError");
    r.MajorPeakAreaCriterion=metricFailed(P,"AreaRelativeError");
    r.MinorPeakFractionCriterion=metricFailed(P,"FractionAbsError_pp");
    r.CompositionFCCriterion=metricFailed(C,"FCRelativeError") || ...
        metricFailed(C,"CFRelativeError");
    r.FAtPercentCriterion=metricFailed(C,"FAtAbsError_pp");
    r.FalseValidCriterion=falseValidFailed(R,gate);
    r.FalseInvalidCriterion=falseInvalidFailed(R,gate);
    r.ChemicalLabelMisclassificationEvents=labelMisclassificationEvents(T,c.FamilyID);
    r.ChemicalLabelMisclassification= ...
        c.FamilyID==13 && r.FalseValidCriterion;
    r.QCWithholdingCount=c.NCompositionWithheld;
    r.QCWithholding=c.NCompositionWithheld>0;
    r.BoundSensitivity=c.FamilyID==15 && string(c.GateStatus)=="fail";
    r.PairCriterion=~logical(c.PairCriterionPass);
    r.ScaleCriterion=~logical(c.ScaleCriterionPass);
    reasons=strings(0,1);
    names=["ConvergenceFailure","PeakCenterCriterion","FWHMCriterion", ...
        "MajorPeakAreaCriterion","MinorPeakFractionCriterion", ...
        "CompositionFCCriterion","FAtPercentCriterion", ...
        "FalseValidCriterion","FalseInvalidCriterion", ...
        "ChemicalLabelMisclassification","QCWithholding", ...
        "BoundSensitivity","PairCriterion","ScaleCriterion"];
    labels=["convergence failure","peak-center criterion", ...
        "FWHM criterion","major-peak area criterion", ...
        "minor-peak fraction criterion","composition F/C criterion", ...
        "F-at.% criterion","false-valid criterion", ...
        "false-invalid criterion","chemical-label misclassification", ...
        "QC withholding","bound sensitivity","paired criterion", ...
        "scale criterion"];
    for j=1:numel(names)
        if r.(names(j)),reasons(end+1)=labels(j);end %#ok<AGROW>
    end
    if isempty(reasons) && string(c.GateStatus)=="fail"
        reasons="other frozen-gate criterion";
    end
    r.FailureReasons=strjoin(reasons,"; "); rows{i}=r;
end
breakdown=struct2table(vertcat(rows{:}));
end

function tf=convergenceFailed(c,gate)
if ismember(gate,["A","A_paired"]),tf=c.ConvergenceRate<.95;
elseif ismember(gate,["B","B_paired"]),tf=c.ConvergenceRate<.90;
elseif ismember(gate,["Order","Scale"]),tf=c.NConverged<c.NPlanned;
else,tf=false;end
end

function tf=metricFailed(T,metric)
tf=~isempty(T) && any(T.Metric==metric & ~T.Pass);
end

function tf=falseValidFailed(R,gate)
tf=false;if gate~="C",return;end
use=R.RateType=="FalseValid" & R.TruthTier=="B" & R.Denominator>0;
tf=any(R.ObservedRate(use)>.05);
end

function tf=falseInvalidFailed(R,gate)
if ismember(gate,["A","A_paired"]),tier="A";limit=.05;
elseif ismember(gate,["B","B_paired"]),tier="B";limit=.10;
else,tf=false;return;end
use=R.RateType=="FalseInvalid" & R.TruthTier==tier & R.Denominator>0;
tf=any(R.ObservedRate(use)>limit);
end

function count=labelMisclassificationEvents(T,familyID)
if familyID~=13 || isempty(T),count=0;return;end
use=T.CompositionApplicable & ~T.CompositionTruthAcceptable_B & ...
    T.DeployableCompositionQCValid;
count=nnz(use);
end

function r=template
r=struct("FamilyID",0,"FamilyName","","CellKey","","Gate","", ...
    "GateStatus","","ConvergenceFailure",false, ...
    "PeakCenterCriterion",false,"FWHMCriterion",false, ...
    "MajorPeakAreaCriterion",false,"MinorPeakFractionCriterion",false, ...
    "CompositionFCCriterion",false,"FAtPercentCriterion",false, ...
    "FalseValidCriterion",false,"FalseInvalidCriterion",false, ...
    "ChemicalLabelMisclassification",false, ...
    "ChemicalLabelMisclassificationEvents",0, ...
    "QCWithholding",false,"QCWithholdingCount",0, ...
    "BoundSensitivity",false,"PairCriterion",false, ...
    "ScaleCriterion",false,"FailureReasons","");
end
