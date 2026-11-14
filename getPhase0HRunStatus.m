function status = getPhase0HRunStatus(outputFolder)
%GETPHASE0HRUNSTATUS Read formal Phase 0H status without modifying results.

arguments
    outputFolder (1,1) string = ""
end
projectFolder=string(fileparts(mfilename("fullpath")));
if strlength(outputFolder)==0
    outputFolder=fullfile(projectFolder,"results","phase0h_formal_v1_0_0");
end
manifestFile=fullfile(outputFolder,"manifest.json");
if ~isfile(manifestFile)
    status=struct("run_status","not_started","output_folder",outputFolder, ...
        "planned_cells",92,"completed_cells",0,"planned_trials",9200, ...
        "completed_trials",0,"error_trials",0,"remaining_trials",9200, ...
        "fingerprint_matches_current_code_config",missing);
    fprintf("Formal Phase 0H has not started: %s\n",outputFolder);
    return
end
plan=xpsh.buildPlan(projectFolder);
manifest=jsondecode(fileread(manifestFile));
current=xpsh.createManifest(plan,projectFolder,"formal");
status=xpsh.inspectRun(plan,outputFolder,manifest,string(current.run_fingerprint));
fprintf(["Formal Phase 0H status: %s; %d/%d trials; %d/%d cells; " + ...
    "errors=%d; fingerprint-match=%s.\n"],status.run_status, ...
    status.completed_trials,status.planned_trials,status.completed_cells, ...
    status.planned_cells,status.error_trials,string( ...
    status.fingerprint_matches_current_code_config));
end
