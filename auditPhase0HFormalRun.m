function audit = auditPhase0HFormalRun(formalFolder,options)
%AUDITPHASE0HFORMALRUN Read-only audit of immutable Phase 0H checkpoints.
%
% This utility never calls a checkpoint writer and never writes beneath the
% formal run folder. Scientific invalidity is kept separate from an actual
% caught MATLAB/runtime exception.

arguments
    formalFolder (1,1) string = ""
    options.WriteArtifacts (1,1) logical = false
    options.OutputFolder (1,1) string = ""
end
projectFolder=string(fileparts(mfilename("fullpath")));
if strlength(formalFolder)==0
    formalFolder=fullfile(projectFolder,"results","phase0h_formal_v1_0_0");
end
if ~isfile(fullfile(formalFolder,"manifest.json"))
    error("auditPhase0HFormalRun:MissingManifest", ...
        "Formal manifest not found at %s.",formalFolder);
end
manifest=jsondecode(fileread(fullfile(formalFolder,"manifest.json")));
expectedPlanHash="1f932b278de41dc14154191833f45b5fcf55f3b5a01edd7a661ddcbcf2f556bf";
expectedExecutionFingerprint= ...
    "93c6ad3a88ba0245be2043c06ca20c0adb62033989f051a6e71e340d31e292b4";
if string(manifest.plan_sha256)~=expectedPlanHash || ...
        string(manifest.code_config_fingerprint)~=expectedExecutionFingerprint
    error("auditPhase0HFormalRun:ProvenanceMismatch", ...
        "Stored formal plan or execution fingerprint is not the approved v1.0.0 run.");
end

inventory=readtable(fullfile(formalFolder,"cell_inventory.csv"), ...
    TextType="string",VariableNamingRule="preserve");
plannedTotal=sum(inventory.InitialTrials);
checkpointRoot=fullfile(formalFolder,"checkpoints");

FamilyID=zeros(plannedTotal,1); FamilyName=strings(plannedTotal,1);
CellKey=strings(plannedTotal,1); TrialID=zeros(plannedTotal,1);
ExecutionStatus=strings(plannedTotal,1); ActualException=false(plannedTotal,1);
ErrorIdentifier=strings(plannedTotal,1); NormalizedErrorMessage=strings(plannedTotal,1);
ErrorStage=strings(plannedTotal,1); ErrorNature=strings(plannedTotal,1);
TrialConverged=false(plannedTotal,1); CompositionWithheld=false(plannedTotal,1);
QCInvalid=false(plannedTotal,1); ScientificInvalid=false(plannedTotal,1);
cursor=0;

for c=1:height(inventory)
    cellKey=inventory.CellKey(c);
    for trialID=1:inventory.InitialTrials(c)
        cursor=cursor+1;
        filename=fullfile(checkpointRoot,cellKey,compose("trial_%04d.mat",trialID));
        if ~isfile(filename)
            error("auditPhase0HFormalRun:MissingCheckpoint", ...
                "Missing checkpoint %s.",filename);
        end
        value=load(filename,"payload","runFingerprint","cellKey","trialID");
        if string(value.runFingerprint)~=string(manifest.run_fingerprint) || ...
                string(value.cellKey)~=cellKey || value.trialID~=trialID
            error("auditPhase0HFormalRun:CheckpointIdentityMismatch", ...
                "Checkpoint identity mismatch in %s.",filename);
        end
        payload=value.payload;
        FamilyID(cursor)=inventory.FamilyID(c);
        FamilyName(cursor)=inventory.FamilyName(c);
        CellKey(cursor)=cellKey; TrialID(cursor)=trialID;
        ExecutionStatus(cursor)=string(payload.status);
        ActualException(cursor)=ExecutionStatus(cursor)=="error";
        if ActualException(cursor)
            [identifier,message,report]=exceptionFields(payload);
            ErrorIdentifier(cursor)=identifier;
            NormalizedErrorMessage(cursor)=normalizeMessage(message);
            ErrorStage(cursor)=classifyStage(identifier,message,report);
            ErrorNature(cursor)=classifyExceptionNature(identifier,message,report);
        else
            TrialConverged(cursor)=logical(fieldOr(payload,"trial_converged",false));
            CompositionWithheld(cursor)=hasWithheldComposition(payload);
            QCInvalid(cursor)=hasInvalidCompositionQC(payload);
            ScientificInvalid(cursor)=~TrialConverged(cursor) || ...
                CompositionWithheld(cursor) || QCInvalid(cursor);
            if ScientificInvalid(cursor)
                ErrorNature(cursor)="scientific_invalid_or_withheld_no_exception";
            else
                ErrorNature(cursor)="successful_valid_execution";
            end
            ErrorStage(cursor)="none";
        end
    end
end

trialAudit=table(FamilyID,FamilyName,CellKey,TrialID,ExecutionStatus, ...
    ActualException,ErrorIdentifier,NormalizedErrorMessage,ErrorStage, ...
    ErrorNature,TrialConverged,CompositionWithheld,QCInvalid,ScientificInvalid);
familyAudit=aggregateAudit(trialAudit,["FamilyID","FamilyName"]);
cellAudit=aggregateAudit(trialAudit,["FamilyID","FamilyName","CellKey"]);
exceptionRows=trialAudit.ActualException;
errorsByIdentifier=frequencyTable(trialAudit.ErrorIdentifier(exceptionRows), ...
    "ErrorIdentifier");
errorsByMessage=frequencyTable(trialAudit.NormalizedErrorMessage(exceptionRows), ...
    "NormalizedErrorMessage");
errorsByStage=frequencyTable(trialAudit.ErrorStage(exceptionRows),"ErrorStage");
errorsByNature=frequencyTable(trialAudit.ErrorNature(exceptionRows),"ErrorNature");

totals=struct("planned_trials",plannedTotal, ...
    "successful_trials",nnz(~trialAudit.ActualException), ...
    "execution_error_trials",nnz(trialAudit.ActualException), ...
    "nonconverged_trials",nnz(~trialAudit.ActualException & ~trialAudit.TrialConverged), ...
    "composition_withheld_trials",nnz(trialAudit.CompositionWithheld), ...
    "qc_invalid_trials",nnz(trialAudit.QCInvalid), ...
    "scientific_invalid_no_exception_trials",nnz(trialAudit.ScientificInvalid));
audit=struct("audit_id","phase0h_formal_read_only_audit", ...
    "audit_version","1.0.1","formal_folder",formalFolder, ...
    "read_only",true,"plan_hash",string(manifest.plan_sha256), ...
    "execution_code_config_fingerprint",string(manifest.code_config_fingerprint), ...
    "run_fingerprint",string(manifest.run_fingerprint),"totals",totals, ...
    "trialAudit",trialAudit,"familyAudit",familyAudit,"cellAudit",cellAudit, ...
    "errorsByIdentifier",errorsByIdentifier,"errorsByMessage",errorsByMessage, ...
    "errorsByStage",errorsByStage,"errorsByNature",errorsByNature);
audit.postprocessing=phase0HPostprocessingProvenance(projectFolder);

fprintf("\nPhase 0H immutable-run execution audit\n");
fprintf("Success=%d; execution errors=%d; nonconverged=%d; withheld=%d; QC-invalid=%d.\n", ...
    totals.successful_trials,totals.execution_error_trials, ...
    totals.nonconverged_trials,totals.composition_withheld_trials, ...
    totals.qc_invalid_trials);
disp(familyAudit);
fprintf("Errors by identifier:\n");disp(errorsByIdentifier);
fprintf("Errors by normalized message:\n");disp(errorsByMessage);

if options.WriteArtifacts
    outputFolder=options.OutputFolder;
    if strlength(outputFolder)==0
        outputFolder=fullfile(projectFolder,"results", ...
            "phase0h_postprocess_audit_v1_0_1");
    end
    assertOutsideFormal(outputFolder,formalFolder);
    if ~isfolder(outputFolder),mkdir(outputFolder);end
    audit.output_folder=outputFolder;
    writetable(trialAudit,fullfile(outputFolder,"trial_audit.csv"));
    writetable(familyAudit,fullfile(outputFolder,"family_audit.csv"));
    writetable(cellAudit,fullfile(outputFolder,"cell_audit.csv"));
    writetable(errorsByIdentifier,fullfile(outputFolder,"errors_by_identifier.csv"));
    writetable(errorsByMessage,fullfile(outputFolder,"errors_by_message.csv"));
    writetable(errorsByStage,fullfile(outputFolder,"errors_by_stage.csv"));
    writetable(errorsByNature,fullfile(outputFolder,"errors_by_nature.csv"));
    save(fullfile(outputFolder,"audit_report.mat"),"audit","-v7.3");
    writeText(fullfile(outputFolder,"audit_provenance.json"), ...
        jsonencode(struct("formal_plan_sha256",audit.plan_hash, ...
        "formal_execution_code_config_fingerprint", ...
        audit.execution_code_config_fingerprint, ...
        "formal_run_fingerprint",audit.run_fingerprint, ...
        "postprocessing",audit.postprocessing),PrettyPrint=true));
end
end

function [identifier,message,report]=exceptionFields(payload)
identifier="unidentified_exception";message="missing exception message";report="";
if ~isfield(payload,"error"),return;end
if isfield(payload.error,"identifier"),identifier=string(payload.error.identifier);end
if isfield(payload.error,"message"),message=string(payload.error.message);end
if isfield(payload.error,"report"),report=string(payload.error.report);end
end

function value=normalizeMessage(message)
value=string(regexprep(char(message),'[\x00-\x20\x7F]+',' '));
value=string(regexprep(char(value),'trial_\d+','trial_<N>','ignorecase'));
value=strip(value);
end

function stage=classifyStage(identifier,message,report)
text=lower(identifier+" "+message+" "+report);
if contains(text,"invalidfixture") || contains(text,"generatefixture") || ...
        contains(text,"validatefixture")
    stage="fixture_generation";
elseif contains(text,"preprocess") || contains(text,"estimatebackground") || ...
        contains(text,"xps_backgrounds")
    stage="preprocessing/background";
elseif contains(text,"classifyf1speaks")
    stage="classification";
elseif contains(text,"calculatecomposition") || ...
        contains(text,"executecompositiononly") || contains(text,"truthasfittedpeaks") || ...
        contains(text,"buildquantificationscaling")
    stage="composition";
elseif contains(text,"residualautocorrelation") || contains(text,"wilson") || ...
        contains(text,"summarizevalues") || contains(text,"calculatefitmetrics")
    stage="QC/statistics";
elseif contains(text,"fitspectrum") || contains(text,"fitregion")
    if contains(text,"c1s")
        stage="C1s_fitting";
    elseif contains(text,"f1s")
        stage="F1s_fitting";
    else
        stage="fitting_region_not_recoverable";
    end
else
    stage="stage_not_recoverable";
end
end

function nature=classifyExceptionNature(identifier,message,report)
text=lower(identifier+" "+message+" "+report);
if contains(text,"invalidfixture") || contains(text,"nonexistentfield") || ...
        contains(text,"unrecognized field") || contains(text,"undefinedfunction") || ...
        contains(text,"structref") || contains(text,"index exceeds")
    nature="implementation_or_harness_defect";
elseif contains(text,"allstartsfailed") || contains(text,"lsqnonlin") || ...
        contains(text,"optim")
    nature="algorithm_or_numerical_failure_under_stress";
else
    nature="runtime_exception_requires_review";
end
end

function tf=hasWithheldComposition(payload)
tf=false;
if ~isfield(payload,"variants"),return;end
for i=1:numel(payload.variants)
    if ~isfield(payload.variants(i),"composition"),continue;end
    comp=payload.variants(i).composition;
    if isfield(comp,"status") && contains(lower(string(comp.status)),"withheld")
        tf=true;return
    end
    if isfield(comp,"primary") && groupHasStatus(comp.primary,"withheld")
        tf=true;return
    end
end
end

function tf=hasInvalidCompositionQC(payload)
tf=false;
if ~isfield(payload,"variants"),return;end
for i=1:numel(payload.variants)
    if ~isfield(payload.variants(i),"composition"),continue;end
    comp=payload.variants(i).composition;
    for group=["primary","diagnostics"]
        if isfield(comp,group) && groupHasInvalidQC(comp.(group))
            tf=true;return
        end
    end
end
end

function tf=groupHasStatus(group,status)
tf=false;names=fieldnames(group);
for i=1:numel(names)
    value=group.(names{i});
    if isstruct(value) && isfield(value,"status") && ...
            contains(lower(string(value.status)),lower(status))
        tf=true;return
    end
end
end

function tf=groupHasInvalidQC(group)
tf=false;names=fieldnames(group);
for i=1:numel(names)
    value=group.(names{i});
    if isstruct(value) && isfield(value,"QC") && isstruct(value.QC)
        if isfield(value.QC,"pass") && ~logical(value.QC.pass)
            tf=true;return
        end
        if isfield(value.QC,"valid") && ~logical(value.QC.valid)
            tf=true;return
        end
    end
end
end

function out=aggregateAudit(T,groupNames)
keys=unique(T(:,groupNames),"rows","stable");
n=height(keys);
NPlanned=zeros(n,1);NSuccess=zeros(n,1);NExecutionError=zeros(n,1);
NNonconverged=zeros(n,1);NCompositionWithheld=zeros(n,1);NQCInvalid=zeros(n,1);
for i=1:n
    use=true(height(T),1);
    for name=groupNames
        use=use & T.(name)==keys.(name)(i);
    end
    NPlanned(i)=nnz(use);
    NSuccess(i)=nnz(use & ~T.ActualException);
    NExecutionError(i)=nnz(use & T.ActualException);
    NNonconverged(i)=nnz(use & ~T.ActualException & ~T.TrialConverged);
    NCompositionWithheld(i)=nnz(use & T.CompositionWithheld);
    NQCInvalid(i)=nnz(use & T.QCInvalid);
end
out=[keys,table(NPlanned,NSuccess,NExecutionError,NNonconverged, ...
    NCompositionWithheld,NQCInvalid)];
end

function out=frequencyTable(values,name)
if isempty(values)
    out=table(strings(0,1),zeros(0,1),VariableNames=[name,"Count"]);return
end
[labels,~,group]=unique(values,"stable");
counts=accumarray(group,1);
[counts,order]=sort(counts,"descend");labels=labels(order);
out=table(labels,counts,VariableNames=[name,"Count"]);
end

function value=fieldOr(s,name,default)
if isfield(s,name),value=s.(name);else,value=default;end
end

function assertOutsideFormal(outputFolder,formalFolder)
formal=lower(string(char(java.io.File(formalFolder).getCanonicalPath())));
output=lower(string(char(java.io.File(outputFolder).getCanonicalPath())));
if output==formal || startsWith(output,formal+string(filesep))
    error("auditPhase0HFormalRun:FormalOutputIsImmutable", ...
        "Audit artifacts may not be written inside the formal run folder.");
end
end

function writeText(filename,value)
fid=fopen(filename,"w");
if fid<0,error("auditPhase0HFormalRun:WriteFailed","Cannot write %s.",filename);end
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,"%s\n",value);
end
