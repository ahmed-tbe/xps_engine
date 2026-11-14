function plan = buildPlan(projectFolder)
%BUILDPLAN Enumerate the frozen Phase 0H v1.0.0 cell inventory.
%
% This is an executable representation of the frozen design. It schedules
% work but never calls an optimizer.

arguments
    projectFolder (1,1) string = string(fileparts(fileparts(mfilename("fullpath"))))
end

plan.plan_id = "phase_0h_robustness_plan";
plan.plan_version = "1.0.0";
plan.plan_document = fullfile(projectFolder,"PHASE_0H_TEST_PLAN_v1.0.0.md");
plan.lock_file = fullfile(projectFolder,"PHASE_0H_PLAN_LOCK_v1.0.0.json");
plan.trials_per_cell = 100;
plan.seed_formula = ...
    "100000000*familyID + 100000*cellIndex + 100*trialID + streamID";
plan.combined_family_id = 16;
plan.combined_family_id_note = [ ...
    "The frozen plan numbers independent families 1-15 but leaves the " + ...
    "combined set unnumbered; the harness assigns the next unused ID, 16, " + ...
    "for deterministic seed keys without changing any scenario."];
plan.stream_ids = struct("C_noise",1,"F_noise",2,"C_center",11, ...
    "F_center",12,"C_area",21,"F_area",22,"C_width",31, ...
    "F_width",32,"C_order",41,"F_order",42, ...
    "C_acquisition",51,"F_acquisition",52,"charging_shift",61);

cells = repmat(cellTemplate(),0,1);

% Family 1: noise.
snrs = [100,50,20]; gates = ["A","A","B"];
for i = 1:3
    s = defaultSettings(); s.snr = snrs(i);
    cells = addCell(cells,1,"Noise",i,"N"+i,gates(i),1,1,true,s, ...
        compose("PeakSNR %g",snrs(i)));
end

% Family 2: initial conditions and multi-start.
modes = ["moderate","broad","broad","broad"];
starts = [1,1,5,10]; gates = ["A","B","A","A"];
for i = 1:4
    s = defaultSettings(); s.snr = 50; s.start_mode = modes(i);
    cells = addCell(cells,2,"InitialConditions",i,"I"+i,gates(i), ...
        starts(i),1,true,s,compose("%s starts, %d replicate(s)", ...
        modes(i),starts(i)));
end

% Family 3: paired canonical/permuted fits.
snrs = [Inf,50]; gates = ["Order","A"];
for i = 1:2
    s = defaultSettings(); s.snr = snrs(i); s.permute_fit_order = true;
    cells = addCell(cells,3,"PeakOrder",i,"O"+i,gates(i),1,2,true,s, ...
        "paired canonical and independently permuted configurations");
end

% Family 4: overlap.
for i = 1:4
    s = defaultSettings(); s.snr = 50; s.use_overlap_test_bounds = true;
    if i <= 2
        factors = [0.75,0.50];
        s.center_offset_factor = factors(i);
        description = compose("cluster-center offset factor %.2f", ...
            s.center_offset_factor);
    else
        widths = [1.0,1.4];
        s.fwhm_override_eV = widths(i-2);
        description = compose("all truth FWHM %.1f eV",s.fwhm_override_eV);
    end
    cells = addCell(cells,4,"Overlap",i,"V"+i,"B",1,1,true,s,description);
end

% Family 5: zero, omitted, extra, and unmodelled peaks.
cIDs = ["sp2_C_C","C_CF_sp3","C_F","C_CF23_C_O","CF2","CF3"];
fIDs = ["F_ionic","F_semi_covalent","F_covalent"];
targets = [compose("C1s:%s",cIDs),compose("F1s:%s",fIDs)];
idx = 0;
for i = 1:numel(targets)
    idx = idx+1; s = defaultSettings(); s.snr = 50;
    s.zero_truth_target = targets(i);
    cells = addCell(cells,5,"MissingUnnecessaryPeaks",idx, ...
        "S1_zero_"+safeID(targets(i)),"C",1,1,true,s, ...
        "zero truth area while retaining fitted component");
end
for i = 1:numel(targets)
    idx = idx+1; s = defaultSettings(); s.snr = 50;
    s.omit_fit_target = targets(i);
    cells = addCell(cells,5,"MissingUnnecessaryPeaks",idx, ...
        "S2_omit_"+safeID(targets(i)),"C",1,1,true,s, ...
        "omit fitted component while retaining truth");
end
for region = ["C1s","F1s"]
    idx = idx+1; s = defaultSettings(); s.snr = 50;
    s.add_zero_truth_fit_region = region;
    cells = addCell(cells,5,"MissingUnnecessaryPeaks",idx, ...
        "S3_extra_fit_"+region,"C",1,1,true,s, ...
        "add zero-truth fitted component");
end
idx = idx+1; s = defaultSettings(); s.snr = 50;
s.unmodelled_C_fraction = 0.05;
cells = addCell(cells,5,"MissingUnnecessaryPeaks",idx,"S4_unmodelled_C", ...
    "C",1,1,true,s,"unmodelled C1s peak at 286.25 eV");
for fraction = [0.01,0.05,0.10]
    idx = idx+1; s = defaultSettings(); s.snr = 50;
    s.F_other_fraction = fraction; s.extend_F_window_low_eV = 679;
    cells = addCell(cells,5,"MissingUnnecessaryPeaks",idx, ...
        compose("S5_F_other_%02d",round(100*fraction)),"C",1,1,true,s, ...
        compose("unmodelled F_other at 681.5 eV, %.0f%% total F",100*fraction));
end

% Family 6: shape mismatch.
etas = [0.2,0.5,0.8]; gates = ["A","B","B"];
for i = 1:3
    s = defaultSettings(); s.snr = 50; s.pseudo_voigt_eta = etas(i);
    cells = addCell(cells,6,"PeakShape",i,"P"+i,gates(i),1,1,true,s, ...
        compose("pseudo-Voigt truth eta %.1f; Gaussian fit",etas(i)));
end

% Family 7: background truth/recovery combinations.
truth = ["linear","shirley","tougaard","shirley","tougaard", ...
    "quadratic","zero"];
fit = ["linear","shirley","tougaard","linear","linear","linear","asls"];
gates = ["A","A","A","C","C","C","C"];
for i = 1:7
    s = defaultSettings(); s.snr = 50;
    s.background_truth = truth(i); s.background_fit = fit(i);
    cells = addCell(cells,7,"Background",i,"B"+i,gates(i),1,1,true,s, ...
        truth(i)+" truth -> "+fit(i)+" preprocessing");
end

% Family 8: window truncation.
idx = 0;
for edge = ["low","high","both"]
    for amount = [0.5,1.0,2.0]
        idx = idx+1; s = defaultSettings(); s.snr = 50;
        s.trim_edge = edge; s.trim_eV = amount;
        cells = addCell(cells,8,"WindowTruncation",idx, ...
            compose("T_%s_%.1f",edge,amount),"B",1,1,true,s, ...
            compose("trim %.1f eV from %s edge(s)",amount,edge));
    end
end

% Family 9: exact/unknown scale controls.
for i = 1:3
    s = defaultSettings();
    if i == 1, s.scale_mode = "random_exact"; gate = "Scale";
    elseif i == 2, s.scale_mode = "random_exact_file_units"; gate = "Scale";
    else, s.scale_mode = "unknown_cycle"; gate = "C";
    end
    cells = addCell(cells,9,"ScaleControls",i,"Q"+i,gate,1,1,true,s, ...
        s.scale_mode);
end

% Family 10: common charging shifts.
ranges = [0.25,0.50]; gates = ["A","B"];
for i = 1:2
    s = defaultSettings(); s.snr = 50; s.start_mode = "moderate";
    s.charging_half_range_eV = ranges(i);
    cells = addCell(cells,10,"ChargingShift",i,"G"+i,gates(i),1,1,true,s, ...
        compose("common U(-%.2f,%.2f) eV shift",ranges(i),ranges(i)));
end

% Family 11: deliberately erroneous supplied acquisition factors.
regions = ["F1s","F1s","C1s","C1s","both","both"];
multipliers = [0.90,1.10,0.90,1.10,0.90,1.10];
for i = 1:6
    s = defaultSettings(); s.scale_mode = "supplied_error";
    s.acquisition_error_region = regions(i);
    s.acquisition_error_multiplier = multipliers(i);
    cells = addCell(cells,11,"AcquisitionScaleError",i,"E"+i,"C", ...
        1,1,true,s,compose("%s supplied scale x %.2f",regions(i),multipliers(i)));
end

% Family 12: composition-only sensitivity sweeps.
multipliers = [0.90,0.95,1.00,1.05,1.10];
idx = 0;
for base = ["ruoff_reproduction_sf3p95_v1","thermo_k_alpha_sf4p118_v1"]
    prefix = "R"; if startsWith(base,"thermo"),prefix = "T";end
    for i = 1:5
        idx = idx+1; s = defaultSettings();
        s.sensitivity_base_profile = base;
        s.sensitivity_multiplier = multipliers(i);
        gate = "C_descriptive"; if i == 3,gate = "Scale";end
        cells = addCell(cells,12,"SensitivitySweep",idx,prefix+i,gate, ...
            0,0,false,s,compose("%s S_F multiplier %.2f",base,multipliers(i)));
    end
end

% Family 13: post-fit chemical-label mutations.
mutations = ["swap_semi_ionic","swap_semi_covalent", ...
    "remove_semi","duplicate_semi"];
for i = 1:4
    s = defaultSettings(); s.label_mutation = mutations(i);
    s.permute_fit_order = true;
    cells = addCell(cells,13,"LabelMisclassification",i,"L"+i,"C", ...
        1,1,true,s,mutations(i));
end

% Family 14: substrate-related extra peaks and shoulders.
centers = [684.0,684.0,685.8,685.8];
fractions = [0.02,0.10,0.02,0.05];
types = ["substrate","substrate","shoulder","shoulder"];
for i = 1:4
    s = defaultSettings(); s.snr = 50;
    s.extra_F_center_eV = centers(i); s.extra_F_fraction = fractions(i);
    s.extra_F_type = types(i);
    cells = addCell(cells,14,"SubstrateShoulder",i,"X"+i,"C",1,1,true,s, ...
        compose("%s %.1f eV at %.0f%% total F",types(i),centers(i),100*fractions(i)));
end

% Family 15: paired baseline/widened-bound fits.
variants = ["center","fwhm","center_and_fwhm_overlap_v2"];
gates = ["A_paired","A_paired","B_paired"];
for i = 1:3
    s = defaultSettings(); s.snr = 50; s.bound_variant = variants(i);
    if i == 3
        s.center_offset_factor = 0.50;
        s.use_overlap_test_bounds = true;
    end
    cells = addCell(cells,15,"BoundSensitivity",i,"W"+i,gates(i), ...
        1,2,true,s,variants(i));
end

% Family 16: four frozen combined-stress cells.
for i = 1:4
    s = defaultSettings();
    if i == 1
        s.snr=50; s.start_mode="moderate"; s.center_offset_factor=0.75;
        s.use_overlap_test_bounds=true;
        s.pseudo_voigt_eta=0.2; s.background_truth="linear";
        s.background_fit="linear"; s.trim_edge="both"; s.trim_eV=0.5;
        starts=5; gate="B";
    elseif i == 2
        s.snr=20; s.start_mode="broad"; s.center_offset_factor=0.50;
        s.use_overlap_test_bounds=true;
        s.pseudo_voigt_eta=0.5; s.background_truth="shirley";
        s.background_fit="shirley"; s.trim_edge="both"; s.trim_eV=1.0;
        starts=10; gate="B";
    elseif i == 3
        s.snr=20; s.start_mode="broad"; s.fwhm_override_eV=1.4;
        s.pseudo_voigt_eta=0.5; s.background_truth="tougaard";
        s.background_fit="linear"; s.trim_edge="low"; s.trim_eV=1.0;
        s.F_other_fraction=0.05; s.extend_F_window_low_eV=679;
        starts=10; gate="C";
    else
        s.snr=50; s.start_mode="broad"; s.pseudo_voigt_eta=0.8;
        s.background_truth="quadratic"; s.background_fit="linear";
        s.trim_edge="high"; s.trim_eV=2.0;
        s.omit_fit_target="C1s:CF3";
        s.add_zero_truth_fit_region="C1s";
        starts=10; gate="C";
    end
    cells = addCell(cells,16,"CombinedStress",i,"C"+i,gate,starts,1,true,s, ...
        "frozen combined-stress scenario C"+i);
end

plan.cells = cells;
plan.cell_count = numel(cells);
plan.initial_trial_count = sum([cells.trials]);
plan.expected_optimizer_invocations = sum( ...
    [cells.trials].*[cells.optimizer_invocations_per_trial]);
plan.optimizer_count_definition = [ ...
    "One optimizer invocation is one regional xps.fitSpectrum call. " + ...
    "Standard trials use two regions; order/bound cells run paired pipelines; " + ...
    "family 12 is composition-only; combined cells retain 5/10 starts."];

assert(plan.cell_count == 92,"xpsh:buildPlan:CellCount", ...
    "Frozen plan must enumerate 92 cells.");
assert(plan.initial_trial_count == 9200,"xpsh:buildPlan:TrialCount", ...
    "Frozen plan must enumerate 9,200 initial trials.");
assert(plan.expected_optimizer_invocations == 26200, ...
    "xpsh:buildPlan:OptimizerCount", ...
    "Frozen execution topology must schedule 26,200 optimizer invocations.");
end

function cells = addCell(cells,familyID,familyName,cellIndex,cellID,gate, ...
        starts,pipelines,fitRequired,settings,description)
entry = cellTemplate();
entry.family_id = familyID;
entry.family_name = string(familyName);
entry.cell_index = cellIndex;
entry.cell_id = string(cellID);
entry.cell_key = compose("F%02d_%s",familyID,cellID);
entry.gate = string(gate);
entry.trials = 100;
entry.starts = starts;
entry.pipelines_per_trial = pipelines;
entry.fit_required = logical(fitRequired);
entry.regions_per_pipeline = 2*double(fitRequired);
entry.optimizer_invocations_per_trial = ...
    entry.regions_per_pipeline*starts*pipelines;
entry.settings = settings;
entry.description = string(description);
cells(end+1,1) = entry;
end

function entry = cellTemplate
entry = struct("family_id",0,"family_name","","cell_index",0, ...
    "cell_id","","cell_key","","gate","","trials",100, ...
    "starts",1,"pipelines_per_trial",1,"fit_required",true, ...
    "regions_per_pipeline",2,"optimizer_invocations_per_trial",2, ...
    "settings",struct(),"description","");
end

function s = defaultSettings
s = struct("snr",Inf,"start_mode","production", ...
    "permute_fit_order",false,"center_offset_factor",1, ...
    "fwhm_override_eV",NaN,"use_overlap_test_bounds",false, ...
    "zero_truth_target","","omit_fit_target","", ...
    "add_zero_truth_fit_region","","unmodelled_C_fraction",0, ...
    "F_other_fraction",0,"extend_F_window_low_eV",NaN, ...
    "pseudo_voigt_eta",0,"background_truth","zero", ...
    "background_fit","linear","trim_edge","none","trim_eV",0, ...
    "scale_mode","locked","charging_half_range_eV",0, ...
    "acquisition_error_region","", ...
    "acquisition_error_multiplier",1, ...
    "sensitivity_base_profile","ruoff_reproduction_sf3p95_v1", ...
    "sensitivity_multiplier",1,"label_mutation","none", ...
    "extra_F_center_eV",NaN,"extra_F_fraction",0, ...
    "extra_F_type","none","bound_variant","none");
end

function value = safeID(value)
value = replace(string(value),[":","/"," ","."],"_");
end
