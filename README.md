# Ruoff XPS CxF — first milestone

This is a **legacy-baseline starter**, not the finished scientific model.

## Goal

For one Ruoff sample, reproduce the current six-component C1s / three-component F1s workflow as closely as the supplied report allows, then calculate:

- locked legacy C1s F/C
- provisional weighted C1s F/C
- carbon-bound F1s/C1s F/C
- total-F F1s/C1s F/C
- F atomic %
- C/F
- CxF

The Ruoff reference value is **not used as a fitting constraint**.

## Important distinction

`F/C` is a ratio.

`F at.%` is:

`F_at% = (F/C)/(1 + F/C) * 100`

Therefore `F/C * 100` is **not** fluorine atomic percent.

## Current assumptions

From the supplied tuning report:

- C1s: six components
- F1s: three components
- normalization: max intensity
- background: AsLS
- fit unsmoothed data
- S_C = 1.0
- S_F = 4.4118
- C4 legacy bounds remain 288.1–289.5 eV even though the report flags a reference position near 287.3 eV
- F1s chemical assignment is based on fitted position, not peak index

The supplied report says the exact historical XPS Fit Lab peak shape is not documented in the material we have. This starter therefore exposes the peak shape explicitly and defaults to Gaussian because that is the current lab-development assumption. Do not call this the verified historical XPS Fit Lab implementation until the peak shape is confirmed.

## Run

Put this folder on the MATLAB path and run:

```matlab
runSingleSample
```

Keep `C1s_A(1).txt` and `F1s_A(1).txt` in the project root, or change the paths in `runSingleSample.m`.

## Required MATLAB toolbox

Optimization Toolbox (`lsqnonlin`).

## What to inspect first

1. Are the raw spectra imported correctly?
2. Does the energy direction look correct?
3. Does the AsLS background look sensible?
4. Do the fitted centers/FWHMs look chemically reasonable?
5. Are any parameters pinned to bounds?
6. Does the C1s legacy calculation reproduce the known legacy result once the fitted areas are matched?
7. Only after that should we move to weighted and cross-region models.

## Not yet implemented

- pseudo-Voigt mixing
- automated multi-start fitting
- stability sweeps
- all background choices
- Excel output
- blind/validation split
- sensitivity-factor sweep
- GUI/App Designer

Those belong after the legacy baseline is reproducible.
