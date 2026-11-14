# Testing

## Maintained regression suite

Run the maintained deterministic MATLAB regression suite from the repository
root:

```matlab
results = runtests(pwd);
assertSuccess(results);
```

This discovers the root-level function/unit tests and the maintained
`test_0G_composition.m` compatibility test. A failure here is a regression
and must be investigated before Phase 0H execution.

The scripts under `Phase 0 tests/` are historical development artifacts.
They use obsolete APIs and MATLAB section/shared-workspace execution patterns,
so `runtests(pwd,"IncludeSubfolders",true)` incorrectly treats their sections
as independent maintained tests. Those scripts are intentionally excluded
from the regression suite and are not repaired or deleted in this phase.

## Phase 0H harness validation

The Phase 0H dry-run validates inventory, seeds, configurations, one generated
fixture per cell, independent background generators, checkpoint/resume, and
statistics without calling the optimizer:

```matlab
report = runPhase0HDryRun;
```

Do not launch the 100-trial cells until the dry-run artifacts have been
reviewed and a separate launch is approved.

## Phase 0H execution and resume

Optimizer execution is strictly non-graphical. The runner sets default figure
visibility to `off`, rejects and closes any figure created by a trial, and
does not call `xps.plotFitComponents` or other report plotting functions.
Figures belong only in later, separate post-processing.

Before a formal launch, run the separate smoke dataset. It uses temporary
storage and independent seed-family IDs 31/32, invokes the optimizer, tests
resume, and is excluded from formal statistics:

```matlab
smokeReport = runPhase0HExecutionSmokeTest;
assert(smokeReport.passed)
```

After explicit launch approval, start the formal frozen run once:

```matlab
formalReport = runPhase0HFormal("start");
```

If MATLAB stops, resume from immutable trial/cell checkpoints. Completed
trial IDs and their stored seeds are verified and skipped:

```matlab
formalReport = runPhase0HFormal("resume");
```

Status inspection is read-only:

```matlab
status = getPhase0HRunStatus;
```

Final summaries are gated on all 9,200 planned trials and all 92 completed-
cell checkpoints. This command refuses to write a partial final summary and
writes reporting artifacts to the separate
`results/phase0h_postprocess_v1_0_1` folder; it never writes into the formal
run folder:

```matlab
summary = generatePhase0HSummaries;
```

The execution-error audit is likewise read-only with respect to the formal
run. Optional audit artifacts are written separately:

```matlab
audit = auditPhase0HFormalRun("", WriteArtifacts=true);
```

The formal output defaults to `results/phase0h_formal_v1_0_0`. Its manifest
contains the frozen plan version/hash, code/config fingerprint, Git revision
and tracked-diff hash, seed namespace, MATLAB/platform details, cell inventory,
and expected optimizer count. Progress is printed and appended to `run.log`
with family, cell, trial, elapsed time, status, and checkpoint path.
