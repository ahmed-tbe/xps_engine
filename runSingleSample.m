%% Ruoff XPS CxF - first milestone
% Legacy-baseline playground for ONE Ruoff sample.
%
% IMPORTANT:
% This first version is deliberately conservative. It reproduces the
% report's six C1s / three F1s component structure and legacy calculation.
% It does NOT tune parameters to the Ruoff reference value.
%
% MATLAB requirements:
%   - Optimization Toolbox (lsqnonlin)
%
% Current data format:
%   two-column TXT/CSV: [binding_energy_eV, intensity]
%
% The report says the supplied Excel files use C1s/F1s sheets with data
% beginning at row 17. For the supplied TXT files, this script reads the
% two numeric columns directly.

clear; clc; close all;

%% User settings
sampleID = "A";
c1sFile = "C1s_A.txt";
f1sFile = "F1s_A.txt";

cfg = jsondecode(fileread(fullfile("config","legacy_current_v1.json")));

% The exact peak-shape used by the old XPS Fit Lab implementation is not
% established by the supplied report. We therefore expose it explicitly.
% Change only when you have evidence for the legacy implementation.
cfg.peak_shape = "gaussian";

%% Read raw spectra
C = xps.readSpectrum(c1sFile);
F = xps.readSpectrum(f1sFile);

fprintf("Sample %s\n", sampleID);
fprintf("C1s: %d valid points, BE %.3f to %.3f eV\n", ...
    numel(C.energy), min(C.energy), max(C.energy));
fprintf("F1s: %d valid points, BE %.3f to %.3f eV\n", ...
    numel(F.energy), min(F.energy), max(F.energy));

%% Preprocess
Cpre = xps.preprocessSpectrum(C, cfg.preprocessing);
Fpre = xps.preprocessSpectrum(F, cfg.preprocessing);

%% Fit C1s six-peak model
Cfit = xps.fitSpectrum(Cpre.energy, Cpre.y_fit, cfg.C1s, cfg.peak_shape);

%% Fit F1s three-peak model
Ffit = xps.fitSpectrum(Fpre.energy, Fpre.y_fit, cfg.F1s, cfg.peak_shape);

%% Position-based F1s classification
Ffit.peaks = xps.classifyF1sPeaks(Ffit.peaks, cfg.F1s.classification_boundaries_eV);

%% Composition calculations
% The first milestone keeps the legacy calculation locked.
comp = xps.calculateComposition(Cfit.peaks, Ffit.peaks, ...
    cfg.sensitivity_factors.C1s, cfg.sensitivity_factors.F1s, 0);

%% Display results
fprintf("\n===== C1s fitted peaks =====\n");
disp(struct2table(Cfit.peaks));

fprintf("\n===== F1s fitted peaks =====\n");
disp(struct2table(Ffit.peaks));

fprintf("\n===== Composition =====\n");
fprintf("Legacy C1s F/C   = %.6f\n", comp.legacy.F_over_C);
fprintf("Legacy C1s F at%% = %.3f %%\n", comp.legacy.F_atpct);
fprintf("Legacy C1s       = %s\n", comp.legacy.CxF);

fprintf("C-bound F/C      = %.6f\n", comp.carbonBound.F_over_C);
fprintf("C-bound F at%%    = %.3f %%\n", comp.carbonBound.F_atpct);
fprintf("C-bound CxF      = %s\n", comp.carbonBound.CxF);

fprintf("Total-F F/C      = %.6f\n", comp.totalF.F_over_C);
fprintf("Total-F F at%%    = %.3f %%\n", comp.totalF.F_atpct);
fprintf("Total-F CxF      = %s\n", comp.totalF.CxF);

%% QC
fprintf("\n===== QC =====\n");
fprintf("C1s RMSE = %.6g, R2 = %.6f\n", Cfit.metrics.RMSE, Cfit.metrics.R2);
fprintf("F1s RMSE = %.6g, R2 = %.6f\n", Ffit.metrics.RMSE, Ffit.metrics.R2);

if ~isempty(Cfit.warnings)
    fprintf("C1s warnings:\n");
    disp(Cfit.warnings(:));
end
if ~isempty(Ffit.warnings)
    fprintf("F1s warnings:\n");
    disp(Ffit.warnings(:));
end

%% Plot
xps.plotFitComponents(Cpre, Cfit, "C 1s - Sample " + sampleID);
xps.plotFitComponents(Fpre, Ffit, "F 1s - Sample " + sampleID);

%% Save result
if ~exist("results","dir"), mkdir("results"); end
save(fullfile("results","Sample_"+sampleID+"_legacy_baseline.mat"), ...
    "C","F","Cpre","Fpre","Cfit","Ffit","comp","cfg","sampleID");

fprintf("\nSaved results/Sample_%s_legacy_baseline.mat\n", sampleID);
fprintf("NOTE: MATLAB execution has not been validated by the author of this script.\n");
