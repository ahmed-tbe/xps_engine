%% TEST_0G_COMPOSITION.M — Unit tests for xps.calculateComposition
clear; clc;

fprintf('====================================================\n');
fprintf('  PHASE 0G-2: COMPOSITION CALCULATIONS UNIT TEST\n');
fprintf('====================================================\n\n');

%% Test Case 1: Synthetic C1s peak table matching pipeline schema
% Exact Peak Areas:
% sp2_C_C       : 10
% sp3           : 20
% C_F           : 40  (weight = 1  -> 40 F)
% C_CF23_C_O    : 10  (weight = 0  when alpha=0)
% CF2           : 15  (weight = 2  -> 30 F)
% CF3           : 5   (weight = 3  -> 15 F)
% Total C Area  = 100
% Ground Truth Weighted C1s F/C (alpha=0) = (40 + 0 + 2*15 + 3*5) / 100 = 85 / 100 = 0.850000

C_peaks = struct(...
    'id',     {"sp2_C_C", "sp3", "C_F", "C_CF23_C_O", "CF2", "CF3"}, ...
    'name',   {"sp2", "sp3", "C-CF", "C-CF2,3", "CF2", "CF3"}, ...
    'center', {284.2, 285.2, 286.0, 287.3, 290.8, 292.6}, ...
    'area',   {10.0, 20.0, 40.0, 10.0, 15.0, 5.0} ...
);

F_peaks = struct(...
    'id',                          {"C_bound_F", "physisorbed_F"}, ...
    'name',                        {"C-bound F", "physisorbed F"}, ...
    'center',                      {687.0, 681.6}, ...
    'area',                        {100.0, 0.0}, ...
    'include_in_carbon_bound_F',   {true, false}, ...
    'include_in_total_F',          {true, true} ...
);

SC = 1.0;
SF = 4.4118;
alpha = 0;

% Execute function
comp = xps.calculateComposition(C_peaks, F_peaks, SC, SF, alpha);

fprintf('--- Test Case 1 Results ---\n');
fprintf('Calculated Weighted C1s F/C = %.6f (Expected: 0.850000)\n', comp.weighted.F_over_C);
fprintf('Calculated Legacy C1s F/C   = %.6f (Expected: 0.300000)\n', comp.legacy.F_over_C);
fprintf('Calculated Carbon-Bound F/C = %.6f\n', comp.carbonBound.F_over_C);
fprintf('Calculated CxF Formula      = %s\n', comp.weighted.CxF);

% Check 1: Weighted F/C formula accuracy
expected_weighted_FC = (40 + 2*15 + 3*5) / 100; % 0.85
if abs(comp.weighted.F_over_C - expected_weighted_FC) < 1e-6
    fprintf('[PASS] Weighted C1s F/C matches exact mathematical definition (0.85)!\n');
else
    fprintf('[FAIL] Weighted C1s F/C mismatch! Expected %.6f, got %.6f\n', expected_weighted_FC, comp.weighted.F_over_C);
end

% Check 2: Legacy C1s formula accuracy: ((A_Ctotal - A_sp2)/A_Ctotal)*(1/3) = ((100-10)/100)*(1/3) = 0.3000
expected_legacy_FC = ((100 - 10)/100) * (1/3);
if abs(comp.legacy.F_over_C - expected_legacy_FC) < 1e-6
    fprintf('[PASS] Legacy C1s F/C matches exact mathematical definition (0.30)!\n');
else
    fprintf('[FAIL] Legacy C1s F/C mismatch! Expected %.6f, got %.6f\n', expected_legacy_FC, comp.legacy.F_over_C);
end

% Check 3: CxF Conversion: 1 / 0.85 = 1.17647 -> C1.18F
expected_Cx = 1 / expected_weighted_FC;
if abs(comp.weighted.C_over_F - expected_Cx) < 1e-6
    fprintf('[PASS] CxF ratio conversion (1/(F/C)) verified!\n');
else
    fprintf('[FAIL] CxF conversion failed!\n');
end

%% Test Case 2: Alpha parameter test (alpha = 1.5)
alpha2 = 1.5;
comp2 = xps.calculateComposition(C_peaks, F_peaks, SC, SF, alpha2);
expected_weighted_FC2 = (40 + 1.5*10 + 2*15 + 3*5) / 100; % 1.00

fprintf('\n--- Test Case 2 Results (alpha = 1.5) ---\n');
fprintf('Calculated Weighted C1s F/C = %.6f (Expected: 1.000000)\n', comp2.weighted.F_over_C);

if abs(comp2.weighted.F_over_C - expected_weighted_FC2) < 1e-6
    fprintf('[PASS] Weighted C1s F/C with non-zero alpha verified (1.00)!\n');
else
    fprintf('[FAIL] Alpha-weighted calculation mismatch!\n');
end