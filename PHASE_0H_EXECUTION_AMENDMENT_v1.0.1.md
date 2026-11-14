# Phase 0H Execution Amendment v1.0.1

Status: execution amendment approved for dry-run/smoke validation only. The
1,100 amended trials require explicit user approval after validation.

This amendment references, but never modifies, the frozen Phase 0H v1.0.0
plan and immutable `results/phase0h_formal_v1_0_0` output.

## Scope

- Rerun all ten composition-only Family 12 cells (`F12_R1`–`F12_R5` and
  `F12_T1`–`F12_T5`) after correcting the generated-truth schema adapter.
- Rerun the complete 100-trial `F10_G2` charging-shift cell after correcting
  illegal moderate-start fixture generation.
- Reuse the frozen family IDs, cell indices, trial IDs, stream IDs, and seed
  formula exactly. Family 12 remains composition-only with zero optimizer
  calls. `F10_G2` retains two optimizer calls per trial.

No acceptance threshold, composition equation, sensitivity factor, fit
bound, cell definition, or production fitting equation changes in this
amendment.

## Frozen moderate-center initialization rule

Let the truth-centered perturbation interval be
`[truthCenter-0.25, truthCenter+0.25]` and the configured legal center bounds
be `[boundLower,boundUpper]`.

1. If their intersection is nonempty, retain the v1.0.0 rule exactly: draw
   uniformly from the intersection using the original center seed.
2. If their intersection is empty, ignore the shifted truth center and use
   the configured nominal initial center. Project it onto the inclusive legal
   bounds only as a defensive safeguard against invalid configuration.
3. Never widen the configured fit bounds and never emit an out-of-bound
   initial center.

The disjoint fallback is deterministic and uses only configured fitting
information, not privileged knowledge of the injected charging shift.

## Schema adapter correction

Generated truth peaks store their descriptive assignment in `label`.
Composition-only execution now maps `truth.label` to the fitted-like
`assignment` field expected by the composition API. No chemical labels,
areas, centers, sensitivity factors, or equations are changed.

## Required provenance

The amendment manifest records the original plan hash, original execution
fingerprint, amended code/config fingerprint, amended execution fingerprint,
affected cells, exact source changes, reused-seed policy, and rerun rationale.
Unified reporting must retain per-cell source-run provenance.
