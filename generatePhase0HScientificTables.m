function package = generatePhase0HScientificTables(outputFolder)
%GENERATEPHASE0HSCIENTIFICTABLES Read-only scientific interpretation tables.
%
% This post-processing function never writes to a formal, amendment,
% extension, or unified Phase 0H result directory. It reads the frozen
% mixed-N final summary and writes a separately versioned conclusions
% package containing tables and figures only.

arguments
    outputFolder (1,1) string = ""
end
projectFolder=string(fileparts(mfilename("fullpath")));
sourceFolder=fullfile(projectFolder,"results","phase0h_final_v1_0_0");
if strlength(outputFolder)==0
    outputFolder=fullfile(projectFolder,"results","phase0h_conclusions_v1_0_0");
end
assertSeparate(outputFolder,sourceFolder);
if folderHasEntries(outputFolder)
    error("generatePhase0HScientificTables:OutputExists", ...
        "Conclusions output must be new or empty: %s",outputFolder);
end
if ~isfolder(outputFolder),mkdir(outputFolder);end
plotsFolder=fullfile(outputFolder,"plots");mkdir(plotsFolder);

before=phase0HResultIntegritySnapshot(sourceFolder);
sourceFile=fullfile(sourceFolder,"phase0h_final_summary.mat");
loaded=load(sourceFile,"summary");s=loaded.summary;
validateFrozenSummary(s);
plan=xpsh.buildPlan(projectFolder);

perCell=buildPerCell(s,plan);
gateOverview=buildGateOverview(s.cellSummary);
familySummary=buildFamilySummary(perCell);
model1=buildModelRobustness(perCell,"Model1");
model2=buildModelRobustness(perCell,"Model2");
qc=buildQCTable(s,perCell);
sensitivity=buildSensitivityTable(s,plan);
failure=buildFailureDecomposition(s,perCell);
modelComparison=buildModelComparison(perCell);
recommendations=buildRecommendations;
charging=extractChargingTrials(s);

writetable(gateOverview,fullfile(outputFolder,"gate_overview.csv"));
writetable(modelComparison,fullfile(outputFolder,"model_comparison.csv"));
writetable(familySummary,fullfile(outputFolder,"family_summary.csv"));
writetable(perCell,fullfile(outputFolder,"per_cell_summary.csv"));
writetable(failure,fullfile(outputFolder,"gate_failure_decomposition.csv"));
writetable(model1,fullfile(outputFolder,"model1_robustness.csv"));
writetable(model2,fullfile(outputFolder,"model2_robustness.csv"));
writetable(qc,fullfile(outputFolder,"qc_false_valid_false_invalid.csv"));
writetable(sensitivity,fullfile(outputFolder,"sensitivity_factor_sweep.csv"));
writetable(recommendations,fullfile(outputFolder,"sample_AB_investigation_priorities.csv"));
writetable(charging,fullfile(outputFolder,"charging_shift_trial_diagnostics.csv"));

plotErrorVsSNR(perCell,plotsFolder);
plotOverlap(perCell,plotsFolder);
plotPeakShape(perCell,plotsFolder);
plotBackground(perCell,plotsFolder);
plotTruncation(perCell,plotsFolder);
plotCharging(charging,plotsFolder);
plotSensitivity(sensitivity,plotsFolder);
plotBounds(s,perCell,plotsFolder);
plotFalseRates(familySummary,plotsFolder);

after=phase0HResultIntegritySnapshot(sourceFolder);
if ~isequaln(before,after)
    error("generatePhase0HScientificTables:SourceChanged", ...
        "Frozen final Phase 0H output changed during read-only analysis.");
end
postFiles=["generatePhase0HScientificTables.m"; ...
    "analyzePhase0HUnifiedTrial.m";"summarizePhase0HUnifiedResults.m"];
postHashes=strings(size(postFiles));
for i=1:numel(postFiles),postHashes(i)=xpsh.sha256File(fullfile(projectFolder,postFiles(i)));end
manifest=struct("package_id","phase0h_scientific_conclusions", ...
    "package_version","1.0.0", ...
    "generated_at",string(datetime("now","TimeZone","America/Chicago", ...
        "Format","yyyy-MM-dd'T'HH:mm:ssXXX")), ...
    "read_only_postprocessing",true,"monte_carlo_trials_executed",0, ...
    "source_summary",replace(sourceFile,projectFolder+filesep,""), ...
    "source_summary_sha256",xpsh.sha256File(sourceFile), ...
    "source_provenance_sha256",xpsh.sha256File(fullfile(sourceFolder, ...
        "final_provenance.json")),"plan_sha256",string(s.plan_sha256), ...
    "cell_count",92,"trial_count",21800,"extended_cells",42, ...
    "unextended_cells",50,"source_integrity_unchanged",true, ...
    "postprocessing_files",postFiles,"postprocessing_sha256",postHashes, ...
    "postprocessing_combined_sha256", ...
        xpsh.sha256Text(strjoin(postFiles+":"+postHashes,newline)), ...
    "sample_C_used",false,"production_configuration_changed",false, ...
    "thresholds_changed",false);
xpsh.writeJsonAtomic(fullfile(outputFolder,"conclusions_manifest.json"),manifest);
package=struct("manifest",manifest,"gateOverview",gateOverview, ...
    "modelComparison",modelComparison,"familySummary",familySummary, ...
    "perCell",perCell,"failure",failure,"model1",model1,"model2",model2, ...
    "qc",qc,"sensitivity",sensitivity,"recommendations",recommendations, ...
    "charging",charging,"output_folder",outputFolder);
save(fullfile(outputFolder,"phase0h_conclusions_tables.mat"),"package","-v7.3");
fprintf("Phase 0H scientific tables created read-only at %s\n",outputFolder);
fprintf("Cells=%d; final trials=%d; plots=%d; frozen source unchanged=%s.\n", ...
    height(perCell),s.trial_count,numel(dir(fullfile(plotsFolder,"*.png"))), ...
    string(manifest.source_integrity_unchanged));
end

function validateFrozenSummary(s)
required=struct("cell_count",92,"trial_count",21800, ...
    "extended_cell_count",42,"unextended_cell_count",50,"execution_errors",0);
names=fieldnames(required);
for i=1:numel(names)
    if s.(names{i})~=required.(names{i})
        error("generatePhase0HScientificTables:FrozenSummaryMismatch", ...
            "%s does not match the accepted final result.",names{i});
    end
end
if ~logical(s.provenance_validation_passed) || ...
        ~logical(s.observed_rates_are_primary_gates) || ...
        ~logical(s.wilson_intervals_are_uncertainty_only) || ...
        ~logical(s.thresholds_unchanged)
    error("generatePhase0HScientificTables:Provenance", ...
        "Final summary provenance/gate policy is not frozen as expected.");
end
end

function T=buildPerCell(s,plan)
C=s.compositionMetrics;P=s.peakMetrics;R=s.rateSummary;Trials=s.trialMetrics;
cellSummary=s.cellSummary; failure=s.failureBreakdown;
n=height(cellSummary);rows=cell(n,1);
for i=1:n
    c=cellSummary(i,:);key=string(c.CellKey);pt=Trials(Trials.CellKey==key,:);
    planCell=plan.cells(string({plan.cells.cell_key})==key);
    m1=modelMetrics(C,key,"primary.c1s_main_cf",c.NPlanned);
    m2=modelMetrics(C,key,"primary.c1s_f1s_semi",c.NPlanned);
    r=cellTemplate();r.FamilyID=c.FamilyID;r.FamilyName=string(c.FamilyName);
    r.CellKey=key;r.Scenario=string(planCell.description);r.FinalN=c.NPlanned;
    r.Gate=string(c.Gate);r.GateStatus=string(c.GateStatus);
    r.ConvergenceRate=c.ConvergenceRate;
    r.C1sMedianRMSE=medianFinite(pt.C1sRMSE);r.C1sMedianR2=medianFinite(pt.C1sR2);
    r.C1sP95AbsResidualRho1=p95Finite(abs(pt.C1sResidualRho1));
    r.F1sMedianRMSE=medianFinite(pt.F1sRMSE);r.F1sMedianR2=medianFinite(pt.F1sR2);
    r.F1sP95AbsResidualRho1=p95Finite(abs(pt.F1sResidualRho1));
    [r.CenterMedianWorstPeak_eV,r.CenterP95WorstPeak_eV]= ...
        peakMetric(P,key,"CenterAbsError_eV");
    [r.FWHMMedianWorstPeak_rel,r.FWHMP95WorstPeak_rel]= ...
        peakMetric(P,key,"FWHMRelativeError");
    [r.MajorAreaMedianWorstPeak_rel,r.MajorAreaP95WorstPeak_rel]= ...
        peakMetric(P,key,"AreaRelativeError");
    [r.MinorFractionMedianWorstPeak_pp,r.MinorFractionP95WorstPeak_pp]= ...
        peakMetric(P,key,"FractionAbsError_pp");
    r.Model1MedianFC=m1.MedianFC;r.Model1MedianFCError_rel=m1.MedianFCError;
    r.Model1P95FCError_rel=m1.P95FCError;r.Model1MedianFAtAbsError_pp=m1.MedianFAtError;
    r.Model1P95FAtAbsError_pp=m1.P95FAtError;r.Model1WithheldRate=m1.WithheldRate;
    r.Model2MedianFC=m2.MedianFC;r.Model2MedianFCError_rel=m2.MedianFCError;
    r.Model2P95FCError_rel=m2.P95FCError;r.Model2MedianFAtAbsError_pp=m2.MedianFAtError;
    r.Model2P95FAtAbsError_pp=m2.P95FAtError;r.Model2WithheldRate=m2.WithheldRate;
    r.AnyCompositionWithheldRate=c.NCompositionWithheld/c.NPlanned;
    r.ExactBoundRate=c.ExactBoundRate;
    r.NearBoundRate=nearBoundRate(P,key,c.NPlanned);
    tier=assignedTier(string(c.Gate));
    r.PeakFalseValidRate=rateValue(R,key,"Peak","FalseValid",tier);
    r.CompositionFalseValidRate=rateValue(R,key,"Composition","FalseValid",tier);
    r.OverallFalseValidRate=rateValue(R,key,"Overall","FalseValid",tier);
    r.PeakFalseInvalidRate=rateValue(R,key,"Peak","FalseInvalid",tier);
    r.CompositionFalseInvalidRate=rateValue(R,key,"Composition","FalseInvalid",tier);
    r.OverallFalseInvalidRate=rateValue(R,key,"Overall","FalseInvalid",tier);
    r.MaxDimensionFalseValidRate=max([r.PeakFalseValidRate, ...
        r.CompositionFalseValidRate,r.OverallFalseValidRate],[],"omitnan");
    r.MaxDimensionFalseInvalidRate=max([r.PeakFalseInvalidRate, ...
        r.CompositionFalseInvalidRate,r.OverallFalseInvalidRate],[],"omitnan");
    r.InjectedLabelMisclassificationRate=double(c.FamilyID==13);
    r.DangerousLabelAcceptanceRate=labelAcceptanceRate(C,key,c.FamilyID,c.NPlanned);
    f=failure(failure.CellKey==key,:);r.PrimaryFailureReasons=string(f.FailureReasons);
    r.PeakDistributionPass=logical(c.PeakDistributionPass);
    r.CompositionDistributionPass=logical(c.CompositionDistributionPass);
    r.Model1ThresholdAssessment=assessModel(m1,string(c.Gate));
    r.Model2ThresholdAssessment=assessModel(m2,string(c.Gate));
    rows{i}=r;
end
T=struct2table(vertcat(rows{:}));
end

function m=modelMetrics(C,key,path,n)
one=C(C.CellKey==key&C.ModelPath==path&C.Applicable,:);
m=struct("MedianFC",NaN,"MedianFCError",NaN,"P95FCError",NaN, ...
    "MedianFAtError",NaN,"P95FAtError",NaN,"WithheldRate",NaN);
if isempty(one),return;end
finite=one.ActualFinite;
m.WithheldRate=nnz(~finite)/max(n,1);
m.MedianFC=medianFinite(one.ActualF_over_C(finite));
m.MedianFCError=medianFinite(one.FCRelativeError(finite));
m.P95FCError=p95Finite(one.FCRelativeError(finite));
m.MedianFAtError=medianFinite(one.FAtAbsError_pp(finite));
m.P95FAtError=p95Finite(one.FAtAbsError_pp(finite));
end

function [med,p95]=peakMetric(P,key,metric)
one=P(P.CellKey==key,:);
if metric=="CenterAbsError_eV"||metric=="FWHMRelativeError"
    one=one(one.TruthPresent&one.FitPresent&one.TruthArea>0,:);
elseif metric=="AreaRelativeError"
    one=one(one.AreaClass=="major",:);
else
    one=one(one.AreaClass~="major",:);
end
values=one.(metric);valid=isfinite(values);one=one(valid,:);values=values(valid);
if isempty(one),med=NaN;p95=NaN;return;end
[g,~,~]=findgroups(one.Region,one.PeakID);
medByPeak=splitapply(@median,values,g);
p95ByPeak=splitapply(@(x)prctile(x,95),values,g);
med=max(medByPeak,[],"omitnan");p95=max(p95ByPeak,[],"omitnan");
end

function rate=nearBoundRate(P,key,n)
one=P(P.CellKey==key,:);rate=NaN;if isempty(one),return;end
[~,~,g]=unique(one.TrialID);anyNear=splitapply(@any,one.NearBoundHit,g);
rate=nnz(anyNear)/n;
end

function rate=rateValue(R,key,dimension,type,tier)
rate=NaN;if tier=="",return;end
use=R.CellKey==key&R.QCType=="Deployable"&R.TruthTier==tier&R.RateType==type;
if dimension~="Any",use=use&R.Dimension==dimension;end
one=R(use&R.Denominator>0,:);
if ~isempty(one),rate=max(one.ObservedRate,[],"omitnan");end
end

function rate=labelAcceptanceRate(C,key,familyID,n)
if familyID~=13,rate=NaN;return;end
one=C(C.CellKey==key&C.ModelPath=="primary.c1s_f1s_semi"&C.Applicable,:);
rate=nnz(one.ActualFinite&one.ActualValid)/n;
end

function value=assessModel(m,gate)
tier=assignedTier(gate);
if tier=="",value="descriptive_or_noncomposition_gate";return;end
if m.WithheldRate>=1,value="withheld";return;end
if tier=="A",fc=[.03,.10];fat=[1,3];else,fc=[.05,.15];fat=[1.5,5];end
pass=m.MedianFCError<=fc(1)&&m.P95FCError<=fc(2)&& ...
    m.MedianFAtError<=fat(1)&&m.P95FAtError<=fat(2);
if pass,value="meets_assigned_composition_limits";else,value="fails_assigned_composition_limits";end
end

function T=buildGateOverview(S)
labels=["Gate A";"Gate A paired";"Gate B";"Gate B paired";"Gate C"; ...
    "Order";"Scale";"Descriptive only"];
gates=["A";"A_paired";"B";"B_paired";"C";"Order";"Scale";"C_descriptive"];
n=numel(gates);Cells=zeros(n,1);Pass=zeros(n,1);Fail=zeros(n,1);Descriptive=zeros(n,1);
for i=1:n
    one=S(S.Gate==gates(i),:);Cells(i)=height(one);Pass(i)=nnz(one.GateStatus=="pass");
    Fail(i)=nnz(one.GateStatus=="fail");
    Descriptive(i)=nnz(one.GateStatus=="descriptive_no_acceptance_gate");
end
T=table(labels,gates,Cells,Pass,Fail,Descriptive, ...
    VariableNames=["GateCategory","GateCode","Cells","Pass","Fail","Descriptive"]);
end

function T=buildFamilySummary(P)
ids=unique(P.FamilyID,"stable");rows=cell(numel(ids),1);
for i=1:numel(ids)
    one=P(P.FamilyID==ids(i),:);r=familyTemplate();r.FamilyID=ids(i);
    r.FamilyName=one.FamilyName(1);r.CellIDs=strjoin(one.CellKey,", ");
    r.Scenarios=strjoin(one.CellKey+"="+one.Scenario,"; ");
    r.FinalN=strjoin(unique(string(one.FinalN),"stable"),"/");
    r.AssignedGates=strjoin(unique(one.Gate,"stable"),"/");
    r.PassCells=nnz(one.GateStatus=="pass");r.FailCells=nnz(one.GateStatus=="fail");
    r.DescriptiveCells=nnz(one.GateStatus=="descriptive_no_acceptance_gate");
    r.MinimumConvergenceRate=min(one.ConvergenceRate,[],"omitnan");
    r.WorstCenterP95_eV=max(one.CenterP95WorstPeak_eV,[],"omitnan");
    r.WorstFWHMP95_rel=max(one.FWHMP95WorstPeak_rel,[],"omitnan");
    r.WorstMajorAreaP95_rel=max(one.MajorAreaP95WorstPeak_rel,[],"omitnan");
    r.WorstMinorFractionP95_pp=max(one.MinorFractionP95WorstPeak_pp,[],"omitnan");
    r.WorstModel1FCP95_rel=max(one.Model1P95FCError_rel,[],"omitnan");
    r.WorstModel1FAtP95_pp=max(one.Model1P95FAtAbsError_pp,[],"omitnan");
    r.WorstModel2FCP95_rel=max(one.Model2P95FCError_rel,[],"omitnan");
    r.WorstModel2FAtP95_pp=max(one.Model2P95FAtAbsError_pp,[],"omitnan");
    r.MaximumModel2WithheldRate=max(one.Model2WithheldRate,[],"omitnan");
    r.MaximumFalseValidRate=max(one.MaxDimensionFalseValidRate,[],"omitnan");
    r.MaximumFalseInvalidRate=max(one.MaxDimensionFalseInvalidRate,[],"omitnan");
    r.MaximumExactBoundRate=max(one.ExactBoundRate,[],"omitnan");
    r.MaximumNearBoundRate=max(one.NearBoundRate,[],"omitnan");
    reasons=unique(one.PrimaryFailureReasons(strlength(one.PrimaryFailureReasons)>0),"stable");
    r.PrimaryFailureReasons=strjoin(reasons," | ");rows{i}=r;
end
T=struct2table(vertcat(rows{:}));
end

function T=buildModelRobustness(P,prefix)
base=P(:,["FamilyID","FamilyName","CellKey","Scenario","FinalN","Gate","GateStatus"]);
if prefix=="Model1"
    base.MedianF_over_C=P.Model1MedianFC;base.MedianFCError_rel=P.Model1MedianFCError_rel;
    base.P95FCError_rel=P.Model1P95FCError_rel;base.MedianFAtAbsError_pp=P.Model1MedianFAtAbsError_pp;
    base.P95FAtAbsError_pp=P.Model1P95FAtAbsError_pp;base.WithheldRate=P.Model1WithheldRate;
    base.ThresholdAssessment=P.Model1ThresholdAssessment;
else
    base.MedianF_over_C=P.Model2MedianFC;base.MedianFCError_rel=P.Model2MedianFCError_rel;
    base.P95FCError_rel=P.Model2P95FCError_rel;base.MedianFAtAbsError_pp=P.Model2MedianFAtAbsError_pp;
    base.P95FAtAbsError_pp=P.Model2P95FAtAbsError_pp;base.WithheldRate=P.Model2WithheldRate;
    base.ThresholdAssessment=P.Model2ThresholdAssessment;
end
T=base;
end

function T=buildQCTable(s,P)
T=P(:,["FamilyID","FamilyName","CellKey","FinalN","Gate","GateStatus", ...
    "PeakFalseValidRate","CompositionFalseValidRate","OverallFalseValidRate", ...
    "PeakFalseInvalidRate","CompositionFalseInvalidRate", ...
    "OverallFalseInvalidRate","MaxDimensionFalseValidRate", ...
    "MaxDimensionFalseInvalidRate","AnyCompositionWithheldRate", ...
    "Model2WithheldRate","InjectedLabelMisclassificationRate", ...
    "DangerousLabelAcceptanceRate","ExactBoundRate","NearBoundRate"]);
T.NQCInvalid=s.cellSummary.NQCInvalid;
T.QCInvalidRate=s.cellSummary.NQCInvalid./s.cellSummary.NPlanned;
end

function T=buildSensitivityTable(s,plan)
C=s.compositionMetrics;cells=plan.cells([plan.cells.family_id]==12);rows=cell(numel(cells),1);
for i=1:numel(cells)
    c=cells(i);one=C(C.CellKey==string(c.cell_key)& ...
        C.ModelPath=="primary.c1s_f1s_semi",:);finite=one.ActualFinite;
    base=3.95;if startsWith(c.settings.sensitivity_base_profile,"thermo"),base=4.118;end
    rows{i}=struct("CellKey",string(c.cell_key), ...
        "BaseProfile",string(c.settings.sensitivity_base_profile), ...
        "BaseS_F",base,"Multiplier",c.settings.sensitivity_multiplier, ...
        "AppliedS_F",base*c.settings.sensitivity_multiplier, ...
        "TrueF_over_C",medianFinite(one.TrueF_over_C), ...
        "MedianRetrievedF_over_C",medianFinite(one.ActualF_over_C(finite)), ...
        "MedianRetrievedFAt_pct",medianFinite(one.ActualF_atpct(finite)), ...
        "MedianFCError_rel",medianFinite(one.FCRelativeError(finite)), ...
        "MedianFAtAbsError_pp",medianFinite(one.FAtAbsError_pp(finite)), ...
        "Gate",string(c.gate));
end
T=struct2table(vertcat(rows{:}));
end

function T=buildFailureDecomposition(s,P)
labels=["center accuracy";"FWHM accuracy";"major peak area"; ...
    "minor peak fraction";"F/C";"F-at.%";"false-valid"; ...
    "false-invalid";"misclassification";"withholding"; ...
    "bound sensitivity";"convergence"];
fields=["PeakCenterCriterion";"FWHMCriterion";"MajorPeakAreaCriterion"; ...
    "MinorPeakFractionCriterion";"CompositionFCCriterion";"FAtPercentCriterion"; ...
    "FalseValidCriterion";"FalseInvalidCriterion";"ChemicalLabelMisclassification"; ...
    "QCWithholding";"BoundSensitivity";"ConvergenceFailure"];
n=numel(labels);CellCount=zeros(n,1);TrialCount=zeros(n,1);Denominator=zeros(n,1);
F=s.failureBreakdown;
for i=1:n,CellCount(i)=nnz(F.(fields(i)));end

% Per-trial counts use the assigned A/B truth tier. Gate C uses Tier B for
% its false-valid question; nonquantitative Order/Scale/descriptive cells
% are excluded from component-error denominators.
flags=containers.Map(cellstr(labels),cell(n,1));
for i=1:n,flags(char(labels(i)))=strings(0,1);end
for i=1:height(P)
    gate=P.Gate(i);tier=assignedTier(gate);if tier=="",continue;end
    key=P.CellKey(i);tr=s.trialMetrics(s.trialMetrics.CellKey==key,:);
    pk=s.peakMetrics(s.peakMetrics.CellKey==key,:);
    cp=s.compositionMetrics(s.compositionMetrics.CellKey==key& ...
        s.compositionMetrics.GateApplicable,:);
    if tier=="A",ct=.15;wt=.25;at=.15;ft=1.5;rt=.10;fat=3;
    else,ct=.30;wt=.50;at=.30;ft=3;rt=.15;fat=5;end
    flags=appendTrialKeys(flags,"center accuracy",key, ...
        pk.TrialID(pk.TruthPresent&pk.FitPresent&pk.TruthArea>0&pk.CenterAbsError_eV>ct));
    flags=appendTrialKeys(flags,"FWHM accuracy",key, ...
        pk.TrialID(pk.TruthPresent&pk.FitPresent&pk.TruthArea>0&pk.FWHMRelativeError>wt));
    flags=appendTrialKeys(flags,"major peak area",key, ...
        pk.TrialID(pk.AreaClass=="major"&pk.AreaRelativeError>at));
    flags=appendTrialKeys(flags,"minor peak fraction",key, ...
        pk.TrialID(pk.AreaClass~="major"&pk.FractionAbsError_pp>ft));
    flags=appendTrialKeys(flags,"F/C",key, ...
        cp.TrialID(cp.TrueF_over_C>0&cp.FCRelativeError>rt));
    flags=appendTrialKeys(flags,"F-at.%",key,cp.TrialID(cp.FAtAbsError_pp>fat));
    if tier=="A"
        truth=tr.OverallTruthAcceptable_A;
    else
        truth=tr.OverallTruthAcceptable_B;
    end
    flags=appendTrialKeys(flags,"false-valid",key, ...
        tr.TrialID(~truth&tr.DeployableOverallQCValid));
    flags=appendTrialKeys(flags,"false-invalid",key, ...
        tr.TrialID(truth&~tr.DeployableOverallQCValid));
end
flags("misclassification")=s.trialMetrics.CellKey(s.trialMetrics.FamilyID==13)+":"+ ...
    string(s.trialMetrics.TrialID(s.trialMetrics.FamilyID==13));
flags("withholding")=s.trialMetrics.CellKey(s.trialMetrics.CompositionWithheld)+":"+ ...
    string(s.trialMetrics.TrialID(s.trialMetrics.CompositionWithheld));
bound=s.pairMetrics(startsWith(s.pairMetrics.CellKey,"F15_"),:);
flags("bound sensitivity")=bound.CellKey+":"+string(bound.TrialID);
flags("convergence")=s.trialMetrics.CellKey(~s.trialMetrics.TrialConverged)+":"+ ...
    string(s.trialMetrics.TrialID(~s.trialMetrics.TrialConverged));
for i=1:n
    TrialCount(i)=numel(unique(flags(char(labels(i)))));
    if ismember(labels(i),["misclassification","bound sensitivity"])
        Denominator(i)=TrialCount(i);
    elseif labels(i)=="convergence"||labels(i)=="withholding"
        Denominator(i)=height(s.trialMetrics);
    else
        Denominator(i)=sum(P.FinalN(assignedTier(P.Gate)~=""));
    end
end
CategoryType=repmat("frozen gate criterion",n,1);
CategoryType(labels=="misclassification")="safety stress outcome";
CategoryType(labels=="withholding")="availability / protective behavior";
CategoryType(labels=="bound sensitivity")="paired sensitivity criterion";
CategoryType(labels=="convergence")="optimizer outcome";
Interpretation=repmat("Trials outside the frozen truth-accuracy criterion; categories can overlap.",n,1);
Interpretation(labels=="misclassification")= ...
    "Dangerously accepted label-mutated trials (all 400 injected trials were withheld, so the count is zero).";
Interpretation(labels=="withholding")= ...
    "Composition outputs withheld by QC; this may be protective rather than a scientific failure.";
Interpretation(labels=="bound sensitivity")= ...
    "Paired bound-sensitivity trials evaluated; all three bound-sensitivity cells failed their paired criterion.";
Interpretation(labels=="convergence")= ...
    "Trials with a non-positive required regional optimizer exit flag.";
% The label-misclassification row counts dangerous acceptance, not the
% number of deliberately injected label mutations.
idx=labels=="misclassification";
TrialCount(idx)=sum(P.DangerousLabelAcceptanceRate(P.FamilyID==13).*P.FinalN(P.FamilyID==13),"omitnan");
Denominator(idx)=sum(P.FinalN(P.FamilyID==13));
T=table(labels,CategoryType,CellCount,TrialCount,Denominator,Interpretation, ...
    VariableNames=["FailureCategory","CategoryType","FailingCellCount", ...
    "AffectedTrialCount","ApplicableTrialDenominator","Interpretation"]);
end

function flags=appendTrialKeys(flags,label,key,ids)
if isempty(ids),return;end
old=flags(label);flags(label)=[old;key+":"+string(unique(ids))];
end

function T=buildModelComparison(P)
models=["ruoff_c1s_main_cf_v1";"ruoff_c1s_f1s_semi_sf3p95_v1"];
prefix=["Model1";"Model2"];n=2;QuantitativeABCells=zeros(n,1);
ABMeetsAssignedLimits=zeros(n,1);ABFailsAssignedLimits=zeros(n,1);ABWithheldCells=zeros(n,1);
CCells=zeros(n,1);CMeetsTierBLimits=zeros(n,1);CFailsTierBLimits=zeros(n,1);CWithheldCells=zeros(n,1);
WorstMedianFCError_rel=zeros(n,1);WorstP95FCError_rel=zeros(n,1);
WorstMedianFAtError_pp=zeros(n,1);WorstP95FAtError_pp=zeros(n,1);
for i=1:n
    assess=P.(prefix(i)+"ThresholdAssessment");
    ab=ismember(P.Gate,["A","A_paired","B","B_paired"]);c=P.Gate=="C";
    QuantitativeABCells(i)=nnz(ab);ABMeetsAssignedLimits(i)=nnz(ab&assess=="meets_assigned_composition_limits");
    ABFailsAssignedLimits(i)=nnz(ab&assess=="fails_assigned_composition_limits");
    ABWithheldCells(i)=nnz(ab&assess=="withheld");
    CCells(i)=nnz(c);CMeetsTierBLimits(i)=nnz(c&assess=="meets_assigned_composition_limits");
    CFailsTierBLimits(i)=nnz(c&assess=="fails_assigned_composition_limits");
    CWithheldCells(i)=nnz(c&assess=="withheld");
    WorstMedianFCError_rel(i)=max(P.(prefix(i)+"MedianFCError_rel")(ab),[],"omitnan");
    WorstP95FCError_rel(i)=max(P.(prefix(i)+"P95FCError_rel")(ab),[],"omitnan");
    WorstMedianFAtError_pp(i)=max(P.(prefix(i)+"MedianFAtAbsError_pp")(ab),[],"omitnan");
    WorstP95FAtError_pp(i)=max(P.(prefix(i)+"P95FAtAbsError_pp")(ab),[],"omitnan");
end
T=table(models,QuantitativeABCells,ABMeetsAssignedLimits,ABFailsAssignedLimits, ...
    ABWithheldCells,CCells,CMeetsTierBLimits,CFailsTierBLimits,CWithheldCells, ...
    WorstMedianFCError_rel,WorstP95FCError_rel, ...
    WorstMedianFAtError_pp,WorstP95FAtError_pp,VariableNames=["ModelID", ...
    "QuantitativeABCells","ABMeetsAssignedLimits","ABFailsAssignedLimits", ...
    "ABWithheldCells","CCells","CMeetsTierBLimits","CFailsTierBLimits", ...
    "CWithheldCells","WorstMedianFCError_rel","WorstP95FCError_rel", ...
    "WorstMedianFAtError_pp","WorstP95FAtError_pp"]);
end

function T=buildRecommendations
Issue=["Peak shape";"Background selection";"Center/FWHM bounds"; ...
    "Charging correction";"F1s positional classification"; ...
    "Substrate/interface fluorine";"Acquisition scaling";"Multi-start fitting"];
Evidence=["Families 6 and 16 show Gaussian recovery degrades as pseudo-Voigt mixing increases."; ...
    "Family 7 separates matched and mismatched background behavior; AsLS and curved/mismatched cases require scrutiny."; ...
    "Family 15 shows fitted results depend on permitted center/FWHM ranges."; ...
    "Family 10 shows common binding-energy shifts affect peak recovery and Model 2 classification/withholding."; ...
    "Families 10 and 13 show the strict semi-covalent positional/label rule is consequential."; ...
    "Families 5 and 14 test F_other, substrate peaks, and shoulders; some cases are dangerous false-valids."; ...
    "Families 9 and 11 show numerical normalization invariance but physical acquisition-factor errors propagate to cross-region composition."; ...
    "Family 2 compares one, five, and ten starts; use the evidence before choosing A/B development settings."];
RecommendedABInvestigation=["Compare Gaussian and pseudo-Voigt residual/area stability without choosing on Sample C."; ...
    "Compare physically plausible Linear/Shirley/Tougaard treatments and residual structure; do not rank across background families by AICc/BIC."; ...
    "Review recurring exact/near-bound components and test predeclared alternate bounds on Samples A/B only."; ...
    "Evaluate a common energy-reference correction before F1s positional classification."; ...
    "Audit the 686.7-686.9 eV rule after charging correction and retain withholding when classification is ambiguous."; ...
    "Inspect Sample A/B F1s for 681.3-681.6 eV interface F and 684/685.8 eV substrate/shoulder structure."; ...
    "Recover acquisition metadata before using cross-region F/C; do not infer unity scaling."; ...
    "Use multi-start only if it improves recovery/robustness rather than residual alone."];
T=table(Issue,Evidence,RecommendedABInvestigation);
end

function T=extractChargingTrials(s)
idx=s.trialIndex(ismember(s.trialIndex.CellKey,["F10_G1","F10_G2"]),:);
C=s.compositionMetrics;rows=cell(height(idx),1);
for i=1:height(idx)
    v=load(idx.CheckpointPath(i),"payload");p=v.payload;
    c=C(C.CellKey==idx.CellKey(i)&C.TrialID==idx.TrialID(i)& ...
        C.ModelPath=="primary.c1s_f1s_semi",:);
    rows{i}=struct("CellKey",idx.CellKey(i),"TrialID",idx.TrialID(i), ...
        "ChargingShift_eV",p.charging_shift_eV, ...
        "Model2FCError_rel",c.FCRelativeError, ...
        "Model2FAtAbsError_pp",c.FAtAbsError_pp, ...
        "Model2Finite",c.ActualFinite,"Model2Valid",c.ActualValid, ...
        "Model2Withheld",~c.ActualFinite);
end
T=struct2table(vertcat(rows{:}));
end

function plotErrorVsSNR(P,folder)
one=P(P.FamilyID==1,:);x=[100;50;20];
f=figure("Visible","off","Color","w");
tiledlayout(1,2,"Padding","compact","TileSpacing","compact");
nexttile;plot(x,100*one.Model1MedianFCError_rel,"-o","LineWidth",1.5);hold on;
plot(x,100*one.Model2MedianFCError_rel,"-s","LineWidth",1.5);set(gca,"XDir","reverse");
xlabel("PeakSNR");ylabel("Median F/C relative error (%)");legend("Model 1","Model 2","Location","northwest");grid on;
nexttile;plot(x,one.CenterP95WorstPeak_eV,"-o","LineWidth",1.5);hold on;
plot(x,100*one.FWHMP95WorstPeak_rel,"-s","LineWidth",1.5);set(gca,"XDir","reverse");
xlabel("PeakSNR");ylabel("Worst-peak 95th percentile");legend("Center error (eV)","FWHM error (%)","Location","northwest");grid on;
sgtitle("Noise sensitivity");exportgraphics(f,fullfile(folder,"error_vs_snr.png"),"Resolution",180);close(f);
end

function plotOverlap(P,folder)
one=P(P.FamilyID==4,:);categories=categorical(one.CellKey,one.CellKey);
f=figure("Visible","off","Color","w");tiledlayout(1,2,"Padding","compact");
nexttile;bar(categories,[100*one.MajorAreaP95WorstPeak_rel,one.MinorFractionP95WorstPeak_pp]);
ylabel("95th-percentile error");legend("Major area (%)","Minor fraction (pp)");title("Peak recovery");grid on;
nexttile;bar(categories,[one.Model1P95FAtAbsError_pp,one.Model2P95FAtAbsError_pp]);
ylabel("F-at.% absolute error (pp)");legend("Model 1","Model 2");title("Composition recovery");grid on;
sgtitle("Overlap and broadening");exportgraphics(f,fullfile(folder,"overlap_fwhm_vs_error.png"),"Resolution",180);close(f);
end

function plotPeakShape(P,folder)
one=P(P.FamilyID==6,:);eta=[.2;.5;.8];f=figure("Visible","off","Color","w");
plot(eta,one.Model1P95FAtAbsError_pp,"-o","LineWidth",1.5);hold on;
plot(eta,one.Model2P95FAtAbsError_pp,"-s","LineWidth",1.5);
xlabel("Pseudo-Voigt mixing eta");ylabel("95th-percentile F-at.% error (pp)");
legend("Model 1","Model 2","Location","northwest");grid on;title("Gaussian fit to pseudo-Voigt truth");
exportgraphics(f,fullfile(folder,"pseudo_voigt_vs_composition_error.png"),"Resolution",180);close(f);
end

function plotBackground(P,folder)
one=P(P.FamilyID==7,:);categories=categorical(one.CellKey,one.CellKey);
f=figure("Visible","off","Color","w");tiledlayout(1,2,"Padding","compact");
nexttile;bar(categories,[100*one.MajorAreaP95WorstPeak_rel,one.MinorFractionP95WorstPeak_pp]);
ylabel("95th-percentile error");legend("Major area (%)","Minor fraction (pp)");title("Peak-area stability");grid on;
nexttile;bar(categories,[one.Model1P95FAtAbsError_pp,one.Model2P95FAtAbsError_pp]);
ylabel("95th-percentile F-at.% error (pp)");legend("Model 1","Model 2");title("Composition stability");grid on;
sgtitle("Background generation and recovery");exportgraphics(f,fullfile(folder,"background_stability.png"),"Resolution",180);close(f);
end

function plotTruncation(P,folder)
one=P(P.FamilyID==8,:);amount=zeros(height(one),1);edge=strings(height(one),1);
for i=1:height(one)
    token=regexp(one.CellKey(i),'F08_T_(low|high|both)_([0-9.]+)','tokens','once');
    edge(i)=token{1};amount(i)=str2double(token{2});
end
f=figure("Visible","off","Color","w");
for e=["low","high","both"]
    use=edge==e;plot(amount(use),one.Model2P95FAtAbsError_pp(use),"-o","LineWidth",1.5,"DisplayName",e);hold on;
end
xlabel("Trim amount (eV)");ylabel("Model 2 95th-percentile F-at.% error (pp)");legend("Location","best");grid on;
title("Window truncation");exportgraphics(f,fullfile(folder,"truncation_vs_error.png"),"Resolution",180);close(f);
end

function plotCharging(T,folder)
f=figure("Visible","off","Color","w");
finite=T.Model2Finite;scatter(T.ChargingShift_eV(finite),T.Model2FAtAbsError_pp(finite),14,"filled");hold on;
scatter(T.ChargingShift_eV(~finite),zeros(nnz(~finite),1),20,"x","LineWidth",1.2);
xlabel("Injected common shift (eV)");ylabel("Model 2 F-at.% error (pp)");
legend("Quantified","Withheld (shown at zero)","Location","best");grid on;title("Charging shift and Model 2 behavior");
exportgraphics(f,fullfile(folder,"charging_shift_vs_model2.png"),"Resolution",180);close(f);
end

function plotSensitivity(T,folder)
f=figure("Visible","off","Color","w");
for base=unique(T.BaseProfile,"stable").'
    one=T(T.BaseProfile==base,:);plot(one.AppliedS_F,one.MedianRetrievedFAt_pct,"-o", ...
        "LineWidth",1.5,"DisplayName",base);hold on;
end
xlabel("Applied S_F");ylabel("Retrieved F (at.%)");legend("Location","best","Interpreter","none");grid on;
title("Sensitivity-factor sweep");exportgraphics(f,fullfile(folder,"sensitivity_factor_vs_fat.png"),"Resolution",180);close(f);
end

function plotBounds(s,P,folder)
one=P(P.FamilyID==15,:);pair=s.pairMetrics(startsWith(s.pairMetrics.CellKey,"F15_"),:);
keys=one.CellKey;p95=zeros(numel(keys),1);
for i=1:numel(keys),p95(i)=p95Finite(pair.MaxCompositionRelativeDifference(pair.CellKey==keys(i)));end
f=figure("Visible","off","Color","w");categories=categorical(keys,keys);
yyaxis left;bar(categories,100*p95);ylabel("95th-percentile composition change (%)");
yyaxis right;plot(categories,100*one.ExactBoundRate,"-o","LineWidth",1.5);ylabel("Exact-bound trials (%)");
grid on;title("Bound sensitivity");exportgraphics(f,fullfile(folder,"bound_sensitivity.png"),"Resolution",180);close(f);
end

function plotFalseRates(T,folder)
f=figure("Visible","off","Color","w");
x=categorical(string(T.FamilyID),string(T.FamilyID));
bar(x,100*[T.MaximumFalseValidRate,T.MaximumFalseInvalidRate]);
xlabel("Stress family");ylabel("Maximum cell rate (%)");legend("False-valid","False-invalid","Location","northwest");
grid on;title("Deployable QC classification rates by family");
exportgraphics(f,fullfile(folder,"false_valid_false_invalid_by_family.png"),"Resolution",180);close(f);
end

function tier=assignedTier(gate)
gate=string(gate);tier=strings(size(gate));
tier(ismember(gate,["A","A_paired"]))="A";
tier(ismember(gate,["B","B_paired","C"]))="B";
end

function value=medianFinite(x)
x=x(isfinite(x));if isempty(x),value=NaN;else,value=median(x);end
end
function value=p95Finite(x)
x=x(isfinite(x));if isempty(x),value=NaN;else,value=prctile(x,95);end
end

function s=cellTemplate
s=struct("FamilyID",0,"FamilyName","","CellKey","","Scenario","", ...
    "FinalN",0,"Gate","","GateStatus","","ConvergenceRate",NaN, ...
    "C1sMedianRMSE",NaN,"C1sMedianR2",NaN,"C1sP95AbsResidualRho1",NaN, ...
    "F1sMedianRMSE",NaN,"F1sMedianR2",NaN,"F1sP95AbsResidualRho1",NaN, ...
    "CenterMedianWorstPeak_eV",NaN,"CenterP95WorstPeak_eV",NaN, ...
    "FWHMMedianWorstPeak_rel",NaN,"FWHMP95WorstPeak_rel",NaN, ...
    "MajorAreaMedianWorstPeak_rel",NaN,"MajorAreaP95WorstPeak_rel",NaN, ...
    "MinorFractionMedianWorstPeak_pp",NaN,"MinorFractionP95WorstPeak_pp",NaN, ...
    "Model1MedianFC",NaN,"Model1MedianFCError_rel",NaN,"Model1P95FCError_rel",NaN, ...
    "Model1MedianFAtAbsError_pp",NaN,"Model1P95FAtAbsError_pp",NaN,"Model1WithheldRate",NaN, ...
    "Model2MedianFC",NaN,"Model2MedianFCError_rel",NaN,"Model2P95FCError_rel",NaN, ...
    "Model2MedianFAtAbsError_pp",NaN,"Model2P95FAtAbsError_pp",NaN,"Model2WithheldRate",NaN, ...
    "AnyCompositionWithheldRate",NaN,"ExactBoundRate",NaN,"NearBoundRate",NaN, ...
    "PeakFalseValidRate",NaN,"CompositionFalseValidRate",NaN, ...
    "OverallFalseValidRate",NaN,"PeakFalseInvalidRate",NaN, ...
    "CompositionFalseInvalidRate",NaN,"OverallFalseInvalidRate",NaN, ...
    "MaxDimensionFalseValidRate",NaN,"MaxDimensionFalseInvalidRate",NaN, ...
    "InjectedLabelMisclassificationRate",NaN,"DangerousLabelAcceptanceRate",NaN, ...
    "PrimaryFailureReasons","","PeakDistributionPass",false, ...
    "CompositionDistributionPass",false,"Model1ThresholdAssessment","", ...
    "Model2ThresholdAssessment","");
end

function s=familyTemplate
s=struct("FamilyID",0,"FamilyName","","CellIDs","","Scenarios","", ...
    "FinalN","","AssignedGates","","PassCells",0,"FailCells",0, ...
    "DescriptiveCells",0,"MinimumConvergenceRate",NaN, ...
    "WorstCenterP95_eV",NaN,"WorstFWHMP95_rel",NaN, ...
    "WorstMajorAreaP95_rel",NaN,"WorstMinorFractionP95_pp",NaN, ...
    "WorstModel1FCP95_rel",NaN,"WorstModel1FAtP95_pp",NaN, ...
    "WorstModel2FCP95_rel",NaN,"WorstModel2FAtP95_pp",NaN, ...
    "MaximumModel2WithheldRate",NaN,"MaximumFalseValidRate",NaN, ...
    "MaximumFalseInvalidRate",NaN,"MaximumExactBoundRate",NaN, ...
    "MaximumNearBoundRate",NaN,"PrimaryFailureReasons","");
end

function assertSeparate(output,source)
out=lower(string(char(java.io.File(output).getCanonicalPath())));
src=lower(string(char(java.io.File(source).getCanonicalPath())));
if out==src||startsWith(out,src+string(filesep))
    error("generatePhase0HScientificTables:ImmutableSource", ...
        "Conclusions output must be outside the frozen source folder.");
end
end
function tf=folderHasEntries(folder)
if ~isfolder(folder),tf=false;return;end
items=dir(folder);names=string({items.name});tf=any(names~="."&names~="..");
end
