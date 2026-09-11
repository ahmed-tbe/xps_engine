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

The Ruoff reference values are **not used as fitting constraints**. Direct
Sample A references live in `reference/sample_A_ruoff_v1.json`; model values
derived from those peak fractions are calculated and labeled separately.

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
- versioned default background: AsLS
- supported configured backgrounds: linear, Shirley, AsLS, and Tougaard
- fit unsmoothed data
- S_C = 1.0
- S_F = 4.4118
- C4 legacy bounds remain 288.1–289.5 eV even though the report flags a reference position near 287.3 eV
- F1s chemical assignment is based on fitted position, not peak index

The supplied report says the exact historical XPS Fit Lab peak shape is not documented in the material we have. This starter therefore exposes the peak shape explicitly and defaults to Gaussian because that is the current lab-development assumption. Do not call this the verified historical XPS Fit Lab implementation until the peak shape is confirmed.

## Run the standardized Sample A benchmark

Put this folder on the MATLAB path and run:

```matlab
report = runSampleABenchmark("linear");
```

The explicit `"linear"` argument is a local exploratory choice. It does not
change the JSON default. `runSingleSample.m` remains as a compatibility entry
point and calls the same benchmark engine.

The supplied Sample A files contain energy and intensity columns only. The
software max-normalization divisors are recorded and reversed, but C1s/F1s
acquisition scaling is not present. Therefore the benchmark withholds physical
cross-region F/C until acquisition factors and provenance are supplied.

## Required MATLAB toolbox

Optimization Toolbox (`lsqnonlin`).

## What to inspect first

1. Are the raw spectra imported correctly?
2. Does the energy direction look correct?
3. Does the explicitly selected background look sensible?
4. Do the fitted centers/FWHMs look chemically reasonable?
5. Are any parameters pinned to bounds?
6. Does the C1s legacy calculation reproduce the known legacy result once the fitted areas are matched?
7. Only after that should we move to weighted and cross-region models.

## Not yet implemented

- pseudo-Voigt mixing
- automated multi-start fitting
- stability sweeps
- Excel output
- blind/validation split
- sensitivity-factor sweep
- GUI/App Designer

Those belong after the legacy baseline is reproducible.

Planned candidate and robustness cases are tracked in `FUTURE_TESTS.md`,
including the separate ~681.3-681.6 eV `F_other` assignment that is not part of
the locked three-peak F1s model.
