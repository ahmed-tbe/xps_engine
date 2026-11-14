function [trial,peakRows,compositionRows,pairRow] = analyzePhase0HUnifiedTrial( ...
        payload,cellDef,sourceRunID,sourceFingerprint)
%ANALYZEUNIFIEDTRIAL Derive frozen Phase 0H truth/QC metrics from one payload.
%
% This function is reporting-only. It does not regenerate a fixture, call an
% optimizer, or mutate a checkpoint. Truth composition is calculated from
% the stored physical truth areas and chemical identities, independently of
% fitted peak position/QC.

trial=trialTemplate();
trial.FamilyID=cellDef.family_id;
trial.FamilyName=string(cellDef.family_name);
trial.CellKey=string(cellDef.cell_key);
trial.Gate=string(cellDef.gate);
trial.TrialID=double(payload.trial_id);
trial.SourceRunID=string(sourceRunID);
trial.SourceExecutionFingerprint=string(sourceFingerprint);
trial.Status=string(fieldOr(payload,"status","missing"));
trial.ExecutionError=trial.Status=="error";
trial.TrialConverged=logical(fieldOr(payload,"trial_converged",false));
trial.OptimizerInvocations=double(fieldOr(payload,"optimizer_invocations",0));
trial.CompositionWithheld=false;
trial.CrossRegionExpected=logical(payload.scaling_truth_and_supplied.C1s_known && ...
    payload.scaling_truth_and_supplied.F1s_known);
trial.CrossRegionWithheld=false;

peakRows=repmat(peakTemplate(),0,1);
compositionRows=repmat(compositionTemplate(),0,1);
pairRow=pairTemplate();
pairRow.CellKey=trial.CellKey; pairRow.TrialID=trial.TrialID;

if trial.ExecutionError || ~isfield(payload,"variants") || isempty(payload.variants)
    return
end

primary=payload.variants(1);
trial=copyFitMetrics(trial,primary);
if isfield(primary,"C1s")
    peakRows=[peakRows; regionPeakRows(payload,primary,"C1s")]; %#ok<AGROW>
end
if isfield(primary,"F1s")
    peakRows=[peakRows; regionPeakRows(payload,primary,"F1s")]; %#ok<AGROW>
end
compositionRows=compositionMetrics(payload,primary);

[peakA,peakB]=truthLabelsForPeaks(peakRows);
[compositionA,compositionB]=truthLabelsForComposition(compositionRows);
trial.PeakApplicable=~isempty(peakRows);
trial.CompositionApplicable=~isempty(compositionRows);
trial.PeakTruthAcceptable_A=peakA;
trial.PeakTruthAcceptable_B=peakB;
trial.CompositionTruthAcceptable_A=compositionA;
trial.CompositionTruthAcceptable_B=compositionB;
trial.OverallTruthAcceptable_A=applicableAnd(trial.PeakApplicable,peakA, ...
    trial.CompositionApplicable,compositionA);
trial.OverallTruthAcceptable_B=applicableAnd(trial.PeakApplicable,peakB, ...
    trial.CompositionApplicable,compositionB);

[fitCommon,syntheticFitQC,exactBound,smallArea]=fitQC(payload,primary);
trial.ExactBoundHit=exactBound;
trial.SmallAreaWarning=smallArea;
trial.DeployablePeakQCValid=trial.PeakApplicable && fitCommon && ...
    ~exactBound && ~smallArea;
trial.SyntheticDiagnosticPeakQCValid=trial.DeployablePeakQCValid && syntheticFitQC;

gatedComposition=compositionRows([compositionRows.GateApplicable]);
compositionFinite=isempty(gatedComposition) || all([gatedComposition.ActualFinite]);
trial.CompositionWithheld=~compositionFinite;
trial.CrossRegionWithheld=crossRegionWithheld(compositionRows);
trial.DeployableCompositionQCValid=trial.CompositionApplicable && ...
    ~trial.ExecutionError && trial.TrialConverged && compositionFinite;
trial.SyntheticDiagnosticCompositionQCValid= ...
    trial.DeployableCompositionQCValid && (~trial.PeakApplicable || syntheticFitQC);
trial.DeployableOverallQCValid=applicableAnd(trial.PeakApplicable, ...
    trial.DeployablePeakQCValid,trial.CompositionApplicable, ...
    trial.DeployableCompositionQCValid);
trial.SyntheticDiagnosticOverallQCValid=applicableAnd(trial.PeakApplicable, ...
    trial.SyntheticDiagnosticPeakQCValid,trial.CompositionApplicable, ...
    trial.SyntheticDiagnosticCompositionQCValid);

if numel(payload.variants)>1
    pairRow=pairedMetrics(payload.variants(1),payload.variants(2),trial.CellKey,trial.TrialID);
end
end

function rows=regionPeakRows(payload,variant,region)
truth=payload.truth.(region).peaks;
fit=variant.(region).peaks;
truthIDs=string({truth.id}); fitIDs=string({fit.id});
ids=unique([truthIDs(:);fitIDs(:)],"stable");
truthTotal=sum([truth.physical_area]); fitTotal=sum([fit.area]);
multiplier=NaN;
if isfield(variant,"quantification_scaling") && ...
        isfield(variant.quantification_scaling,region)
    multiplier=double(variant.quantification_scaling.(region).physicalAreaMultiplier);
end
rows=repmat(peakTemplate(),numel(ids),1);
for i=1:numel(ids)
    id=ids(i); ti=find(truthIDs==id,1); fi=find(fitIDs==id,1);
    row=peakTemplate(); row.CellKey=string(payload.cell_key);
    row.TrialID=double(payload.trial_id); row.Region=region; row.PeakID=id;
    if ~isempty(ti)
        t=truth(ti); row.TruthPresent=true; row.TruthCenter_eV=t.center_eV;
        row.TruthFWHM_eV=t.FWHM_eV; row.TruthArea=t.physical_area;
        row.TruthFraction=100*t.physical_area/max(truthTotal,eps);
        row.TruthInFitModel=logical(t.in_fit_model);
        row.TrueFullAnalyticArea=t.true_full_analytic_area;
        row.TrueInWindowArea=t.true_in_window_area;
        row.TrueWindowContainmentFraction=t.true_window_containment_fraction;
        row.TrueSampledGridArea=t.true_sampled_grid_area;
    end
    if ~isempty(fi)
        f=fit(fi); row.FitPresent=true; row.FitCenter_eV=f.center_eV;
        row.FitFWHM_eV=f.FWHM_eV; row.FitArea=f.area*multiplier;
        row.FitFraction=100*f.area/max(fitTotal,eps);
        row.CenterAtBound=logical(f.center_at_bound);
        row.FWHMAtBound=logical(f.FWHM_at_bound);
        row.AreaAtBound=logical(f.area_at_bound);
        row.CenterNearBound=logical(f.center_near_bound);
        row.FWHMNearBound=logical(f.FWHM_near_bound);
        row.AreaNearBound=logical(f.area_near_bound);
    end
    row.ExactBoundHit=row.CenterAtBound||row.FWHMAtBound||row.AreaAtBound;
    row.NearBoundHit=row.CenterNearBound||row.FWHMNearBound||row.AreaNearBound;
    if row.TruthPresent && row.FitPresent
        row.MatchType="matched";
        row.CenterAbsError_eV=abs(row.FitCenter_eV-row.TruthCenter_eV);
        if row.TruthFWHM_eV>0
            row.FWHMRelativeError=abs(row.FitFWHM_eV-row.TruthFWHM_eV)/row.TruthFWHM_eV;
        end
        if row.TruthArea>0 && isfinite(row.FitArea)
            row.AreaRelativeError=abs(row.FitArea-row.TruthArea)/row.TruthArea;
        end
        row.FractionAbsError_pp=abs(row.FitFraction-row.TruthFraction);
    elseif row.TruthPresent
        row.MatchType="omitted_truth";
        row.FractionAbsError_pp=row.TruthFraction;
    else
        row.MatchType="extraneous_fit";
        row.FractionAbsError_pp=row.FitFraction;
    end
    if row.TruthPresent && row.TruthArea>0
        if row.TruthFraction>=5,row.AreaClass="major";else,row.AreaClass="minor";end
    else
        row.AreaClass="zero_or_unmatched";
    end
    rows(i)=row;
end
end

function rows=compositionMetrics(payload,variant)
truth=trueComposition(payload);
paths=["primary.c1s_main_cf","diagnostics.legacy_c1s", ...
    "diagnostics.weighted_c1s","primary.c1s_f1s_semi", ...
    "diagnostics.carbon_bound_f1s_previous","diagnostics.total_f1s"];
rows=repmat(compositionTemplate(),numel(paths),1);
for i=1:numel(paths)
    row=compositionTemplate(); row.CellKey=string(payload.cell_key);
    row.TrialID=double(payload.trial_id); row.ModelPath=paths(i);
    row.CrossRegion=i>=4; row.Applicable=~row.CrossRegion || truth.CrossApplicable;
    % The frozen v1.0.0 truth label explicitly gates weighted/legacy C1s
    % plus valid cross-region outputs. The newer primary main-CF result is
    % retained in reporting but is not retroactively added to that gate.
    row.GateApplicable=row.Applicable && i~=1;
    row.TrueF_over_C=truth.F_over_C(i);
    row.TrueF_atpct=truth.F_atpct(i); row.TrueC_over_F=truth.C_over_F(i);
    actual=getPath(fieldOr(variant,"composition",struct()),paths(i));
    if isstruct(actual) && isfield(actual,"F_over_C")
        row.ActualStatus=string(fieldOr(actual,"status",""));
        row.ActualF_over_C=double(actual.F_over_C);
        row.ActualF_atpct=double(fieldOr(actual,"F_atpct",NaN));
        row.ActualC_over_F=double(fieldOr(actual,"C_over_F",NaN));
        row.ActualValid=logical(fieldOr(actual,"valid",false));
    else
        row.ActualStatus="missing_or_withheld";
    end
    row.ActualFinite=~row.Applicable || (isfinite(row.ActualF_over_C) && ...
        isfinite(row.ActualF_atpct));
    if row.Applicable && row.ActualFinite
        if row.TrueF_over_C>0
            row.FCRelativeError=abs(row.ActualF_over_C-row.TrueF_over_C)/row.TrueF_over_C;
            row.CFRelativeError=abs(row.ActualC_over_F-row.TrueC_over_F)/row.TrueC_over_F;
        elseif row.TrueF_over_C==0
            row.FCAbsoluteError=abs(row.ActualF_over_C);
        end
        row.FAtAbsError_pp=abs(row.ActualF_atpct-row.TrueF_atpct);
    end
    rows(i)=row;
end
end

function out=trueComposition(payload)
c=payload.truth.C1s.peaks; f=payload.truth.F1s.peaks;
cIDs=string({c.id}); fIDs=string({f.id});
cArea=[c.physical_area]; fArea=[f.physical_area]; cTotal=sum(cArea);
area=@(id) sum(cArea(cIDs==id));
main=area("C_F")/cTotal;
legacy=((cTotal-area("sp2_C_C"))/cTotal)/3;
alpha=0;
if isfield(payload,"composition_model_profile") && ...
        isfield(payload.composition_model_profile,"alpha_ambiguous")
    alpha=payload.composition_model_profile.alpha_ambiguous;
end
weighted=(area("C_F")+alpha*area("C_CF23_C_O")+ ...
    2*area("CF2")+3*area("CF3"))/cTotal;
SC=payload.sensitivity_profile.S_C; SF=payload.sensitivity_profile.S_F;
if isfield(payload.sensitivity_profile,"base_profile_id") && ...
        isfield(payload.settings,"sensitivity_multiplier")
    % Family 12 perturbs the supplied sensitivity factor while holding the
    % underlying physical truth fixed at the declared base profile.
    SF=SF/payload.settings.sensitivity_multiplier;
end
semi=sum(fArea(fIDs=="F_semi_covalent"));
carbonMask=ismember(fIDs,["F_semi_covalent","F_covalent"]);
% A synthetic unmodelled shoulder at 685.8 eV is chemically carbon-bound;
% F_other/interface and the 684-eV substrate component are not.
carbonMask=carbonMask | contains(fIDs,"shoulder");
cross=@(a) (a/SF)/(cTotal/SC);
fc=[main,legacy,weighted,cross(semi),cross(sum(fArea(carbonMask))),cross(sum(fArea))];
out.F_over_C=fc;
out.F_atpct=100*fc./(1+fc);
out.C_over_F=1./fc;
out.CrossApplicable=logical(payload.scaling_truth_and_supplied.C1s_known && ...
    payload.scaling_truth_and_supplied.F1s_known);
end

function [a,b]=truthLabelsForPeaks(rows)
if isempty(rows),a=false;b=false;return;end
a=true;b=true;
for i=1:numel(rows)
    r=rows(i);
    if r.AreaClass=="major"
        a=a && finiteLE(r.CenterAbsError_eV,.15) && finiteLE(r.FWHMRelativeError,.25) && finiteLE(r.AreaRelativeError,.15);
        b=b && finiteLE(r.CenterAbsError_eV,.30) && finiteLE(r.FWHMRelativeError,.50) && finiteLE(r.AreaRelativeError,.30);
    elseif r.AreaClass=="minor"
        a=a && finiteLE(r.CenterAbsError_eV,.15) && finiteLE(r.FWHMRelativeError,.25) && finiteLE(r.FractionAbsError_pp,1.5);
        b=b && finiteLE(r.CenterAbsError_eV,.30) && finiteLE(r.FWHMRelativeError,.50) && finiteLE(r.FractionAbsError_pp,3.0);
    else
        a=a && finiteLE(r.FractionAbsError_pp,1.5);
        b=b && finiteLE(r.FractionAbsError_pp,3.0);
    end
end
end

function [a,b]=truthLabelsForComposition(rows)
app=rows([rows.GateApplicable]);
if isempty(app),a=false;b=false;return;end
a=true;b=true;
for i=1:numel(app)
    r=app(i);
    if r.TrueF_over_C>0
        a=a && finiteLE(r.FCRelativeError,.10) && finiteLE(r.CFRelativeError,.10) && finiteLE(r.FAtAbsError_pp,3);
        b=b && finiteLE(r.FCRelativeError,.15) && finiteLE(r.CFRelativeError,.15) && finiteLE(r.FAtAbsError_pp,5);
    else
        a=a && finiteLE(r.FCAbsoluteError,eps) && finiteLE(r.FAtAbsError_pp,3);
        b=b && finiteLE(r.FCAbsoluteError,eps) && finiteLE(r.FAtAbsError_pp,5);
    end
end
end

function [common,synthetic,exactBound,smallArea]=fitQC(payload,variant)
common=true;synthetic=true;exactBound=false;smallArea=false;
for region=["C1s","F1s"]
    if ~isfield(variant,region),continue;end
    fit=variant.(region);
    common=common && fit.exitflag>0 && all(isfinite(fit.finalParams)) && ...
        isfinite(fit.metrics.RMSE) && isfinite(fit.residual_autocorrelation.rho1) && ...
        abs(fit.residual_autocorrelation.rho1)<=.20;
    peaks=fit.peaks;
    exactBound=exactBound || any([peaks.center_at_bound]) || ...
        any([peaks.FWHM_at_bound]) || any([peaks.area_at_bound]);
    warnings=lower(string(fit.warnings));
    smallArea=smallArea || any(contains(warnings,"small area") | ...
        contains(warnings,"extremely small"));
    sigma=payload.truth.(region).noise_sigma_raw;
    scale=payload.truth.(region).software_normalization_scale;
    if sigma>0
        synthetic=synthetic && fit.metrics.RMSE/(sigma/scale)<=1.25;
    else
        synthetic=synthetic && fit.metrics.R2>=.999;
    end
end
common=common && logical(fieldOr(variant,"converged",true));
end

function tf=crossRegionWithheld(rows)
cross=rows([rows.CrossRegion]);
tf=~isempty(cross) && all(~[cross.ActualFinite]);
end

function row=pairedMetrics(a,b,cellKey,trialID)
row=pairTemplate();row.CellKey=cellKey;row.TrialID=trialID;row.Applicable=true;
center=[];area=[];fraction=[];
for region=["C1s","F1s"]
    if ~isfield(a,region)||~isfield(b,region),continue;end
    pa=a.(region).peaks;pb=b.(region).peaks;
    totalA=sum([pa.area]);totalB=sum([pb.area]);
    ids=intersect(string({pa.id}),string({pb.id}),"stable");
    for id=ids(:).'
        ia=find(string({pa.id})==id,1);ib=find(string({pb.id})==id,1);
        center(end+1)=abs(pa(ia).center_eV-pb(ib).center_eV); %#ok<AGROW>
        area(end+1)=abs(pa(ia).area-pb(ib).area)/max(abs(pa(ia).area),eps); %#ok<AGROW>
        fraction(end+1)=100*abs(pa(ia).area/totalA-pb(ib).area/totalB); %#ok<AGROW>
    end
end
row.MaxCenterDifference_eV=maxOrNaN(center);
row.MaxAreaRelativeDifference=maxOrNaN(area);
row.MaxComponentFractionDifference_pp=maxOrNaN(fraction);
paths=["primary.c1s_main_cf","diagnostics.legacy_c1s", ...
    "diagnostics.weighted_c1s","primary.c1s_f1s_semi", ...
    "diagnostics.carbon_bound_f1s_previous","diagnostics.total_f1s"];
rel=[];fat=[];
for path=paths
    x=getPath(a.composition,path);y=getPath(b.composition,path);
    if isstruct(x)&&isstruct(y)&&isfield(x,"F_over_C")&& ...
            isfinite(x.F_over_C)&&isfinite(y.F_over_C)
        rel(end+1)=abs(x.F_over_C-y.F_over_C)/max(abs(x.F_over_C),eps); %#ok<AGROW>
        fat(end+1)=abs(x.F_atpct-y.F_atpct); %#ok<AGROW>
    end
end
row.MaxCompositionRelativeDifference=maxOrNaN(rel);
row.MaxFAtDifference_pp=maxOrNaN(fat);
end

function value=getPath(s,path)
value=[];
for name=split(path,".").'
    if ~isstruct(s)||~isfield(s,name),value=[];return;end
    s=s.(name);
end
value=s;
end

function trial=copyFitMetrics(trial,variant)
for region=["C1s","F1s"]
    if ~isfield(variant,region),continue;end
    fit=variant.(region);
    prefix=char(region);
    trial.([prefix 'RMSE'])=double(fit.metrics.RMSE);
    trial.([prefix 'R2'])=double(fit.metrics.R2);
    trial.([prefix 'AICc'])=double(fit.metrics.AICc);
    trial.([prefix 'BIC'])=double(fit.metrics.BIC);
    trial.([prefix 'ResidualRho1'])=double(fit.residual_autocorrelation.rho1);
end
end

function tf=applicableAnd(a,x,b,y)
values=[];if a,values(end+1)=logical(x);end %#ok<AGROW>
if b,values(end+1)=logical(y);end %#ok<AGROW>
tf=~isempty(values)&&all(values);
end
function tf=finiteLE(x,limit),tf=isfinite(x)&&x<=limit;end
function value=maxOrNaN(x),if isempty(x),value=NaN;else,value=max(x);end,end
function value=fieldOr(s,name,default),if isfield(s,name),value=s.(name);else,value=default;end,end

function s=trialTemplate
s=struct("FamilyID",0,"FamilyName","","CellKey","","Gate","", ...
    "TrialID",0,"SourceRunID","","SourceExecutionFingerprint","", ...
    "Status","","ExecutionError",false,"TrialConverged",false, ...
    "OptimizerInvocations",0,"PeakApplicable",false, ...
    "CompositionApplicable",false,"PeakTruthAcceptable_A",false, ...
    "PeakTruthAcceptable_B",false,"CompositionTruthAcceptable_A",false, ...
    "CompositionTruthAcceptable_B",false,"OverallTruthAcceptable_A",false, ...
    "OverallTruthAcceptable_B",false,"DeployablePeakQCValid",false, ...
    "DeployableCompositionQCValid",false,"DeployableOverallQCValid",false, ...
    "SyntheticDiagnosticPeakQCValid",false, ...
    "SyntheticDiagnosticCompositionQCValid",false, ...
    "SyntheticDiagnosticOverallQCValid",false,"ExactBoundHit",false, ...
    "SmallAreaWarning",false,"CompositionWithheld",false, ...
    "CrossRegionExpected",false,"CrossRegionWithheld",false, ...
    "C1sRMSE",NaN,"C1sR2",NaN,"C1sAICc",NaN,"C1sBIC",NaN, ...
    "C1sResidualRho1",NaN,"F1sRMSE",NaN,"F1sR2",NaN, ...
    "F1sAICc",NaN,"F1sBIC",NaN,"F1sResidualRho1",NaN);
end
function s=peakTemplate
s=struct("CellKey","","TrialID",0,"Region","","PeakID","", ...
    "MatchType","","AreaClass","","TruthPresent",false,"FitPresent",false, ...
    "TruthInFitModel",false,"TruthCenter_eV",NaN,"FitCenter_eV",NaN, ...
    "TruthFWHM_eV",NaN,"FitFWHM_eV",NaN,"TruthArea",NaN,"FitArea",NaN, ...
    "TruthFraction",NaN,"FitFraction",NaN,"CenterAbsError_eV",NaN, ...
    "FWHMRelativeError",NaN,"AreaRelativeError",NaN, ...
    "FractionAbsError_pp",NaN,"TrueFullAnalyticArea",NaN, ...
    "TrueInWindowArea",NaN,"TrueWindowContainmentFraction",NaN, ...
    "TrueSampledGridArea",NaN,"CenterAtBound",false,"FWHMAtBound",false, ...
    "AreaAtBound",false,"CenterNearBound",false,"FWHMNearBound",false, ...
    "AreaNearBound",false,"ExactBoundHit",false,"NearBoundHit",false);
end
function s=compositionTemplate
s=struct("CellKey","","TrialID",0,"ModelPath","","CrossRegion",false, ...
    "Applicable",false,"GateApplicable",false, ...
    "TrueF_over_C",NaN,"ActualF_over_C",NaN, ...
    "TrueC_over_F",NaN,"ActualC_over_F",NaN,"TrueF_atpct",NaN, ...
    "ActualF_atpct",NaN,"FCRelativeError",NaN,"CFRelativeError",NaN, ...
    "FCAbsoluteError",NaN,"FAtAbsError_pp",NaN,"ActualStatus","", ...
    "ActualValid",false,"ActualFinite",false);
end
function s=pairTemplate
s=struct("CellKey","","TrialID",0,"Applicable",false, ...
    "MaxCenterDifference_eV",NaN,"MaxAreaRelativeDifference",NaN, ...
    "MaxComponentFractionDifference_pp",NaN, ...
    "MaxCompositionRelativeDifference",NaN,"MaxFAtDifference_pp",NaN);
end
