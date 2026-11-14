function manifest = createPhase0HExtensionManifest(plan,projectFolder,runMode)
%CREATEPHASE0HEXTENSIONMANIFEST Provenance for the isolated 101:400 run.

arguments
    plan (1,1) struct
    projectFolder (1,1) string
    runMode (1,1) string {mustBeMember(runMode, ...
        ["extension","extension_dry_run","extension_smoke"])}
end
expectedPlan="1f932b278de41dc14154191833f45b5fcf55f3b5a01edd7a661ddcbcf2f556bf";
expectedOriginal="93c6ad3a88ba0245be2043c06ca20c0adb62033989f051a6e71e340d31e292b4";
expectedAmended="60ddb98176b263595a54ae115980c96dcb7e696dc64e2cd05b759aef2e2a55e6";
expectedAmendedCode="e0173d6d25ebd30e2c1ac02054e4a29568d0a9038b0c4ea815fddcd272293845";

original=jsondecode(fileread(fullfile(projectFolder,"results", ...
    "phase0h_formal_v1_0_0","manifest.json")));
amendment=jsondecode(fileread(fullfile(projectFolder,"results", ...
    "phase0h_execution_amendment_v1_0_1","manifest.json")));
unified=jsondecode(fileread(fullfile(projectFolder,"results", ...
    "phase0h_unified_v1_0_1","unified_provenance.json")));
if string(original.plan_sha256)~=expectedPlan || ...
        string(original.code_config_fingerprint)~=expectedOriginal || ...
        string(amendment.amended_execution_fingerprint)~=expectedAmended || ...
        string(amendment.code_config_fingerprint)~=expectedAmendedCode || ...
        ~logical(unified.provenance_validation_passed) || ...
        ~logical(unified.all_cells_have_100_trials) || ...
        ~logical(unified.all_trials_usable)
    error("createPhase0HExtensionManifest:ParentProvenance", ...
        "Frozen plan, parent executions, or accepted unified provenance mismatch.");
end
% Confirm that the current execution dependencies still reproduce the
% approved v1.0.1 amendment core fingerprint before extending it.
amendmentPlan=xpsh.buildAmendmentPlan(projectFolder);
currentCore=xpsh.createAmendmentManifest(amendmentPlan,projectFolder,"amendment");
if string(currentCore.code_config_fingerprint)~=expectedAmendedCode || ...
        string(currentCore.amended_execution_fingerprint)~=expectedAmended
    error("createPhase0HExtensionManifest:CoreFingerprintChanged", ...
        "Current production/harness core differs from approved v1.0.1.");
end

executionFiles=[ ...
    "buildPhase0HExtensionPlan.m";
    "phase0HExtensionSeedSchedule.m";
    "createPhase0HExtensionManifest.m";
    "preparePhase0HExtensionRun.m";
    "executePhase0HExtensionPlan.m";
    "writePhase0HExtensionCellCheckpoint.m";
    "inspectPhase0HExtensionRun.m";
    "phase0HResultIntegritySnapshot.m";
    "getPhase0HExtensionStatus.m";
    "runPhase0HExtension.m"];
records=repmat(struct("path","","sha256",""),numel(executionFiles),1);
for i=1:numel(executionFiles)
    file=fullfile(projectFolder,executionFiles(i));
    if ~isfile(file)
        error("createPhase0HExtensionManifest:MissingExecutionFile", ...
            "Missing extension execution file %s.",executionFiles(i));
    end
    records(i)=struct("path",executionFiles(i),"sha256",xpsh.sha256File(file));
end
lines=string({records.path}).'+":"+string({records.sha256}).';
extensionCodeHash=xpsh.sha256Text(strjoin(lines,newline));
cellKeys=string({plan.cells.cell_key}).';
executionFingerprint=xpsh.sha256Text(strjoin([ ...
    "extension_version:"+plan.extension_version;
    "plan_sha256:"+expectedPlan;
    "amended_execution_fingerprint:"+expectedAmended;
    "extension_code_sha256:"+extensionCodeHash;
    "selection_sha256:"+plan.selected_cell_sha256;
    "seed_namespace:"+plan.seed_namespace;
    "trial_range:101-400";
    "cells:"+strjoin(cellKeys,",")],newline));

manifest=struct();
manifest.manifest_id="phase0h_borderline_extension_manifest";
manifest.manifest_version="1.0.0";
manifest.run_mode=runMode;
manifest.status=statusFor(runMode);
manifest.generated_at=string(datetime("now","TimeZone","America/Chicago", ...
    "Format","yyyy-MM-dd'T'HH:mm:ssXXX"));
manifest.plan_id=plan.plan_id;manifest.plan_version=plan.plan_version;
manifest.plan_sha256=expectedPlan;
manifest.extension_id=plan.extension_id;
manifest.extension_version=plan.extension_version;
manifest.cell_count=plan.cell_count;
manifest.extension_first_trial=plan.first_trial_id;
manifest.extension_last_trial=plan.last_trial_id;
manifest.extension_trials_per_cell=plan.trials_per_cell_added;
manifest.extension_trial_count=plan.new_trial_count;
manifest.expected_optimizer_invocations=plan.expected_optimizer_invocations;
manifest.seed_namespace=plan.seed_namespace;
manifest.seed_namespace_definition=plan.seed_namespace_definition;
manifest.seed_formula=plan.seed_formula;
manifest.selected_cells=cellKeys;
manifest.selection_source="results/phase0h_unified_v1_0_1/borderline_extension_cells.csv";
manifest.selection_source_sha256=plan.selection_source_sha256;
manifest.selected_cell_sha256=plan.selected_cell_sha256;
manifest.execution_files=records;
manifest.parent_core_code_config_fingerprint=expectedAmendedCode;
manifest.extension_code_sha256=extensionCodeHash;
manifest.extension_execution_fingerprint=executionFingerprint;
manifest.run_fingerprint=expectedPlan+":"+executionFingerprint;
manifest.execution=struct("plotting_enabled",false, ...
    "default_figure_visibility","off", ...
    "checkpoint_frequency","after every trial and completed cell", ...
    "trial_range","101-400 only");
manifest.parent_results=struct( ...
    "original_execution_fingerprint",expectedOriginal, ...
    "amended_execution_fingerprint",expectedAmended, ...
    "accepted_unified_provenance_sha256",xpsh.sha256File(fullfile( ...
        projectFolder,"results","phase0h_unified_v1_0_1","unified_provenance.json")), ...
    "accepted_unified_summary_sha256",xpsh.sha256File(fullfile( ...
        projectFolder,"results","phase0h_unified_v1_0_1","phase0h_unified_summary.mat")), ...
    "immutable",true);
manifest.final_analysis_policy=struct( ...
    "extended_cells_N",400,"unextended_cells_N",100, ...
    "observed_rates_are_gates",true,"wilson_intervals_are_uncertainty_only",true, ...
    "thresholds_unchanged",true);
end

function value=statusFor(mode)
if mode=="extension",value="approved_extension_execution";
elseif mode=="extension_smoke",value="smoke_only_excluded_from_phase0h_statistics";
else,value="dry_run_only_no_extension_trials";end
end
