function summary = generatePhase0HSummaries(formalFolder,options)
%GENERATEPHASE0HSUMMARIES Aggregate immutable checkpoints after completion.
%
% This stage is deliberately separate from optimizer execution. It writes
% tabular summaries and creates no figures; later plotting can consume the
% saved summary tables without entering a Monte Carlo loop. Output is kept
% outside the immutable formal-run directory.

arguments
    formalFolder (1,1) string = ""
    options.OutputFolder (1,1) string = ""
end
projectFolder=string(fileparts(mfilename("fullpath")));
if strlength(formalFolder)==0
    formalFolder=fullfile(projectFolder,"results","phase0h_formal_v1_0_0");
end
outputFolder=options.OutputFolder;
if strlength(outputFolder)==0
    outputFolder=fullfile(projectFolder,"results","phase0h_postprocess_v1_0_1");
end
assertOutsideFormal(outputFolder,formalFolder);

manifest=jsondecode(fileread(fullfile(formalFolder,"manifest.json")));
expectedPlanHash="1f932b278de41dc14154191833f45b5fcf55f3b5a01edd7a661ddcbcf2f556bf";
expectedExecutionFingerprint= ...
    "93c6ad3a88ba0245be2043c06ca20c0adb62033989f051a6e71e340d31e292b4";
if string(manifest.plan_sha256)~=expectedPlanHash || ...
        string(manifest.code_config_fingerprint)~=expectedExecutionFingerprint
    error("generatePhase0HSummaries:ProvenanceMismatch", ...
        "Stored formal provenance is not the approved v1.0.0 run.");
end

inventory=readtable(fullfile(formalFolder,"cell_inventory.csv"), ...
    TextType="string",VariableNamingRule="preserve");
plannedTrials=sum(inventory.InitialTrials);
checkpointRoot=fullfile(formalFolder,"checkpoints");
rows=cell(plannedTrials,1); cursor=0;
for c=1:height(inventory)
    cellKey=inventory.CellKey(c);
    cellCheckpoint=fullfile(checkpointRoot,cellKey,"cell_complete.mat");
    if ~isfile(cellCheckpoint)
        error("generatePhase0HSummaries:RunIncomplete", ...
            "Cell %s has no completion checkpoint.",cellKey);
    end
    cellRecord=load(cellCheckpoint,"runFingerprint","cellKey", ...
        "completedTrialIDs");
    expectedIDs=(1:inventory.InitialTrials(c)).';
    if string(cellRecord.runFingerprint)~=string(manifest.run_fingerprint) || ...
            string(cellRecord.cellKey)~=cellKey || ...
            ~isequal(cellRecord.completedTrialIDs,expectedIDs)
        error("generatePhase0HSummaries:CheckpointMismatch", ...
            "Cell completion checkpoint mismatch for %s.",cellKey);
    end
    for trialID=expectedIDs.'
        filename=fullfile(checkpointRoot,cellKey, ...
            compose("trial_%04d.mat",trialID));
        value=load(filename,"payload","runFingerprint","cellKey","trialID");
        if string(value.runFingerprint)~=string(manifest.run_fingerprint) || ...
                string(value.cellKey)~=cellKey || value.trialID~=trialID
            error("generatePhase0HSummaries:CheckpointMismatch", ...
                "Trial checkpoint identity mismatch in %s.",filename);
        end
        cursor=cursor+1;
        rows{cursor}=trialRow(inventory(c,:),trialID,value.payload);
    end
end
if cursor~=plannedTrials
    error("generatePhase0HSummaries:RunIncomplete", ...
        "Found %d/%d planned trial checkpoints.",cursor,plannedTrials);
end
trialSummary=struct2table(vertcat(rows{:}));
familySummary=aggregatePhase0HFamilySummary(trialSummary);

summaryFolder=outputFolder;
if ~isfolder(summaryFolder),mkdir(summaryFolder);end
writetable(trialSummary,fullfile(summaryFolder,"trial_execution_summary.csv"));
writetable(familySummary,fullfile(summaryFolder,"family_execution_summary.csv"));
postprocessing=phase0HPostprocessingProvenance(projectFolder);
summary=struct("summary_id","phase0h_final_execution_summary_v1", ...
    "generated_after_complete_run",true,"plotting_performed",false, ...
    "formal_run_immutable",true, ...
    "plan_version",string(manifest.plan_version), ...
    "plan_sha256",string(manifest.plan_sha256), ...
    "execution_code_config_fingerprint", ...
        string(manifest.code_config_fingerprint), ...
    "run_fingerprint",string(manifest.run_fingerprint), ...
    "postprocessing",postprocessing,"trialSummary",trialSummary, ...
    "familySummary",familySummary,"output_folder",summaryFolder);
save(fullfile(summaryFolder,"phase0h_final_summary.mat"),"summary","-v7.3");
fprintf("Phase 0H final execution summaries written to %s (no figures).\n", ...
    summaryFolder);
end

function row=trialRow(cellRecord,trialID,payload)
[cR2,fR2]=fitQuality(payload);
errorID="";
if isfield(payload,"error") && isfield(payload.error,"identifier")
    errorID=string(payload.error.identifier);
end
row=struct("FamilyID",cellRecord.FamilyID, ...
    "FamilyName",string(cellRecord.FamilyName), ...
    "CellKey",string(cellRecord.CellKey),"TrialID",trialID, ...
    "Status",string(payload.status), ...
    "TrialConverged",logical(fieldOr(payload,"trial_converged",false)), ...
    "OptimizerInvocations",double(fieldOr(payload,"optimizer_invocations",0)), ...
    "ElapsedSeconds",double(fieldOr(payload,"elapsed_seconds",NaN)), ...
    "C1sR2",cR2,"F1sR2",fR2,"ErrorIdentifier",errorID);
end

function [cR2,fR2]=fitQuality(payload)
cR2=NaN;fR2=NaN;
if ~isfield(payload,"variants") || isempty(payload.variants),return;end
variant=payload.variants(1);
if isfield(variant,"C1s") && isfield(variant.C1s,"metrics")
    cR2=variant.C1s.metrics.R2;
end
if isfield(variant,"F1s") && isfield(variant.F1s,"metrics")
    fR2=variant.F1s.metrics.R2;
end
end

function value=fieldOr(s,name,default)
if isfield(s,name),value=s.(name);else,value=default;end
end

function assertOutsideFormal(outputFolder,formalFolder)
formal=lower(string(char(java.io.File(formalFolder).getCanonicalPath())));
output=lower(string(char(java.io.File(outputFolder).getCanonicalPath())));
if output==formal || startsWith(output,formal+string(filesep))
    error("generatePhase0HSummaries:FormalOutputIsImmutable", ...
        "Post-processing output may not be written inside the formal run folder.");
end
end
