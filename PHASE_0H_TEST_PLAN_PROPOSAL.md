# Phase 0H robustness test plan — proposal for review

Status: revised design awaiting mentor review and freeze. No Phase 0H harness
has been implemented, no Phase 0H trials have been run, and no threshold is
final until that freeze. Phase 0G remains the locked deterministic control.

## 1. Locked control and notation

The primary Phase 0H fixture is
`config/test/ruoff_like_sample_A_synthetic_v1.json`:

- C1s: 280–297 eV in 0.025 eV steps; Ruoff-derived centers/fractions;
  Gaussian FWHM 0.60 eV.
- F1s: 682–691 eV in 0.020 eV steps; centers 684.7/686.7/688.2 eV;
  physical areas 0.2/0.9/0.9; Gaussian FWHM 0.65 eV.
- Explicit zero additive background processed with Linear unless a cell says
  otherwise; C1s/F1s acquisition factors 3/7 and max normalization.
- The Phase 0G generic and Ruoff-like exact tests run once before Phase 0H.
  They are controls, not Monte Carlo cells, and must remain passing.

The 0.60 eV C1s and 0.65 eV F1s widths are locked synthetic fixture
choices. They are not Ruoff-reported linewidths and are not experimental
reference targets.

For region `r`, let `s_r(i)` be its noise-free, peak-only signal after the
declared acquisition multiplier but before background and noise. Define

`PeakSNR_r = max_i(s_r(i)) / sigma_r`.

For a requested finite SNR, add independent noise
`epsilon_r(i) ~ Normal(0,sigma_r^2)`, where
`sigma_r = max_i(s_r(i))/PeakSNR_r`. The same requested PeakSNR is used in
both regions, but their `sigma_r` values are calculated separately. Noise is
added after the synthetic background, is not clipped, and is generated on
the original grid. `PeakSNR=Inf` means exactly zero added noise.

`U(a,b)` means continuous uniform and `LogU(a,b)` means that `log(x)` is
uniform between `log(a)` and `log(b)`. Pseudo-Voigt generation uses the
area-normalized curve `(1-eta)*Gaussian + eta*Lorentzian`, with both terms
having the declared center, FWHM, and integrated area.

## 2. Trials and random seeds

- Initial run: exactly 100 trials per stochastic cell. Increasing the count
  appends trials 101 onward; it never replaces the first 100.
- RNG: MATLAB `twister`. Before each independent draw, call `rng(seed,'twister')`.
- Seed formula:
  `seed = 100000000*familyID + 100000*cellID + 100*trialID + streamID`.
- Stream IDs: 1/2 C/F noise; 11/12 C/F centers; 21/22 C/F areas;
  31/32 C/F widths; 41/42 C/F order; 51/52 C/F acquisition scale.
- The observation and all ID-matched initial values are held identical for
  paired peak-order comparisons. Seeds and generated parameters are saved
  with every trial.
- No thresholds may be changed after aggregate or per-cell results are
  inspected. Any revision creates a versioned plan and a fresh seed block.
- For a binomial rate `k/N`, report the two-sided 95% Wilson interval using
  `p=k/N` and `z=1.95996398454005`. With
  `d=1+z^2/N`, its center is `(p+z^2/(2*N))/d`, its half-width is
  `z*sqrt(p*(1-p)/N+z^2/(4*N^2))/d`, and the interval is center plus/minus
  that half-width. A minimum-rate gate passes only when its Wilson lower bound
  is at least the threshold; a maximum-rate gate passes only when its Wilson
  upper bound is at most the threshold.
- If the initial 100-trial Wilson interval contains a rate threshold, append
  trials 101–400 using the same seed rule. This is the only allowed adaptive
  extension. If the 400-trial interval still contains the threshold, label
  the cell `Inconclusive`; do not call it a pass or tune the threshold.

Plain-language consequence: these confidence-bound gates are substantially
stricter than comparing the observed percentage directly with a threshold.
At `N=100`, even 99/100 successes have a Wilson lower bound of about 94.6%, so
they do not immediately pass a `WilsonLower>=95%` gate; 100/100 are needed for
an immediate pass. For a `WilsonUpper<=5%` maximum-rate gate, 1/100 events
have an upper bound of about 5.45% and trigger the predeclared extension,
whereas 0/100 have an upper bound of about 3.70% and pass immediately. The
thresholds are unchanged, but this conservative interpretation is explicitly
flagged for mentor approval before freeze.

## 3. One-family-at-a-time matrix

All unspecified settings equal the locked control. These cells are run
independently; they are not crossed with one another.

| Family (ID) | Cells and exact variation | Draft gate |
|---|---|---|
| Noise (1) | N1/N2/N3: PeakSNR 100/50/20; production initial values; canonical peak order | A/A/B |
| Initial conditions (2) | I1: moderate, 1 start; I2: broad, 1 start; I3: broad, 5 starts; I4: broad, 10 starts. PeakSNR 50. Moderate: center=`U(max(lower,truth-0.25),min(upper,truth+0.25))` eV, area=`truth*LogU(0.5,2)`, and FWHM=`LogU(max(lower,0.75*truth),min(upper,1.25*truth))`. Thus no probability mass is created at a bound by clipping. Broad: center=`U(lower,upper)`, area=`truth*LogU(0.25,4)`, FWHM=`LogU(lower,upper)`. Multiple starts select minimum resnorm without consulting truth. | A/B/A/A |
| Peak order (3) | O1/O2: canonical versus an independently uniform random permutation of each region at PeakSNR Inf/50. The observation and initial parameters are identical by peak ID. | Order/A |
| Overlap (4) | V1/V2: multiply within-cluster center offsets from the area-weighted cluster centroid by 0.75/0.50; C cluster is the first four C1s peaks and F cluster is all three F1s peaks. V3/V4: retain centers and set every FWHM to 1.0/1.4 eV. PeakSNR 50. One fixed, predeclared test-only bound set must contain all generated centers; production bounds remain unchanged. | B |
| Missing/unnecessary peaks (5) | S1: set each one of the six C1s and three F1s truth areas to zero in separate cells while retaining the full fit model. S2: omit each fitted component separately while retaining the full truth. S3: add a zero-truth fitted C1s peak at 286.25 eV or F1s peak at 689.8 eV in separate test-only models. S4: generate an unmodelled C1s peak at 286.25 eV with 5% of total C area. S5: extend F1s to 679–691 eV and generate `F_other` at 681.5 eV with 1%, 5%, or 10% of total F area while fitting the locked three-peak model. PeakSNR 50. | C |
| Peak shape (6) | P1/P2/P3: generate area-normalized pseudo-Voigt peaks with eta 0.2/0.5/0.8 and fit Gaussian peaks; PeakSNR 50. | A/B/B |
| Background (7) | B1 linear→Linear; B2 Shirley→Shirley; B3 Tougaard→Tougaard; B4 Shirley→Linear; B5 Tougaard→Linear; B6 quadratic→Linear; B7 zero→AsLS with the preserved defaults. PeakSNR 50. `t=(E-min(E))/(max(E)-min(E))`, `M=max(s)`, linear=`M*(0.05+0.10*t)`, quadratic=`M*(0.02+0.03*t+0.10*t^2)`. Shirley/Tougaard truth generation follows the independent-generator requirements below; each generated shape is shifted to zero minimum and scaled to maximum `0.15*M`. | A/A/A/C/C/C/C |
| Window truncation (8) | T1–T9: remove 0.5/1.0/2.0 eV from the low-energy edge, high-energy edge, or both edges, giving nine cells; PeakSNR 50. No bound or peak-definition changes. | B |
| Scale controls (9) | Q1: draw known C/F acquisition factors independently from `LogU(0.25,4)` and provide the exact factors to scaling. Q2: additionally apply one common file-unit multiplier from `LogU(1e-3,1e3)` and include that multiplier in each supplied acquisition scale, so restored physical areas retain their original units. Q3: omit one or both acquisition factors and require cross-region output to be withheld. PeakSNR Inf. | Scale/Scale/C |

### 3.1 Independent background truth generation

The background truth generator must live in test-only code and must not call
`xps.estimateBackground`, `xps.preprocessSpectrum`, or any production
background helper. Its version and literature/reference provenance must be
recorded before the plan is frozen.

For ascending binding energy, the proposed independent Shirley reference is
the trapezoidal discretization of
`q(E)=integral_E^Emax s(u)du / integral_Emin^Emax s(u)du`, followed by the
declared shift and `0.15*M` scaling. The proposed independent Tougaard
reference is a direct trapezoidal convolution
`q(E)=integral_Emin^E s(u)*K(E-u)du`, with
`K(T)=B*T/(C+T^2)^2`, `B=2866`, and `C=1643`, followed by the same declared
shift and scaling. These definitions must be validated against separately
calculated reference arrays or hand-checkable limiting cases before they can
claim independent validation.

If an independently implemented and validated generator is not available at
freeze time, B2 and B3 must be relabeled
`ShirleyAlgorithmSelfConsistency` and `TougaardAlgorithmSelfConsistency`.
They may exercise plumbing and repeatability, but they do not count as
independent validation of the production background estimators. B4/B5 must
likewise identify the actual truth generator in every result record.

## 4. Small predeclared combined-stress set

These four cells replace a full Cartesian product. Each has 100 trials.

| Cell | Predeclared combination | Draft gate |
|---|---|---|
| C1 | PeakSNR 50; moderate starts; 5 starts; center-offset factor 0.75; pseudo-Voigt eta 0.2; matched Linear background; trim 0.5 eV from both edges | B |
| C2 | PeakSNR 20; broad starts; 10 starts; center-offset factor 0.50; pseudo-Voigt eta 0.5; matched Shirley background; trim 1.0 eV from both edges | B |
| C3 | PeakSNR 20; broad starts; 10 starts; FWHM 1.4 eV; pseudo-Voigt eta 0.5; Tougaard generation fitted with Linear; trim 1.0 eV from the low-energy edge; unmodelled 681.5 eV `F_other` at 5% total F | C |
| C4 | PeakSNR 50; broad starts; 10 starts; pseudo-Voigt eta 0.8; quadratic generation fitted with Linear; omit true CF3 from the fit; include the zero-truth fitted C1s peak at 286.25 eV; trim 2.0 eV from the high-energy edge | C |

## 5. Recorded metrics

Record per trial, per region, and by peak ID:

- center error in eV; absolute and relative FWHM error;
- restored physical-area relative error and area-fraction percentage-point
  error (minor truth peaks below 5% are judged primarily in percentage points);
- `TrueFullAnalyticArea`, `TrueInWindowArea`, and
  `TrueWindowContainmentFraction=TrueInWindowArea/TrueFullAnalyticArea` for
  each generated peak, where `TrueInWindowArea` is its continuous integral
  over the retained energy window; also record the trapezoidal sampled-grid
  area. Record the analogous fitted-component in-window integral. Full-area
  error and in-window-area error are reported separately, so a good fit to
  the observed portion with poor full-area extrapolation is identifiable as
  truncation/extrapolation rather than within-window optimizer error;
- weighted and legacy C1s F/C, F at.%, C/F and CxF errors;
- carbon-bound and total-F cross-region F/C, F at.%, C/F and CxF errors when
  acquisition scaling is valid;
- RMSE, R², AICc, BIC, resnorm, exit flag, function evaluations, and runtime;
- residual mean, residual standard deviation, maximum absolute residual,
  RMSE divided by known post-normalization noise sigma, and lag-1 residual
  autocorrelation;
- exact-bound and near-bound status by peak and parameter, plus the fraction
  of trials with any such event;
- convergence rate, exception rate, deployable-QC-valid rate,
  synthetic-diagnostic-QC-valid rate, false-valid rate, and false-invalid rate.

For every scalar error metric report mean, median, sample standard deviation,
empirical 2.5th/97.5th percentiles, and worst case. Empirical percentiles use
the nearest-rank definition: sort `N` values and take value
`ceil(p*N)` for quantile `p`. Do not discard failed trials when calculating
rates or worst cases.

### 5.1 Per-trial truth classification

Truth classification has separate peak and composition axes. These labels
use truth errors only, never residuals, warnings, AICc, or BIC. An exception,
nonfinite required output, or failed peak-ID mapping makes every applicable
truth label false.

| Peak trial label | Center absolute error | FWHM relative error | Major-peak area relative error | Minor/zero/unmatched area-fraction error |
|---|---:|---:|---:|---:|
| `PeakTruthAcceptable_A` | <=0.15 eV | <=25% | <=15% | <=1.5 percentage points |
| `PeakTruthAcceptable_B` | <=0.30 eV | <=50% | <=30% | <=3 percentage points |

| Composition trial label | Every applicable F/C and C/F relative error | Every applicable F-at.% absolute error |
|---|---:|---:|
| `CompositionTruthAcceptable_A` | <=10% | <=3 percentage points |
| `CompositionTruthAcceptable_B` | <=15% | <=5 percentage points |

For tier `X` equal to A or B, define overall truth as the conjunction of its
two axes: `OverallTruthAcceptable_X = PeakTruthAcceptable_X && CompositionTruthAcceptable_X`.

“Major” means truth fraction >=5%; “minor” means positive truth fraction <5%.
Center/FWHM errors apply only to positive-truth peaks having an ID-matched fit
component. Relative error is never formed with zero truth. A fitted zero-truth
peak instead uses its fitted area fraction as the percentage-point error. A
truth peak omitted from the fit uses its full truth fraction as unrecovered
area-fraction error. An unmodelled generated peak is handled the same way.

`CompositionTruthAcceptable` requires every applicable weighted/legacy C1s
and valid cross-region composition output to pass, but it does not inspect
individual center, width, or component-area errors. Thus an incorrect minor
peak width may fail `PeakTruthAcceptable` and `OverallTruthAcceptable` without
being mislabeled as a false-valid composition result. Gate C cells use the B
truth labels for confusion rates; structural misspecification does not
redefine truth as successful.

### 5.2 QC classifications and confusion rates

First define a deployable common fit check using only the spectrum,
configuration, preprocessing record, and fit: no exception; all required fit
outputs finite; positive C1s and F1s exit flags; and absolute lag-1 residual
autocorrelation <=0.20 in both regions.

For residuals `e_i`, set `d_i=e_i-mean(e)` and
`D=sum_i(d_i^2)`. Normally
`rho1=sum_(i=1)^(n-1)(d_i*d_(i+1))/D`. Define
`tau=100*eps(1)*max(1,sum_i((y_i-mean(y))^2))`. If `D<=tau`, record
`ResidualVarianceEffectivelyZero=true`, set `rho1=0`, and treat the
autocorrelation check as passed. This makes exact/noiseless fits well defined.

The deployable QC labels are:

- `DeployablePeakQCValid`: common fit check plus no exact-bound or
  extremely-small-area warning. Near-bound warnings are reported but do not
  alone make this label false.
- `DeployableCompositionQCValid`: common fit check plus finite required
  composition outputs and valid acquisition scaling whenever cross-region
  results are expected. Peak-specific bound/width warnings do not alone make
  this label false.
- `DeployableOverallQCValid` is the conjunction of
  `DeployablePeakQCValid` and `DeployableCompositionQCValid`.

Define `SyntheticDiagnosticPeakQCValid`,
`SyntheticDiagnosticCompositionQCValid`, and
`SyntheticDiagnosticOverallQCValid` from their matching deployable labels by
additionally requiring, for noisy cells, regional
`RMSE/post-normalization-sigma <=1.25`, or, for noise-free cells, regional
R² >=0.999. These labels use injected simulation metadata, are diagnostic
only, and must not be presented as deployable QC. Phase 0H will not invent or
tune a production noise estimator.

For dimension `D` in `{Peak, Composition, Overall}`, use its matching truth
and QC labels. Use tier A truth for Gate A and tier B truth for Gates B/C.
For each deployable and synthetic-diagnostic QC label `Q_D` and truth label
`T_D`, define:

- `FalseValidTrial_D = Q_D && ~T_D`;
- `FalseInvalidTrial_D = ~Q_D && T_D`;
- `FalseValidRate_D = sum(FalseValidTrial_D)/sum(~T_D)`;
- `FalseInvalidRate_D = sum(FalseInvalidTrial_D)/sum(T_D)`.

A rate with a zero denominator is `NotApplicable`, never zero. Report the
deployable and synthetic-diagnostic false-valid and false-invalid rates
separately for peak recovery, composition recovery, and overall validity.
Primary draft acceptance uses the deployable rates; synthetic-diagnostic
rates show what perfect knowledge of injected noise would add.

### 5.3 AICc/BIC scope and parameter count

For a fixed preprocessed response, background algorithm/parameters, retained
window, and noise model, calculate conditional peak-fit AICc/BIC from the peak
residual RSS with `n=number of retained samples` and `k=3*number of fitted
Gaussian peaks`. An added or removed fitted Gaussian changes `k` by three.
The Gaussian fit to pseudo-Voigt-generated data still has three fitted
parameters per peak. AICc is undefined when `n<=k+1` and must be reported as
such rather than forced finite.

The current Linear, Shirley, AsLS, and Tougaard backgrounds are preprocessing
transformations, not parameters jointly optimized under the peak-fit
likelihood. Their effective degrees of freedom are not mutually equivalent:
for example, an AsLS smoother would require a defensible effective dimension
such as a smoothing-matrix trace, while iterative Shirley/Tougaard procedures
do not have a common simple parameter count. Therefore their background
parameters are not added naively to `k`.

Label the existing quantities `ConditionalPeakFitAICc` and
`ConditionalPeakFitBIC`. They may rank peak-count alternatives only within the
same background preprocessing, window, response scaling, and likelihood.
They must not rank Linear versus Shirley versus AsLS versus Tougaard, or any
other cross-background pair. Cross-background information-criterion ranking
is omitted unless a future method supplies a common raw-data likelihood and
validated effective parameter counts. Phase 0H does not select the final
model.

## 6. Cell-level distribution acceptance gates

These are cell-level gates, distinct from the per-trial peak, composition,
and overall truth labels. They are proposed for mentor review and must be
frozen before Phase 0H execution.

| Gate | Proposed requirements across each 100-trial cell |
|---|---|
| A — nominal/in-model | 0 unhandled exceptions; convergence-rate Wilson lower bound >=95%. Median/95th-percentile absolute center error <=0.05/0.15 eV and relative FWHM error <=10%/25%. For truth fractions >=5%, median/95th-percentile relative area error <=5%/15%; for smaller peaks, median/95th-percentile absolute fraction error <=0.5/1.5 percentage points. For every applicable composition result, median/95th-percentile relative F/C and C/F error <=3%/10%, and absolute F-at.% error <=1/3 percentage points. The Wilson upper bound for each deployable peak, composition, and overall false-invalid rate must be <=5%. |
| B — difficult but still intended to be quantifiable | 0 unhandled exceptions; convergence-rate Wilson lower bound >=90%. Median/95th-percentile center error <=0.10/0.30 eV and relative FWHM error <=20%/50%. Major-peak relative area error <=10%/30%; minor-peak absolute fraction error <=1/3 percentage points. Composition relative F/C and C/F error <=5%/15%, and absolute F-at.% error <=1.5/5 percentage points. The Wilson upper bound for each deployable peak, composition, and overall false-invalid rate must be <=10%. |
| C — intentionally misspecified | 0 unhandled exceptions. No peak- or composition-recovery distribution gate is imposed. Separately among trials where each B-tier peak, composition, or overall truth label is false, the Wilson upper bound for the matching deployable false-valid rate must be <=5%. Convergence, residual structure, window containment, bound hits, and within-background conditional AICc/BIC remain descriptive and cannot be interpreted as successful chemistry. |
| Order — permutation invariance | All 100 paired noise-free permutations remain inside existing Phase 0G acceptance and differ from canonical order by <=1e-6 eV center, <=1e-6 relative area, and <=1e-6 relative composition. At PeakSNR 50, 95% of pairs differ by <=0.01 percentage points in F at.% and <=0.05 percentage points in each component fraction. |
| Scale — numerical/acquisition invariance | With supplied factors, all finite scale pairs differ from unscaled truth by <=1e-6 relative in restored physical areas and cross-region F/C. Q3 must withhold cross-region output in 100% of trials. |

Candidate exact-bound gate: the Wilson upper bound for the fraction of
otherwise nominal Gate A trials containing any exact-bound parameter must be
<=5%. **This criterion is not finalized and is explicitly flagged for mentor
review.** Exact- and near-bound frequencies will be reported regardless of
whether this gate is accepted, revised, or removed.

## 7. Checkpoint and deterministic resume requirements

The future harness must persist a run manifest before its first trial. The
manifest contains the frozen plan version and SHA-256, every configuration
file and SHA-256, code revision plus dirty-diff SHA-256, MATLAB/toolbox
versions, platform, RNG algorithm, seed formula, cell list, and requested
trial count.

After every completed trial, write its seed IDs, generated parameters,
configuration snapshot, fit status, warnings, truth/QC labels, and all raw
metrics to a temporary file and atomically rename it into the cell checkpoint.
After each cell, write an immutable cell summary containing completed trial
IDs, Wilson counts/intervals, distribution summaries, and the next eligible
trial ID. Aggregate reports are rebuilt from checkpoints rather than treated
as the source of truth.

On resume, the harness must verify every manifest hash, enumerate completed
`(cellID,trialID)` pairs, skip them without rerunning, and continue with the
first missing trial using its predetermined seed. Wilson-triggered extensions
append trials 101–400 to the same cell. A plan/config/code fingerprint mismatch
must abort resume and require a new run ID; existing checkpoints are never
overwritten or silently mixed.

## 8. Review and execution order

1. Mentor approves or edits the matrix, SNR definition, truth/QC labels, and
   every numerical gate—especially the exact-bound criterion.
2. Freeze this document with a version identifier and retain the seed scheme.
3. Implement the harness without running aggregate trials.
4. Run the Phase 0G controls, then one-family-at-a-time cells.
5. Run the four combined cells only after independent-cell outputs are locked.
6. Publish all trials and failures; do not tune thresholds or production
   parameters from Phase 0H outcomes.
