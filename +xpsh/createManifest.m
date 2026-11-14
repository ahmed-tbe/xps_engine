function manifest = createManifest(plan,projectFolder,runMode)
%CREATEMANIFEST Build a hash-addressed dry-run manifest.

arguments
    plan (1,1) struct
    projectFolder (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
    runMode (1,1) string {mustBeMember(runMode,["dry_run","formal","smoke"])} = "dry_run"
end
lock = jsondecode(fileread(plan.lock_file));
planHash = xpsh.sha256File(plan.plan_document);
if planHash ~= string(lock.sha256)
    error("xpsh:createManifest:PlanHashMismatch", ...
        "Frozen plan hash does not match its lock file.");
end

relativeFiles = [ ...
    "PHASE_0H_TEST_PLAN_v1.0.0.md";
    "PHASE_0H_PLAN_LOCK_v1.0.0.json";
    "config/test/ruoff_like_sample_A_synthetic_v1.json";
    "config/composition/ruoff_primary_models_v1.json";
    "config/sensitivity/ruoff_reproduction_sf3p95_v1.json";
    "config/sensitivity/thermo_k_alpha_sf4p118_v1.json";
    "config/sensitivity/legacy_project_sf4p4118_v1.json";
    "reference/sample_A_ruoff_v1.json";
    "reference/sample_B_ruoff_v1.json";
    "reference/sample_C_ruoff_v1.json";
    "runPhase0HFormal.m";
    "runPhase0HExecutionSmokeTest.m";
    "getPhase0HRunStatus.m";
    "generatePhase0HSummaries.m";
    "xps_backgrounds.m"];
harnessFiles = dir(fullfile(projectFolder,"+xpsh","*.m"));
productionFiles = dir(fullfile(projectFolder,"+xps","*.m"));
relativeFiles = [relativeFiles; ...
    "+xpsh/"+string({harnessFiles.name}).'; ...
    "+xps/"+string({productionFiles.name}).'];
relativeFiles = sort(unique(relativeFiles));
fileRecords = repmat(struct("path","","sha256",""),numel(relativeFiles),1);
for i = 1:numel(relativeFiles)
    fileRecords(i).path = relativeFiles(i);
    fileRecords(i).sha256 = xpsh.sha256File(fullfile(projectFolder, ...
        replace(relativeFiles(i),"/",filesep)));
end

fingerprintLines = strings(numel(fileRecords),1);
for i = 1:numel(fileRecords)
    fingerprintLines(i) = string(fileRecords(i).path)+":"+ ...
        string(fileRecords(i).sha256);
end
codeConfigFingerprint = xpsh.sha256Text(fingerprintLines);

[gitStatus,gitCommit,gitDiffHash] = gitMetadata(projectFolder);
manifest.manifest_id = "phase0h_dry_run_manifest";
manifest.manifest_version = "1.0.0";
manifest.run_mode = runMode;
if runMode == "formal"
    manifest.manifest_id = "phase0h_formal_run_manifest";
    manifest.status = "formal_execution";
elseif runMode == "smoke"
    manifest.manifest_id = "phase0h_execution_smoke_manifest";
    manifest.status = "smoke_only_excluded_from_formal_statistics";
else
    manifest.status = "dry_run_only_no_fitting";
end
manifest.generated_at = string(datetime("now","TimeZone","America/Chicago", ...
    "Format","yyyy-MM-dd'T'HH:mm:ssXXX"));
manifest.plan_id = plan.plan_id;
manifest.plan_version = plan.plan_version;
manifest.plan_sha256 = planHash;
manifest.cell_count = plan.cell_count;
manifest.initial_trials_per_cell = plan.trials_per_cell;
manifest.initial_trial_count = plan.initial_trial_count;
manifest.expected_optimizer_invocations = plan.expected_optimizer_invocations;
manifest.optimizer_count_definition = plan.optimizer_count_definition;
manifest.aggregate_trials_executed = 0;
manifest.fixture_trials_executed = 0;
manifest.fixture_generation_count = plan.cell_count;
manifest.matlab_version = string(version);
manifest.platform = string(computer);
installed = ver;
manifest.toolbox_versions = arrayfun(@(item)struct( ...
    "name",string(item.Name),"version",string(item.Version), ...
    "release",string(item.Release),"date",string(item.Date)),installed);
manifest.rng_algorithm = "twister";
manifest.seed_formula = plan.seed_formula;
manifest.git_commit = gitCommit;
manifest.git_worktree_status = gitStatus;
manifest.git_tracked_diff_sha256 = gitDiffHash;
manifest.files = fileRecords;
manifest.code_config_fingerprint = codeConfigFingerprint;
manifest.run_fingerprint = planHash+":"+codeConfigFingerprint;
manifest.execution = struct("plotting_enabled",false, ...
    "default_figure_visibility","off", ...
    "plotting_policy","optimizer trials never call plotting functions");
if runMode == "smoke"
    manifest.seed_namespace = "smoke_only_family_ids_31_32";
else
    manifest.seed_namespace = "frozen_phase0h_v1_seed_schedule";
end
end

function [status,commit,diffHash] = gitMetadata(projectFolder)
old = pwd; cleanup = onCleanup(@()cd(old)); %#ok<NASGU>
cd(projectFolder);
[ok,commitText] = system("git rev-parse HEAD");
if ok == 0,commit=string(strtrim(commitText));else,commit="unavailable";end
[ok,statusText] = system("git status --porcelain");
if ok ~= 0,status="unavailable";
elseif strlength(strtrim(statusText))==0,status="clean";
else,status="dirty";end
[ok,diffText] = system("git diff --binary HEAD");
if ok == 0,diffHash=xpsh.sha256Text(string(diffText));else,diffHash="unavailable";end
end
