function summary = generateUnifiedPhase0HSummary(originalFolder,amendmentFolder,options)
%GENERATEUNIFIEDPHASE0HSUMMARY Read-only unified Phase 0H v1.0.0+amendment analysis.
%
% Source selection is fixed:
%   * original v1.0.0 checkpoints for the 81 unaffected cells;
%   * amendment v1.0.1 checkpoints for F10_G2 and F12_R1-R5/T1-T5.
%
% The function does not modify either execution directory, regenerate any
% fixture/seed, call an optimizer, or produce a figure. It writes only
% derived tables to a separate post-processing directory.

arguments
    originalFolder (1,1) string = ""
    amendmentFolder (1,1) string = ""
    options.OutputFolder (1,1) string = ""
end
projectFolder=string(fileparts(mfilename("fullpath")));
if strlength(originalFolder)==0
    originalFolder=fullfile(projectFolder,"results","phase0h_formal_v1_0_0");
end
if strlength(amendmentFolder)==0
    amendmentFolder=fullfile(projectFolder,"results", ...
        "phase0h_execution_amendment_v1_0_1");
end
outputFolder=options.OutputFolder;
if strlength(outputFolder)==0
    outputFolder=fullfile(projectFolder,"results","phase0h_unified_v1_0_1");
end
assertOutsideSources(outputFolder,[originalFolder,amendmentFolder]);
if isfolder(outputFolder) && ~isempty(dir(fullfile(outputFolder,"*")))
    error("generateUnifiedPhase0HSummary:OutputExists", ...
        "Derived output folder is not empty; choose a new OutputFolder: %s",outputFolder);
end

plan=xpsh.buildPlan(projectFolder);
originalManifest=readManifest(originalFolder);
amendmentManifest=readManifest(amendmentFolder);
expectedPlan="1f932b278de41dc14154191833f45b5fcf55f3b5a01edd7a661ddcbcf2f556bf";
expectedOriginal="93c6ad3a88ba0245be2043c06ca20c0adb62033989f051a6e71e340d31e292b4";
expectedAmendmentCode="e0173d6d25ebd30e2c1ac02054e4a29568d0a9038b0c4ea815fddcd272293845";
expectedAmendmentExecution="60ddb98176b263595a54ae115980c96dcb7e696dc64e2cd05b759aef2e2a55e6";
validateManifest(originalManifest,amendmentManifest,expectedPlan, ...
    expectedOriginal,expectedAmendmentCode,expectedAmendmentExecution);

affected=["F10_G2","F12_R1","F12_R2","F12_R3","F12_R4","F12_R5", ...
    "F12_T1","F12_T2","F12_T3","F12_T4","F12_T5"];
if ~isequal(sort(string(amendmentManifest.amendment.affected_cells(:))),sort(affected(:)))
    error("generateUnifiedPhase0HSummary:AffectedCellMismatch", ...
        "Amendment manifest does not name the exact approved 11 cells.");
end

originalBefore=xpsh.formalRunIntegritySnapshot(originalFolder);
amendmentBefore=xpsh.formalRunIntegritySnapshot(amendmentFolder);
trialCells=cell(plan.initial_trial_count,1);indexCells=cell(plan.initial_trial_count,1);
peakCells={};compositionCells={};pairCells={};provenanceCells=cell(plan.cell_count,1);
cursor=0;peakCursor=0;compositionCursor=0;pairCursor=0;
fprintf("Building read-only unified Phase 0H index and frozen-gate metrics...\n");
for i=1:numel(plan.cells)
    c=plan.cells(i);key=string(c.cell_key);
    useAmendment=ismember(key,affected);
    if useAmendment
        sourceFolder=amendmentFolder;manifest=amendmentManifest;
        sourceRunID="phase0h_execution_amendment_v1_0_1";
        sourceExecutionFingerprint=string(amendmentManifest.amended_execution_fingerprint);
    else
        sourceFolder=originalFolder;manifest=originalManifest;
        sourceRunID="phase0h_formal_v1_0_0";
        sourceExecutionFingerprint=string(originalManifest.code_config_fingerprint);
    end
    validateCellCheckpoint(sourceFolder,key,c.trials,string(manifest.run_fingerprint));
    provenanceCells{i}=struct("FamilyID",c.family_id,"FamilyName",string(c.family_name), ...
        "CellKey",key,"SourceRunID",sourceRunID, ...
        "SourceExecutionFingerprint",sourceExecutionFingerprint, ...
        "SourceRunFingerprint",string(manifest.run_fingerprint), ...
        "Trials",c.trials,"OriginalSeedsReused",true);
    for trialID=1:c.trials
        filename=fullfile(sourceFolder,"checkpoints",key,compose("trial_%04d.mat",trialID));
        value=load(filename,"payload","runFingerprint","cellKey","trialID");
        validateTrialIdentity(value,key,trialID,string(manifest.run_fingerprint),filename);
        expectedSeeds=xpsh.trialSeeds(c,trialID);
        if ~isequaln(value.payload.seeds,expectedSeeds)
            error("generateUnifiedPhase0HSummary:SeedMismatch", ...
                "Stored seeds differ from frozen schedule in %s.",filename);
        end
        [trial,peaks,compositions,pair]=analyzePhase0HUnifiedTrial( ...
            value.payload,c,sourceRunID,sourceExecutionFingerprint);
        cursor=cursor+1;trialCells{cursor}=trial;
        indexCells{cursor}=struct("FamilyID",c.family_id,"FamilyName",string(c.family_name), ...
            "CellKey",key,"TrialID",trialID,"SourceRunID",sourceRunID, ...
            "SourceExecutionFingerprint",sourceExecutionFingerprint, ...
            "SeedScheduleVerified",true,"CheckpointPath",string(filename));
        if ~isempty(peaks)
            for j=1:numel(peaks),peakCursor=peakCursor+1;peakCells{peakCursor,1}=peaks(j);end %#ok<AGROW>
        end
        if ~isempty(compositions)
            for j=1:numel(compositions)
                compositionCursor=compositionCursor+1;compositionCells{compositionCursor,1}=compositions(j); %#ok<AGROW>
            end
        end
        if pair.Applicable,pairCursor=pairCursor+1;pairCells{pairCursor,1}=pair;end %#ok<AGROW>
    end
    if mod(i,10)==0 || i==numel(plan.cells)
        fprintf("  indexed %d/%d cells (%d/%d trials)\n",i,numel(plan.cells),cursor,plan.initial_trial_count);
    end
end
if cursor~=9200,error("generateUnifiedPhase0HSummary:TrialCount","Expected 9,200 trials.");end

trialTable=struct2table(vertcat(trialCells{:}));
trialIndex=struct2table(vertcat(indexCells{:}));
cellProvenance=struct2table(vertcat(provenanceCells{:}));
peakTable=struct2table(vertcat(peakCells{:}));
compositionTable=struct2table(vertcat(compositionCells{:}));
if isempty(pairCells),pairTable=table();else,pairTable=struct2table(vertcat(pairCells{:}));end

gate=summarizePhase0HUnifiedResults(plan,trialTable,peakTable,compositionTable,pairTable);
allCellsHave100=all(groupcounts(categorical(trialTable.CellKey))==100) && ...
    height(unique(trialTable(:,"CellKey")))==92;
allUsable=all(~trialTable.ExecutionError);
sourceCounts=groupsummary(cellProvenance,"SourceRunID","sum","Trials");

originalAfter=xpsh.formalRunIntegritySnapshot(originalFolder);
amendmentAfter=xpsh.formalRunIntegritySnapshot(amendmentFolder);
if ~isequaln(originalBefore,originalAfter) || ~isequaln(amendmentBefore,amendmentAfter)
    error("generateUnifiedPhase0HSummary:SourceMutation", ...
        "A source execution directory changed during read-only post-processing.");
end

postprocessing=postprocessingProvenance(projectFolder);
provenanceValid=all(trialIndex.SeedScheduleVerified) && ...
    height(cellProvenance)==92 && nnz(cellProvenance.SourceRunID== ...
    "phase0h_formal_v1_0_0")==81 && nnz(cellProvenance.SourceRunID== ...
    "phase0h_execution_amendment_v1_0_1")==11;
summary=struct("summary_id","phase0h_unified_read_only_summary", ...
    "summary_version","1.0.1","generated_at",string(datetime("now", ...
    "Format","yyyy-MM-dd'T'HH:mm:ssXXX")),"plotting_performed",false, ...
    "source_runs_immutable",true,"plan_version","1.0.0", ...
    "plan_sha256",expectedPlan,"original_execution_fingerprint",expectedOriginal, ...
    "amended_execution_fingerprint",expectedAmendmentExecution, ...
    "amended_code_config_fingerprint",expectedAmendmentCode, ...
    "cell_count",92,"trial_count",height(trialTable), ...
    "all_cells_have_100_trials",allCellsHave100, ...
    "all_trials_usable",allUsable,"execution_errors",nnz(trialTable.ExecutionError), ...
    "nonconverged_trials",nnz(~trialTable.TrialConverged), ...
    "provenance_validation_passed",provenanceValid, ...
    "sourceCounts",sourceCounts,"cellProvenance",cellProvenance, ...
    "trialIndex",trialIndex,"trialMetrics",trialTable,"peakMetrics",peakTable, ...
    "compositionMetrics",compositionTable,"pairMetrics",pairTable, ...
    "cellSummary",gate.cellSummary,"rateSummary",gate.rateSummary, ...
    "peakMetricSummary",gate.peakMetricSummary, ...
    "compositionMetricSummary",gate.compositionMetricSummary, ...
    "borderlineExtensionCells",gate.extensionCells, ...
    "postprocessing",postprocessing,"output_folder",outputFolder);

if ~isfolder(outputFolder),mkdir(outputFolder);end
writetable(cellProvenance,fullfile(outputFolder,"cell_execution_provenance.csv"));
writetable(trialIndex,fullfile(outputFolder,"unified_trial_index.csv"));
writetable(trialTable,fullfile(outputFolder,"trial_metrics.csv"));
writetable(peakTable,fullfile(outputFolder,"peak_metrics.csv"));
writetable(compositionTable,fullfile(outputFolder,"composition_metrics.csv"));
if ~isempty(pairTable),writetable(pairTable,fullfile(outputFolder,"paired_metrics.csv"));end
writetable(gate.cellSummary,fullfile(outputFolder,"gate_summary_by_cell.csv"));
writetable(gate.rateSummary,fullfile(outputFolder,"qc_rate_summary.csv"));
writetable(gate.peakMetricSummary,fullfile(outputFolder,"peak_distribution_summary.csv"));
writetable(gate.compositionMetricSummary,fullfile(outputFolder,"composition_distribution_summary.csv"));
writetable(gate.extensionCells,fullfile(outputFolder,"borderline_extension_cells.csv"));
save(fullfile(outputFolder,"phase0h_unified_summary.mat"),"summary","-v7.3");
xpsh.writeJsonAtomic(fullfile(outputFolder,"unified_provenance.json"),struct( ...
    "summary_id",summary.summary_id,"summary_version",summary.summary_version, ...
    "plan_sha256",expectedPlan,"original_execution_fingerprint",expectedOriginal, ...
    "amended_execution_fingerprint",expectedAmendmentExecution, ...
    "amended_code_config_fingerprint",expectedAmendmentCode, ...
    "affected_cells",affected,"source_cell_counts",struct("original",81,"amendment",11), ...
    "all_cells_have_100_trials",allCellsHave100,"all_trials_usable",allUsable, ...
    "provenance_validation_passed",provenanceValid,"postprocessing",postprocessing));

fprintf("Unified Phase 0H summary written to %s\n",outputFolder);
fprintf("Cells=%d; trials=%d; usable=%d; errors=%d; nonconverged=%d; provenance=%s.\n", ...
    92,height(trialTable),nnz(~trialTable.ExecutionError),nnz(trialTable.ExecutionError), ...
    nnz(~trialTable.TrialConverged),string(provenanceValid));
fprintf("Predeclared borderline extensions identified: %d (not executed).\n", ...
    height(gate.extensionCells));
end

function manifest=readManifest(folder)
file=fullfile(folder,"manifest.json");
if ~isfile(file),error("generateUnifiedPhase0HSummary:MissingManifest","Missing %s.",file);end
manifest=jsondecode(fileread(file));
end
function validateManifest(o,a,planHash,original,amendmentCode,amendmentExecution)
if string(o.plan_sha256)~=planHash || string(a.plan_sha256)~=planHash || ...
        string(o.code_config_fingerprint)~=original || ...
        string(a.original_execution.code_config_fingerprint)~=original || ...
        string(a.code_config_fingerprint)~=amendmentCode || ...
        string(a.amended_execution_fingerprint)~=amendmentExecution || ...
        ~logical(a.amendment.original_seeds_reused)
    error("generateUnifiedPhase0HSummary:ProvenanceMismatch", ...
        "Source manifests do not match the approved original/amendment provenance.");
end
end
function validateCellCheckpoint(folder,key,n,runFingerprint)
file=fullfile(folder,"checkpoints",key,"cell_complete.mat");
if ~isfile(file),error("generateUnifiedPhase0HSummary:MissingCell","Missing %s.",file);end
v=load(file,"runFingerprint","cellKey","completedTrialIDs");
if string(v.runFingerprint)~=runFingerprint || string(v.cellKey)~=key || ...
        ~isequal(v.completedTrialIDs,(1:n).')
    error("generateUnifiedPhase0HSummary:CellIdentity","Cell checkpoint mismatch: %s.",file);
end
end
function validateTrialIdentity(v,key,id,runFingerprint,file)
if string(v.runFingerprint)~=runFingerprint || string(v.cellKey)~=key || ...
        v.trialID~=id || string(v.payload.cell_key)~=key || v.payload.trial_id~=id
    error("generateUnifiedPhase0HSummary:TrialIdentity", ...
        "Trial checkpoint identity mismatch: %s.",file);
end
end
function p=postprocessingProvenance(projectFolder)
files=["generateUnifiedPhase0HSummary.m", ...
    "analyzePhase0HUnifiedTrial.m","summarizePhase0HUnifiedResults.m"];
hashes=strings(numel(files),1);
for i=1:numel(files),hashes(i)=xpsh.sha256File(fullfile(projectFolder,files(i)));end
p=struct("version","1.0.1","files",files,"file_sha256",hashes, ...
    "combined_sha256",xpsh.sha256Text(strjoin(files+":"+hashes,newline)));
end
function assertOutsideSources(outputFolder,sources)
output=canonical(outputFolder);
for source=sources
    one=canonical(source);
    if output==one || startsWith(output,one+string(filesep))
        error("generateUnifiedPhase0HSummary:ImmutableSource", ...
            "Unified output must be outside immutable source folder %s.",source);
    end
end
end
function value=canonical(path)
value=lower(string(char(java.io.File(path).getCanonicalPath())));
end
