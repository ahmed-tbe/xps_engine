function plan = buildPhase0HExtensionPlan(projectFolder)
%BUILDPHASE0HEXTENSIONPLAN Build the frozen 42-cell 101:400 extension plan.
%
% Selection is read from the accepted authoritative 100-trial summary and
% checked against the exact mentor-approved key list. Scenario settings,
% gates, starts, variants, and optimizer topology come directly from the
% frozen v1.0.0 plan without modification.

arguments
    projectFolder (1,1) string = string(fileparts(mfilename("fullpath")))
end
sourceFile=fullfile(projectFolder,"results","phase0h_unified_v1_0_1", ...
    "borderline_extension_cells.csv");
if ~isfile(sourceFile)
    error("buildPhase0HExtensionPlan:MissingAcceptedSelection", ...
        "Accepted borderline selection not found: %s",sourceFile);
end
selection=readtable(sourceFile,TextType="string",VariableNamingRule="preserve");
selected=string(selection.CellKey(:));
expected=acceptedCellKeys();
if height(selection)~=42 || numel(unique(selected))~=42 || ...
        ~isequal(sort(selected),sort(expected))
    error("buildPhase0HExtensionPlan:SelectionMismatch", ...
        "Accepted extension selection must contain the exact frozen 42 cells.");
end

base=xpsh.buildPlan(projectFolder);
allKeys=string({base.cells.cell_key}).';
[present,index]=ismember(selected,allKeys);
if ~all(present)
    error("buildPhase0HExtensionPlan:UnknownCell", ...
        "Selection contains an unknown frozen-plan cell.");
end
% Preserve frozen plan order rather than CSV/report display order.
index=sort(index);
cells=base.cells(index);
for i=1:numel(cells)
    cells(i).base_trial_count=100;
    cells(i).extension_first_trial=101;
    cells(i).extension_last_trial=400;
    cells(i).extension_trials=300;
    cells(i).final_trial_count=400;
    cells(i).extension_optimizer_invocations= ...
        300*cells(i).optimizer_invocations_per_trial;
end

plan=struct();
plan.plan_id=base.plan_id;
plan.plan_version=base.plan_version;
plan.plan_document=base.plan_document;
plan.lock_file=base.lock_file;
plan.extension_id="phase0h_borderline_extension";
plan.extension_version="1.0.0";
plan.seed_namespace="phase0h_borderline_extension_v1_0_0/trials_101_400";
plan.seed_formula=base.seed_formula;
plan.seed_namespace_definition=[ ...
    "The namespace is the disjoint trial-ID domain 101-400 under the " + ...
    "frozen seed formula. Trials 1-100 remain in the initial namespace; " + ...
    "numeric seed uniqueness and zero intersection are audited explicitly."];
plan.selection_source=sourceFile;
plan.selection_source_sha256=xpsh.sha256File(sourceFile);
plan.selected_cell_sha256=xpsh.sha256Text(strjoin(string({cells.cell_key}).',newline));
plan.cells=cells;
plan.cell_count=numel(cells);
plan.trials_per_cell_added=300;
plan.first_trial_id=101;
plan.last_trial_id=400;
plan.new_trial_count=sum([cells.extension_trials]);
plan.expected_optimizer_invocations=sum([cells.extension_optimizer_invocations]);
plan.final_extended_cell_trial_count=400;
plan.unextended_cell_trial_count=100;
plan.remaining_unextended_cells=base.cell_count-plan.cell_count;
assert(plan.cell_count==42,"Extension must select exactly 42 cells.");
assert(plan.new_trial_count==12600,"Extension must add exactly 12,600 trials.");
assert(plan.expected_optimizer_invocations==40200, ...
    "Extension optimizer count must remain exactly 40,200.");
assert(plan.remaining_unextended_cells==50, ...
    "Exactly 50 cells must remain at N=100.");
end

function keys=acceptedCellKeys
keys=[ ...
    "F01_N1";"F01_N2";"F01_N3"; ...
    "F02_I1";"F02_I2";"F02_I3";"F02_I4"; ...
    "F03_O2";"F04_V2";"F04_V3"; ...
    "F05_S1_zero_C1s_sp2_C_C";"F05_S1_zero_C1s_C_CF_sp3"; ...
    "F05_S1_zero_C1s_C_F";"F05_S1_zero_C1s_C_CF23_C_O"; ...
    "F05_S1_zero_C1s_CF2";"F05_S1_zero_C1s_CF3"; ...
    "F05_S1_zero_F1s_F_ionic";"F05_S1_zero_F1s_F_semi_covalent"; ...
    "F05_S1_zero_F1s_F_covalent";"F05_S3_extra_fit_C1s"; ...
    "F05_S3_extra_fit_F1s";"F05_S4_unmodelled_C"; ...
    "F05_S5_F_other_01";"F05_S5_F_other_05"; ...
    "F06_P1";"F06_P2"; ...
    "F07_B1";"F07_B3";"F07_B5";"F07_B6";"F07_B7"; ...
    "F08_T_low_1.0";"F08_T_low_2.0";"F08_T_high_1.0";"F08_T_both_0.5"; ...
    "F10_G1";"F10_G2";"F14_X1";"F14_X2"; ...
    "F15_W1";"F15_W2";"F16_C3"];
end
