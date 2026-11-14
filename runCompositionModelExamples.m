function report = runCompositionModelExamples
%RUNCOMPOSITIONMODELEXAMPLES Show explicit sensitivity-profile selection.
%
% Uses the Sample A source-level benchmark areas only to demonstrate the
% composition API. It does not fit spectra and does not tune either factor.

projectFolder = fileparts(mfilename("fullpath"));
reference = xps.loadReference(fullfile(projectFolder,"reference", ...
    "sample_A_ruoff_v1.json"));
modelProfile = xps.loadCompositionModelProfile(fullfile(projectFolder, ...
    "config","composition","ruoff_primary_models_v1.json"));
profileFiles = ["ruoff_reproduction_sf3p95_v1.json"; ...
    "thermo_k_alpha_sf4p118_v1.json"];

cPeaks = makeCPeaks(reference.project_benchmark_inputs.total_C1s_area, ...
    reference.direct_references.main_C_F_fraction.fraction);
fPeaks = makeFPeaks(reference.project_benchmark_inputs.semi_covalent_F1s_area);
scaling = unitScaling();

profileID = strings(numel(profileFiles),1);
profileStatus = strings(numel(profileFiles),1);
intendedApplication = strings(numel(profileFiles),1);
compositionRecords = cell(numel(profileFiles),1);
SC = nan(numel(profileFiles),1);
SF = nan(numel(profileFiles),1);
F_over_C = nan(numel(profileFiles),1);
F_atpct = nan(numel(profileFiles),1);
benchmarkReferenceSet = repmat("ruoff_c1s_f1s_semi_sf3p95_v1", ...
    numel(profileFiles),1);
benchmarkReference = repmat("32% (Sample A scalar reference)", ...
    numel(profileFiles),1);

for i = 1:numel(profileFiles)
    profile = xps.loadSensitivityProfile(fullfile(projectFolder,"config", ...
        "sensitivity",profileFiles(i)));
    comp = xps.calculateComposition(cPeaks,fPeaks,profile.S_C,profile.S_F, ...
        0,scaling,profile,modelProfile);
    result = comp.primary.c1s_f1s_semi;
    profileID(i) = result.sensitivity_factors.profile_id;
    profileStatus(i) = result.sensitivity_factors.status;
    intendedApplication(i) = result.sensitivity_factors.intended_application;
    SC(i) = profile.S_C;
    SF(i) = profile.S_F;
    F_over_C(i) = result.F_over_C;
    F_atpct(i) = result.F_atpct;
    compositionRecords{i} = comp;
end

summary = table(profileID,profileStatus,SC,SF,F_over_C,F_atpct, ...
    benchmarkReferenceSet,benchmarkReference,intendedApplication, ...
    VariableNames=["SensitivityProfileID", ...
    "ProfileStatus","S_C","S_F","F_over_C","F_atpct", ...
    "BenchmarkReferenceSet","BenchmarkReference","IntendedApplication"]);
fprintf("Composition profile example using fixed Sample A benchmark areas\n");
fprintf("No spectrum fitting or sensitivity-factor tuning is performed.\n");
disp(summary);
report = struct("report_id","composition_profile_examples_v1", ...
    "status","deterministic_reference_arithmetic_only", ...
    "source_reference_id",string(reference.reference_id), ...
    "composition_model_profile_id",string(modelProfile.profile_id), ...
    "summary",summary,"compositions",{compositionRecords});
end

function peaks = makeCPeaks(totalArea,mainFraction)
ids = ["sp2_C_C","C_CF_sp3","C_CF23_C_O","C_F","CF2","CF3"];
areas = [totalArea*(1-mainFraction),0,0,totalArea*mainFraction,0,0];
peaks = repmat(struct("id","","area",0),1,numel(ids));
for i = 1:numel(ids)
    peaks(i).id = ids(i);
    peaks(i).area = areas(i);
end
end

function peaks = makeFPeaks(semiArea)
peaks = struct("id",{"F_ionic","F_semi","F_covalent"}, ...
    "center_eV",{684.7,686.8,688.2},"area",{0,semiArea,0}, ...
    "chemical_assignment",{"ionic_or_substrate_bound_F", ...
        "semi_covalent_F_C","covalent_F_C"}, ...
    "include_in_carbon_bound_F",{false,true,true}, ...
    "include_in_total_F",{true,true,true});
end

function scaling = unitScaling
region = struct("softwareNormalizationScale",1, ...
    "acquisitionScaleKnown",true,"acquisitionScale",1);
scaling = struct("C1s",region,"F1s",region);
end
