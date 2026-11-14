function summary = validateRuoffBenchmarkFixtures
%VALIDATERUOFFBENCHMARKFIXTURES Validate model-specific A-C references.
%
% This performs reference arithmetic only. It does not fit spectra, supply
% targets to an optimizer, or tune a composition equation.

projectFolder = fileparts(mfilename("fullpath"));
modelProfile = xps.loadCompositionModelProfile(fullfile(projectFolder, ...
    "config","composition","ruoff_primary_models_v1.json"));
sfProfile = xps.loadSensitivityProfile(fullfile(projectFolder, ...
    "config","sensitivity","ruoff_reproduction_sf3p95_v1.json"));

sampleIDs = ["A";"B";"C"];
n = numel(sampleIDs);
mainReferenceType = strings(n,1);
mainReferenceDisplay = strings(n,1);
mainReferenceLower = nan(n,1);
mainReferenceUpper = nan(n,1);
mainReferenceProvenance = strings(n,1);
mainFC = nan(n,1);
mainFAt = nan(n,1);
mainDifference = nan(n,1);
semiReferenceType = strings(n,1);
semiReferenceDisplay = strings(n,1);
semiReferenceLower = nan(n,1);
semiReferenceUpper = nan(n,1);
semiReferenceProvenance = strings(n,1);
semiFC = nan(n,1);
semiFAt = nan(n,1);
semiDifference = nan(n,1);

for i = 1:n
    sampleID = sampleIDs(i);
    reference = xps.loadReference(fullfile(projectFolder,"reference", ...
        "sample_" + sampleID + "_ruoff_v1.json"));
    cTotal = reference.project_benchmark_inputs.total_C1s_area;
    cFraction = reference.direct_references.main_C_F_fraction.fraction;
    fSemi = reference.project_benchmark_inputs.semi_covalent_F1s_area;
    comp = xps.calculateComposition(makeCPeaks(cTotal,cFraction), ...
        makeFPeaks(fSemi),sfProfile.S_C,sfProfile.S_F,0, ...
        knownReferenceAreaScaling(reference),sfProfile,modelProfile);

    refs = reference.direct_references. ...
        model_specific_fluorine_atomic_percent;
    mainRef = refs.ruoff_c1s_main_cf_v1;
    semiRef = refs.ruoff_c1s_f1s_semi_sf3p95_v1;
    [mainReferenceType(i),mainReferenceDisplay(i), ...
        mainReferenceLower(i),mainReferenceUpper(i)] = referenceValues(mainRef);
    [semiReferenceType(i),semiReferenceDisplay(i), ...
        semiReferenceLower(i),semiReferenceUpper(i)] = referenceValues(semiRef);
    mainReferenceProvenance(i) = string(mainRef.provenance);
    semiReferenceProvenance(i) = string(semiRef.provenance);

    mainFC(i) = comp.primary.c1s_main_cf.F_over_C;
    mainFAt(i) = comp.primary.c1s_main_cf.F_atpct;
    semiFC(i) = comp.primary.c1s_f1s_semi.F_over_C;
    semiFAt(i) = comp.primary.c1s_f1s_semi.F_atpct;
    mainDifference(i) = signedDistanceToReference( ...
        mainFAt(i),mainReferenceLower(i),mainReferenceUpper(i));
    semiDifference(i) = signedDistanceToReference( ...
        semiFAt(i),semiReferenceLower(i),semiReferenceUpper(i));

    expectedMain = reference.model_applied_to_reference. ...
        ruoff_c1s_main_cf_v1.F_atpct;
    expectedSemi = reference.model_applied_to_reference. ...
        ruoff_c1s_f1s_semi_sf3p95_v1.F_atpct;
    assert(abs(mainFAt(i)-expectedMain) < 1e-10, ...
        "Main C1s fixture arithmetic changed for Sample %s.",sampleID);
    assert(abs(semiFAt(i)-expectedSemi) < 1e-10, ...
        "Semi-covalent fixture arithmetic changed for Sample %s.",sampleID);
end

summary = table(sampleIDs,mainReferenceType,mainReferenceDisplay, ...
    mainReferenceLower,mainReferenceUpper,mainFC,mainFAt,mainDifference, ...
    semiReferenceType,semiReferenceDisplay,semiReferenceLower, ...
    semiReferenceUpper,semiFC,semiFAt,semiDifference, ...
    mainReferenceProvenance,semiReferenceProvenance, ...
    VariableNames=["SampleID","MainCF_ReferenceType", ...
    "MainCF_Reference","MainCF_ReferenceLower_pct", ...
    "MainCF_ReferenceUpper_pct","MainCF_F_over_C","MainCF_FAt_pct", ...
    "MainCF_SignedDistanceToReference_pctpt","SemiF1s_ReferenceType", ...
    "SemiF1s_Reference","SemiF1s_ReferenceLower_pct", ...
    "SemiF1s_ReferenceUpper_pct","SemiF1s_F_over_C", ...
    "SemiF1s_FAt_pct","SemiF1s_SignedDistanceToReference_pctpt", ...
    "MainCF_ReferenceProvenance","SemiF1s_ReferenceProvenance"]);

fprintf("Ruoff A-C model-specific benchmark arithmetic (no fitting)\n");
fprintf("Main-CF benchmark set: ruoff_c1s_main_cf_v1\n");
fprintf("Semi-F1s benchmark set: ruoff_c1s_f1s_semi_sf3p95_v1\n");
fprintf("Sensitivity profile for the semi-F1s calculation: %s\n", ...
    sfProfile.profile_id);
disp(summary(:,1:15));
end

function [type,displayText,lower,upper] = referenceValues(reference)
type = string(reference.reference_type);
switch type
    case "scalar"
        lower = double(reference.value);
        upper = lower;
        displayText = compose("%.4g%%",lower);
    case "range"
        lower = double(reference.lower);
        upper = double(reference.upper);
        displayText = compose("%.4g-%.4g%%",lower,upper);
    otherwise
        error("validateRuoffBenchmarkFixtures:InvalidReferenceType", ...
            "Unsupported reference type '%s'.",type);
end
end

function difference = signedDistanceToReference(value,lower,upper)
if value < lower
    difference = value-lower;
elseif value > upper
    difference = value-upper;
else
    difference = 0;
end
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

function scaling = knownReferenceAreaScaling(reference)
region = struct("softwareNormalizationScale",1, ...
    "acquisitionScaleKnown",true,"acquisitionScale",1, ...
    "acquisitionProvenance", ...
    "Fixture uses source-level restored benchmark areas from " + ...
    string(reference.provenance.benchmark_table));
scaling = struct("C1s",region,"F1s",region, ...
    "definition","fixture areas already expressed on their source benchmark scale");
end
