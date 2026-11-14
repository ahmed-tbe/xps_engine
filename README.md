# Ruoff XPS CxF pipeline

This repository preserves the Phase 0G deterministic fitting pipeline and
adds versioned composition models without using literature values as fitting
constraints.

The processing order is unchanged:

`import/configuration -> preprocessing/background -> peak fitting -> chemical classification -> composition -> QC/report`

## Composition outputs

`xps.calculateComposition` now separates mentor-approved primary models from
preserved diagnostics:

- `composition.primary.c1s_main_cf`: `F/C=A(C-F)/A(C,total)`;
- `composition.primary.c1s_f1s_semi`: sensitivity-corrected semi-covalent
  F1s area over total C1s area;
- `composition.diagnostics.weighted_c1s`;
- `composition.diagnostics.legacy_c1s`;
- `composition.diagnostics.carbon_bound_f1s_previous`;
- `composition.diagnostics.total_f1s`.

The old `weighted`, `legacy`, `carbonBound`, and `totalF` fields remain as
deprecated aliases. `F/C` is a ratio; fluorine atomic percent is
`100*(F/C)/(1+F/C)`.

The primary F1s model selects exactly one peak by the chemical assignment
`semi_covalent_F_C` and the approved 686.7-686.9 eV position window. It does
not select by array index. The position window is loaded from
`config/composition/ruoff_primary_models_v1.json`; it is not hardcoded in the
calculation function. Cross-region results restore software normalization
and acquisition scaling before sensitivity correction. If acquisition
scaling is unknown, the result is marked `withheld` rather than assuming one.

## Versioned profiles

- `config/composition/ruoff_primary_models_v1.json`: primary equations and
  selection rules.
- `config/sensitivity/ruoff_reproduction_sf3p95_v1.json`: provisional Ruoff
  reproduction profile (`S_C=1`, `S_F=3.95`), not a confirmed Ruoff
  instrument factor.
- `config/sensitivity/thermo_k_alpha_sf4p118_v1.json`: mentor-confirmed future
  Thermo K-Alpha profile (`S_C=1`, `S_F=4.118`).
- `config/sensitivity/legacy_project_sf4p4118_v1.json`: preserved legacy
  regression profile (`S_C=1`, `S_F=4.4118`).

Profiles are explicit inputs. The composition layer rejects a versioned
profile whose numeric factors do not match the numeric API arguments.

## Reference fixtures and examples

Versioned A-C fixtures are under `reference/`. Direct Ruoff/project values are
separate from values calculated by applying a model. Sample A contains the
complete available C1s center/fraction breakdown; Samples B and C explicitly
record that this breakdown is unavailable instead of inferring it.

Run deterministic reference arithmetic and profile examples with:

```matlab
summary = validateRuoffBenchmarkFixtures;
profiles = runCompositionModelExamples;
```

Run the exploratory real Sample A benchmark with an explicit background and
sensitivity profile:

```matlab
report = runSampleABenchmark("linear", "ruoff_reproduction_sf3p95_v1");
```

This does not tune bounds, peak count, backgrounds, or sensitivity factors.
The raw C1s/F1s files do not document acquisition scaling, so the real
cross-region primary result remains withheld. The C1s-only primary and
diagnostic results are still reported.

The current real Sample A Linear-background fit places the semi-covalent peak
at approximately 686.53 eV, outside the strict 686.7-686.9 eV primary window.
It therefore fails positional QC even independently of the missing acquisition
scale. Phase 0H charging/global-binding-energy-shift cells G1/G2 explicitly
quantify sensitivity to this criterion; the window is not widened here.

## Testing

See `TESTING.md`. From the repository root:

```matlab
results = runtests(pwd,"IncludeSubfolders",true);
assertSuccess(results);
```

Optimization Toolbox (`lsqnonlin`) is required for fitting tests.

## Phase 0H

The mentor-approved design is frozen in `PHASE_0H_TEST_PLAN_v1.0.0.md`, with
its SHA-256 in `PHASE_0H_PLAN_LOCK_v1.0.0.json`. No Phase 0H Monte Carlo trial
has been run. No harness existed when the composition update was implemented,
so no dry-run was performed.

Planned candidates, including a separate ~681.3-681.6 eV `F_other`
assignment, remain tracked without altering the locked three-peak production
model.
