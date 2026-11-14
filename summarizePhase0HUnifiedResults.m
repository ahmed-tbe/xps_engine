function out = summarizePhase0HUnifiedResults(plan,trialTable,peakTable,compositionTable,pairTable)
%SUMMARIZEUNIFIEDRESULTS Apply the frozen Phase 0H v1.0.0 gates.
%
% Peak distributions are grouped by Region + PeakID. No peak IDs are
% pooled. AICc/BIC remain recorded trial diagnostics and are never used to
% rank different preprocessing/background families.

cellRows=cell(numel(plan.cells),1); rateRows={}; peakMetricRows={};
compositionMetricRows={};
for i=1:numel(plan.cells)
    c=plan.cells(i); use=trialTable.CellKey==string(c.cell_key);
    T=trialTable(use,:); P=peakTable(peakTable.CellKey==string(c.cell_key),:);
    C=compositionTable(compositionTable.CellKey==string(c.cell_key),:);
    Q=pairTable(pairTable.CellKey==string(c.cell_key),:);

    row=cellTemplate(); row.FamilyID=c.family_id; row.FamilyName=string(c.family_name);
    row.CellKey=string(c.cell_key); row.Gate=string(c.gate);
    row.NPlanned=c.trials; row.NUsable=nnz(~T.ExecutionError);
    row.NExecutionError=nnz(T.ExecutionError); row.NConverged=nnz(T.TrialConverged);
    conv=rateRecord(row.CellKey,"Convergence","Observed","none", ...
        row.NConverged,height(T));
    row.ConvergenceRate=conv.ObservedRate; row.ConvergenceWilsonLower=conv.WilsonLower;
    row.ConvergenceWilsonUpper=conv.WilsonUpper;
    row.NNonconverged=height(T)-row.NConverged;
    row.NCompositionWithheld=nnz(T.CompositionWithheld);
    row.NQCInvalid=nnz(~T.DeployableOverallQCValid);
    exact=rateRecord(row.CellKey,"ExactBoundHit","Observed","none", ...
        nnz(T.ExactBoundHit),height(T));
    row.ExactBoundRate=exact.ObservedRate;
    row.ExactBoundWilsonLower=exact.WilsonLower;
    row.ExactBoundWilsonUpper=exact.WilsonUpper;
    sources=unique(T.SourceRunID); fingerprints=unique(T.SourceExecutionFingerprint);
    row.SourceRunID=strjoin(sources,";");
    row.SourceExecutionFingerprint=strjoin(fingerprints,";");

    dimensions=["Peak","Composition","Overall"];
    qctypes=["Deployable","SyntheticDiagnostic"];
    tiers=["A","B"];
    for qc=qctypes
        for tier=tiers
            for dimension=dimensions
                [app,truth,valid]=classificationVectors(T,dimension,tier,qc);
                fv=rateRecord(row.CellKey,dimension,qc,tier, ...
                    nnz(app & ~truth & valid),nnz(app & ~truth),"FalseValid");
                fi=rateRecord(row.CellKey,dimension,qc,tier, ...
                    nnz(app & truth & ~valid),nnz(app & truth),"FalseInvalid");
                rateRows{end+1,1}=fv; rateRows{end+1,1}=fi; %#ok<AGROW>
            end
        end
    end

    tier=gateTier(c.gate);
    if tier~=""
        [row.PeakDistributionPass,newRows]=peakDistribution(P,row.CellKey,tier);
        peakMetricRows=[peakMetricRows;newRows]; %#ok<AGROW>
        [row.CompositionDistributionPass,newRows]=compositionDistribution(C,row.CellKey,tier);
        compositionMetricRows=[compositionMetricRows;newRows]; %#ok<AGROW>
    end

    [row.GateStatus,row.GatePass,row.PairCriterionPass,row.ScaleCriterionPass]= ...
        applyGate(c,T,P,C,Q,row);
    [row.ExtensionRecommended,row.ExtensionReasons]=extensionDecision(c,T,Q);
    cellRows{i}=row;
end

out.cellSummary=struct2table(vertcat(cellRows{:}));
out.rateSummary=struct2table(vertcat(rateRows{:}));
if isempty(peakMetricRows),out.peakMetricSummary=table();
else,out.peakMetricSummary=struct2table(vertcat(peakMetricRows{:}));end
if isempty(compositionMetricRows),out.compositionMetricSummary=table();
else,out.compositionMetricSummary=struct2table(vertcat(compositionMetricRows{:}));end
out.extensionCells=out.cellSummary(out.cellSummary.ExtensionRecommended, ...
    ["FamilyID","FamilyName","CellKey","Gate","GateStatus","ExtensionReasons"]);
end

function [status,pass,pairPass,scalePass]=applyGate(c,T,P,C,Q,row)
gate=string(c.gate); pairPass=true;scalePass=true;
if row.NUsable~=row.NPlanned
    status="incomplete";pass=false;return
end
if gate=="C_descriptive"
    status="descriptive_no_acceptance_gate";pass=NaN;return
end
if gate=="Order"
    pairPass=height(Q)==height(T) && all(Q.Applicable) && ...
        all(Q.MaxCenterDifference_eV<=1e-6) && ...
        all(Q.MaxAreaRelativeDifference<=1e-6) && ...
        all(Q.MaxCompositionRelativeDifference<=1e-6);
    pass=row.NExecutionError==0 && all(T.TrialConverged) && pairPass;
    status=passStatus(pass);return
end
if gate=="Scale"
    if c.cell_key=="F09_Q3"
        scalePass=all(T.CrossRegionWithheld);
    elseif c.family_id==12
        app=C.GateApplicable;
        scalePass=all(C.ActualFinite(app)) && all(C.FCRelativeError(app)<=1e-6 | ...
            (isnan(C.FCRelativeError(app)) & C.FCAbsoluteError(app)<=eps));
    else
        pp=P.TruthPresent & P.FitPresent & P.TruthArea>0;
        cc=C.GateApplicable & C.CrossRegion;
        scalePass=all(P.AreaRelativeError(pp)<=1e-6) && ...
            all(C.FCRelativeError(cc)<=1e-6);
    end
    pass=row.NExecutionError==0 && all(T.TrialConverged) && scalePass;
    status=passStatus(pass);return
end
if gate=="C"
    fvPass=true;
    for dimension=["Peak","Composition","Overall"]
        [app,truth,valid]=classificationVectors(T,dimension,"B","Deployable");
        n=nnz(app & ~truth);k=nnz(app & ~truth & valid);
        if n>0,fvPass=fvPass && k/n<=.05;end
    end
    pass=row.NExecutionError==0 && fvPass;
    status=passStatus(pass);return
end

tier=gateTier(gate);
if tier~=""
    convergenceThreshold=.95;falseInvalidThreshold=.05;
    if tier=="B",convergenceThreshold=.90;falseInvalidThreshold=.10;end
    fiPass=true;
    for dimension=["Peak","Composition","Overall"]
        [app,truth,valid]=classificationVectors(T,dimension,tier,"Deployable");
        n=nnz(app & truth);k=nnz(app & truth & ~valid);
        if n>0,fiPass=fiPass && k/n<=falseInvalidThreshold;end
    end
    if c.cell_key=="F03_O2"
        success=Q.MaxFAtDifference_pp<=.01 & ...
            Q.MaxComponentFractionDifference_pp<=.05;
        pairPass=height(Q)==height(T) && nnz(success)/height(T)>=.95;
    end
    pass=row.NExecutionError==0 && row.ConvergenceRate>=convergenceThreshold && ...
        row.PeakDistributionPass && row.CompositionDistributionPass && ...
        fiPass && pairPass;
    status=passStatus(pass);return
end
status="unrecognized_gate";pass=false;
end

function [recommended,reasons]=extensionDecision(c,T,Q)
gate=string(c.gate); reasons=strings(0,1);
tier=gateTier(gate);
if tier~=""
    convThreshold=.95;rateThreshold=.05;
    if tier=="B",convThreshold=.90;rateThreshold=.10;end
    w=xpsh.wilsonInterval(nnz(T.TrialConverged),height(T));
    if crosses(w,convThreshold),reasons(end+1)="convergence";end %#ok<AGROW>
    for dimension=["Peak","Composition","Overall"]
        [app,truth,valid]=classificationVectors(T,dimension,tier,"Deployable");
        n=nnz(app & truth);k=nnz(app & truth & ~valid);
        if n>0
            w=xpsh.wilsonInterval(k,n);
            if crosses(w,rateThreshold)
                reasons(end+1)=dimension+" deployable false-invalid"; %#ok<AGROW>
            end
        end
    end
    if c.cell_key=="F03_O2"
        success=Q.MaxFAtDifference_pp<=.01 & ...
            Q.MaxComponentFractionDifference_pp<=.05;
        w=xpsh.wilsonInterval(nnz(success),height(Q));
        if crosses(w,.95),reasons(end+1)="paired-order success";end %#ok<AGROW>
    end
elseif gate=="C"
    for dimension=["Peak","Composition","Overall"]
        [app,truth,valid]=classificationVectors(T,dimension,"B","Deployable");
        n=nnz(app & ~truth);k=nnz(app & ~truth & valid);
        if n>0
            w=xpsh.wilsonInterval(k,n);
            if crosses(w,.05)
                reasons(end+1)=dimension+" deployable false-valid"; %#ok<AGROW>
            end
        end
    end
end
recommended=~isempty(reasons);reasons=strjoin(unique(reasons,"stable"),"; ");
end

function [pass,rows]=peakDistribution(P,cellKey,tier)
rows={};pass=true;if isempty(P),return;end
groups=unique(P(:,["Region","PeakID"]),"rows","stable");
for i=1:height(groups)
    use=P.Region==groups.Region(i)&P.PeakID==groups.PeakID(i);
    one=P(use,:); positive=one.TruthPresent & one.TruthArea>0;
    if any(positive)
        [pass,rows]=addMetric(pass,rows,cellKey,groups.Region(i), ...
            groups.PeakID(i),"CenterAbsError_eV",one.CenterAbsError_eV(positive), ...
            nnz(positive),tier,centerThreshold(tier));
        [pass,rows]=addMetric(pass,rows,cellKey,groups.Region(i), ...
            groups.PeakID(i),"FWHMRelativeError",one.FWHMRelativeError(positive), ...
            nnz(positive),tier,widthThreshold(tier));
    end
    major=one.AreaClass=="major";
    if any(major)
        [pass,rows]=addMetric(pass,rows,cellKey,groups.Region(i), ...
            groups.PeakID(i),"AreaRelativeError",one.AreaRelativeError(major), ...
            nnz(major),tier,areaThreshold(tier));
    else
        [pass,rows]=addMetric(pass,rows,cellKey,groups.Region(i), ...
            groups.PeakID(i),"FractionAbsError_pp",one.FractionAbsError_pp, ...
            height(one),tier,fractionThreshold(tier));
    end
end
end

function [pass,rows]=compositionDistribution(C,cellKey,tier)
rows={};pass=true;if isempty(C),return;end
models=unique(C.ModelPath(C.GateApplicable),"stable");
for model=models(:).'
    one=C(C.ModelPath==model & C.GateApplicable,:);
    if isempty(one),continue;end
    [pass,rows]=addCompMetric(pass,rows,cellKey,model,"FCRelativeError", ...
        one.FCRelativeError,height(one),tier,ratioThreshold(tier));
    [pass,rows]=addCompMetric(pass,rows,cellKey,model,"CFRelativeError", ...
        one.CFRelativeError,height(one),tier,ratioThreshold(tier));
    [pass,rows]=addCompMetric(pass,rows,cellKey,model,"FAtAbsError_pp", ...
        one.FAtAbsError_pp,height(one),tier,fatThreshold(tier));
end
end

function [pass,rows]=addMetric(pass,rows,cellKey,region,peakID,metric,values,n,tier,threshold)
s=xpsh.summarizeValues(values);ok=s.finite_count==n && ...
    s.median<=threshold(1)&&s.p95<=threshold(2);pass=pass&&ok;
rows{end+1,1}=metricTemplate(cellKey,region,peakID,metric,n,tier,threshold,s,ok); %#ok<AGROW>
end
function [pass,rows]=addCompMetric(pass,rows,cellKey,model,metric,values,n,tier,threshold)
s=xpsh.summarizeValues(values);ok=s.finite_count==n && ...
    s.median<=threshold(1)&&s.p95<=threshold(2);pass=pass&&ok;
r=compositionMetricTemplate();r.CellKey=cellKey;r.ModelPath=model;r.Metric=metric;
r.NExpected=n;r.NFinite=s.finite_count;r.Tier=tier;r.Median=s.median;r.P95=s.p95;
r.Worst=s.worst;r.MedianThreshold=threshold(1);r.P95Threshold=threshold(2);r.Pass=ok;
rows{end+1,1}=r; %#ok<AGROW>
end

function [app,truth,valid]=classificationVectors(T,dimension,tier,qc)
if dimension=="Peak",app=T.PeakApplicable;
elseif dimension=="Composition",app=T.CompositionApplicable;
else,app=T.PeakApplicable|T.CompositionApplicable;end
truth=T.(dimension+"TruthAcceptable_"+tier);
if qc=="Deployable",valid=T.("Deployable"+dimension+"QCValid");
else,valid=T.("SyntheticDiagnostic"+dimension+"QCValid");end
end

function tier=gateTier(gate)
gate=string(gate);
if ismember(gate,["A","A_paired"]),tier="A";
elseif ismember(gate,["B","B_paired"]),tier="B";
else,tier="";end
end
function t=centerThreshold(tier),if tier=="A",t=[.05,.15];else,t=[.10,.30];end,end
function t=widthThreshold(tier),if tier=="A",t=[.10,.25];else,t=[.20,.50];end,end
function t=areaThreshold(tier),if tier=="A",t=[.05,.15];else,t=[.10,.30];end,end
function t=fractionThreshold(tier),if tier=="A",t=[.5,1.5];else,t=[1,3];end,end
function t=ratioThreshold(tier),if tier=="A",t=[.03,.10];else,t=[.05,.15];end,end
function t=fatThreshold(tier),if tier=="A",t=[1,3];else,t=[1.5,5];end,end
function tf=crosses(w,x),tf=w.lower<=x&&w.upper>=x;end
function s=passStatus(tf),if tf,s="pass";else,s="fail";end,end

function r=rateRecord(cellKey,dimension,qc,tier,k,n,kind)
if nargin<7,kind="Rate";end
r=rateTemplate();r.CellKey=cellKey;r.Dimension=dimension;r.QCType=qc;
r.TruthTier=tier;r.RateType=kind;r.Events=k;r.Denominator=n;
if n>0
    w=xpsh.wilsonInterval(k,n);r.ObservedRate=w.observed_rate;
    r.WilsonLower=w.lower;r.WilsonUpper=w.upper;
end
end
function r=metricTemplate(cellKey,region,peakID,metric,n,tier,threshold,s,ok)
r=peakMetricTemplate();r.CellKey=cellKey;r.Region=region;r.PeakID=peakID;
r.Metric=metric;r.NExpected=n;r.NFinite=s.finite_count;r.Tier=tier;
r.Median=s.median;r.P95=s.p95;r.Worst=s.worst;
r.MedianThreshold=threshold(1);r.P95Threshold=threshold(2);r.Pass=ok;
end

function s=cellTemplate
s=struct("FamilyID",0,"FamilyName","","CellKey","","Gate","", ...
    "SourceRunID","","SourceExecutionFingerprint","","NPlanned",0, ...
    "NUsable",0,"NExecutionError",0,"NConverged",0,"NNonconverged",0, ...
    "ConvergenceRate",NaN,"ConvergenceWilsonLower",NaN, ...
    "ConvergenceWilsonUpper",NaN,"NCompositionWithheld",0,"NQCInvalid",0, ...
    "ExactBoundRate",NaN,"ExactBoundWilsonLower",NaN,"ExactBoundWilsonUpper",NaN, ...
    "PeakDistributionPass",true,"CompositionDistributionPass",true, ...
    "PairCriterionPass",true,"ScaleCriterionPass",true,"GateStatus","", ...
    "GatePass",NaN,"ExtensionRecommended",false,"ExtensionReasons","");
end
function s=rateTemplate
s=struct("CellKey","","Dimension","","QCType","","TruthTier","", ...
    "RateType","","Events",0,"Denominator",0,"ObservedRate",NaN, ...
    "WilsonLower",NaN,"WilsonUpper",NaN);
end
function s=peakMetricTemplate
s=struct("CellKey","","Region","","PeakID","","Metric","", ...
    "NExpected",0,"NFinite",0,"Tier","","Median",NaN,"P95",NaN, ...
    "Worst",NaN,"MedianThreshold",NaN,"P95Threshold",NaN,"Pass",false);
end
function s=compositionMetricTemplate
s=struct("CellKey","","ModelPath","","Metric","","NExpected",0, ...
    "NFinite",0,"Tier","","Median",NaN,"P95",NaN,"Worst",NaN, ...
    "MedianThreshold",NaN,"P95Threshold",NaN,"Pass",false);
end
