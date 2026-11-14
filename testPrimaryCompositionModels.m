function tests = testPrimaryCompositionModels
%TESTPRIMARYCOMPOSITIONMODELS Assertive tests for mentor-approved models.

tests = functiontests(localfunctions);
end

function testMainCFPublishedFractions(testCase)
fractions = [0.47,0.37,0.19];
expectedAt = 100*fractions./(1+fractions);
for i = 1:numel(fractions)
    comp = calculate(fractions(i),10,knownScaling(1,1,1,1),ruoffProfile());
    result = comp.primary.c1s_main_cf;
    verifyEqual(testCase,result.F_over_C,fractions(i),"AbsTol",1e-12);
    verifyEqual(testCase,result.F_atpct,expectedAt(i),"AbsTol",1e-12);
    verifyEqual(testCase,result.model_id,"ruoff_c1s_main_cf_v1");
    verifyEqual(testCase,result.status,"quantitative");
end
end

function testSemiCovalentArithmeticAndExclusions(testCase)
cTotal = 100;
targetFC = 0.4;
semiArea = targetFC*3.95*cTotal;
cPeaks = makeCPeaks(cTotal,0.47);
fPeaks = makeFPeaks([999,semiArea,777],[684.7,686.8,688.2]);
fPeaks(end+1) = struct("id","F_other","center_eV",681.5, ...
    "area",888,"chemical_assignment","other_or_interface_F", ...
    "include_in_carbon_bound_F",false,"include_in_total_F",true);
comp = xps.calculateComposition(cPeaks,fPeaks,1,3.95,0, ...
    knownScaling(1,1,1,1),ruoffProfile(),modelProfile());
result = comp.primary.c1s_f1s_semi;
verifyEqual(testCase,result.F_over_C,targetFC,"AbsTol",1e-12);
verifyEqual(testCase,result.numerator_peak_ids,"F_semi");
verifyEqual(testCase,sort(result.excluded_peak_ids), ...
    sort(["F_ionic";"F_covalent";"F_other"]));
verifyGreaterThan(testCase,comp.diagnostics.total_f1s.F_over_C,targetFC);
end

function testPeakOrderAndStableLabelSelection(testCase)
cPeaks = makeCPeaks(100,0.47);
fPeaks = makeFPeaks([8,79,12],[684.7,686.8,688.2]);
baseline = xps.calculateComposition(cPeaks,fPeaks,1,3.95,0, ...
    knownScaling(1,1,1,1),ruoffProfile(),modelProfile());
shuffled = xps.calculateComposition(cPeaks([6,3,1,5,2,4]), ...
    fPeaks([3,1,2]),1,3.95,0,knownScaling(1,1,1,1), ...
    ruoffProfile(),modelProfile());
verifyEqual(testCase,shuffled.primary.c1s_main_cf.F_over_C, ...
    baseline.primary.c1s_main_cf.F_over_C,"AbsTol",1e-12);
verifyEqual(testCase,shuffled.primary.c1s_f1s_semi.F_over_C, ...
    baseline.primary.c1s_f1s_semi.F_over_C,"AbsTol",1e-12);
verifyEqual(testCase,shuffled.primary.c1s_f1s_semi.numerator_peak_ids, ...
    "F_semi");
end

function testSemiAssignmentOutsideApprovedRangeIsWithheld(testCase)
fPeaks = makeFPeaks([0,79,0],[684.7,686.6,688.2]);
comp = xps.calculateComposition(makeCPeaks(100,0.47),fPeaks,1,3.95,0, ...
    knownScaling(1,1,1,1),ruoffProfile(),modelProfile());
result = comp.primary.c1s_f1s_semi;
verifyEqual(testCase,result.status,"withheld");
verifyTrue(testCase,isnan(result.F_over_C));
verifyTrue(testCase,any(contains(result.QC.warnings,"outside approved")));
end

function testChemicalLabelRequired(testCase)
fPeaks = makeFPeaks([0,79,0],[684.7,686.8,688.2]);
fPeaks(2).chemical_assignment = "covalent_F_C";
comp = xps.calculateComposition(makeCPeaks(100,0.47),fPeaks,1,3.95,0, ...
    knownScaling(1,1,1,1),ruoffProfile(),modelProfile());
verifyEqual(testCase,comp.primary.c1s_f1s_semi.status,"withheld");
end

function testNormalizationAndAcquisitionRestoration(testCase)
physicalC = 200;
physicalF = 0.25*3.95*physicalC;
scaling1 = knownScaling(10,2,20,4); % both multipliers are 5
c1 = makeCPeaks(physicalC/5,0.47);
f1 = makeFPeaks([0,physicalF/5,0],[684.7,686.8,688.2]);
comp1 = xps.calculateComposition(c1,f1,1,3.95,0,scaling1, ...
    ruoffProfile(),modelProfile());

scaling2 = knownScaling(7,1,21,3); % both multipliers are 7
c2 = makeCPeaks(physicalC/7,0.47);
f2 = makeFPeaks([0,physicalF/7,0],[684.7,686.8,688.2]);
comp2 = xps.calculateComposition(c2,f2,1,3.95,0,scaling2, ...
    ruoffProfile(),modelProfile());
verifyEqual(testCase,comp1.primary.c1s_f1s_semi.F_over_C,0.25, ...
    "AbsTol",1e-12);
verifyEqual(testCase,comp2.primary.c1s_f1s_semi.F_over_C,0.25, ...
    "AbsTol",1e-12);
verifyEqual(testCase,comp1.primary.c1s_f1s_semi.F_over_C, ...
    comp2.primary.c1s_f1s_semi.F_over_C,"AbsTol",1e-12);
end

function testUnknownAcquisitionWithholdsCrossRegionOnly(testCase)
scaling = knownScaling(2,1,3,1);
scaling.F1s.acquisitionScaleKnown = false;
scaling.F1s.acquisitionScale = NaN;
comp = calculate(0.47,79,scaling,ruoffProfile());
verifyEqual(testCase,comp.primary.c1s_main_cf.status,"quantitative");
verifyEqual(testCase,comp.primary.c1s_f1s_semi.status,"withheld");
verifyTrue(testCase,isnan(comp.primary.c1s_f1s_semi.F_over_C));
verifyTrue(testCase,contains( ...
    comp.primary.c1s_f1s_semi.acquisition_scaling.status, ...
    "not physically validated"));
end

function testSensitivityProfilesAreDistinctAndPropagated(testCase)
ruoff = ruoffProfile();
thermo = thermoProfile();
scaling = knownScaling(1,1,1,1);
cPeaks = makeCPeaks(100,0.47);
fPeaks = makeFPeaks([0,100,0],[684.7,686.8,688.2]);
r1 = xps.calculateComposition(cPeaks,fPeaks,ruoff.S_C,ruoff.S_F,0, ...
    scaling,ruoff,modelProfile());
r2 = xps.calculateComposition(cPeaks,fPeaks,thermo.S_C,thermo.S_F,0, ...
    scaling,thermo,modelProfile());
verifyNotEqual(testCase,r1.primary.c1s_f1s_semi.F_over_C, ...
    r2.primary.c1s_f1s_semi.F_over_C);
verifyEqual(testCase,r1.primary.c1s_f1s_semi.sensitivity_factors.profile_id, ...
    "ruoff_reproduction_sf3p95_v1");
verifyEqual(testCase,r2.primary.c1s_f1s_semi.sensitivity_factors.profile_id, ...
    "thermo_k_alpha_sf4p118_v1");
verifyError(testCase,@() xps.calculateComposition(cPeaks,fPeaks,1,4.118, ...
    0,scaling,ruoff,modelProfile()), ...
    "xps:calculateComposition:SensitivityProfileMismatch");
end

function testStandardResultSchemaAndDeprecatedAliases(testCase)
comp = calculate(0.47,79,knownScaling(1,1,1,1),ruoffProfile());
required = ["model_id","model_version","status","equation_id", ...
    "equation_text","numerator_peak_ids","numerator_chemical_labels", ...
    "denominator_definition","normalization_restoration", ...
    "acquisition_scaling","sensitivity_factors","F_over_C","F_atpct", ...
    "C_over_F","CxF","uncertainty","QC"];
result = comp.primary.c1s_f1s_semi;
for field = required
    verifyTrue(testCase,isfield(result,field),"Missing schema field: " + field);
end

verifyEqual(testCase,result.uncertainty.status,"not_estimated");
verifyEqual(testCase,comp.weighted.F_over_C, ...
    comp.diagnostics.weighted_c1s.F_over_C,"AbsTol",0);
verifyEqual(testCase,comp.carbonBound.F_over_C, ...
    comp.diagnostics.carbon_bound_f1s_previous.F_over_C,"AbsTol",0);
verifyEqual(testCase,comp.deprecated_aliases.weighted, ...
    "diagnostics.weighted_c1s");
end

function testExampleReportsPreserveProfileProvenance(testCase)
report = runCompositionModelExamples;
verifyEqual(testCase,height(report.summary),2);
verifyEqual(testCase,report.summary.SensitivityProfileID, ...
    ["ruoff_reproduction_sf3p95_v1";"thermo_k_alpha_sf4p118_v1"]);
for i = 1:2
    result = report.compositions{i}.primary.c1s_f1s_semi;
    verifyEqual(testCase,result.sensitivity_factors.profile_id, ...
        report.summary.SensitivityProfileID(i));
    verifyNotEmpty(testCase,result.sensitivity_factors.source_provenance);
    verifyNotEmpty(testCase,result.sensitivity_factors.intended_application);
end
end

function comp = calculate(mainFraction,semiArea,scaling,profile)
comp = xps.calculateComposition(makeCPeaks(100,mainFraction), ...
    makeFPeaks([0,semiArea,0],[684.7,686.8,688.2]), ...
    profile.S_C,profile.S_F,0,scaling,profile,modelProfile());
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

function peaks = makeFPeaks(areas,centers)
peaks = struct("id",{"F_ionic","F_semi","F_covalent"}, ...
    "center_eV",num2cell(centers),"area",num2cell(areas), ...
    "chemical_assignment",{"ionic_or_substrate_bound_F", ...
        "semi_covalent_F_C","covalent_F_C"}, ...
    "include_in_carbon_bound_F",{false,true,true}, ...
    "include_in_total_F",{true,true,true});
end

function scaling = knownScaling(cSoftware,cAcquisition,fSoftware,fAcquisition)
scaling.C1s = struct("softwareNormalizationScale",cSoftware, ...
    "acquisitionScaleKnown",true,"acquisitionScale",cAcquisition);
scaling.F1s = struct("softwareNormalizationScale",fSoftware, ...
    "acquisitionScaleKnown",true,"acquisitionScale",fAcquisition);
end

function profile = ruoffProfile
profile = xps.loadSensitivityProfile(fullfile(projectFolder,"config", ...
    "sensitivity","ruoff_reproduction_sf3p95_v1.json"));
end

function profile = thermoProfile
profile = xps.loadSensitivityProfile(fullfile(projectFolder,"config", ...
    "sensitivity","thermo_k_alpha_sf4p118_v1.json"));
end

function profile = modelProfile
profile = xps.loadCompositionModelProfile(fullfile(projectFolder,"config", ...
    "composition","ruoff_primary_models_v1.json"));
end

function folder = projectFolder
folder = fileparts(mfilename("fullpath"));
end
