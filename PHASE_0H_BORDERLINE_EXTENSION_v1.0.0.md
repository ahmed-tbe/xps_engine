# Phase 0H Borderline Extension — Execution v1.0.0

Status: execution design frozen for dry-run validation; extension trials are not started by the dry-run.

## Scope

The accepted `phase0h_unified_v1_0_1` 100-trial dataset remains authoritative and immutable. The extension adds only trial IDs 101–400 for the exact 42 cells listed in its accepted `borderline_extension_cells.csv`. Trials 1–100 are never regenerated, replaced, or copied into the extension directory.

- Selected cells: 42
- New trials per selected cell: 300
- Total new trials: 12,600
- Expected optimizer invocations: 40,200
- Final analysis: N=400 for the 42 selected cells and N=100 for the remaining 50 cells
- Gate behavior: unchanged frozen thresholds; observed rates are the gates and Wilson intervals are uncertainty only

## Seed namespace

The extension namespace is `phase0h_borderline_extension_v1_0_0/trials_101_400`. It uses the frozen Phase 0H seed formula with the original cell family/index and the disjoint trial-ID domain 101–400. The initial dataset uses trial IDs 1–100. The dry run verifies all extension stream seeds are deterministic and unique and that no numeric seed occurs in the initial schedule.

## Execution and immutability

Formal extension output is isolated at `results/phase0h_borderline_extension_v1_0_0`. The original formal, amendment, and accepted unified directories are read-only inputs and are protected by before/after integrity snapshots. Trial checkpoints are atomic, are written after every trial, and are skipped only after their run fingerprint and frozen seed record validate. Plotting is forcibly disabled throughout optimizer execution.

The final reporting step writes a separate `results/phase0h_final_v1_0_0` directory. It retains per-trial and per-cell execution provenance and reports failures separately for convergence, peak center, FWHM, major area, minor fraction, composition F/C, F at.%, false-valid, false-invalid, chemical-label misclassification, QC withholding, and bound sensitivity.

## Commands

These commands are issued from the project root after the dry run is approved:

```matlab
report = runPhase0HExtension("start");
report = runPhase0HExtension("resume");
status = getPhase0HExtensionStatus;
summary = generateFinalPhase0HSummary;
```

`generateFinalPhase0HSummary` refuses to run until all 12,600 extension checkpoints and all 42 cell-completion checkpoints are present and the stored execution fingerprint matches the frozen extension code.
