# Sample A/B model-development protocol — review draft v0.1.1

Status: **review draft; not frozen and not authorized for fitting**  
Date: 2026-10-17  
Scope: mentor-approved transition from frozen Phase 0H to real Sample A/B
model development. Sample C remains blind.

This protocol is a design artifact only. It does not alter production
configuration, execute a real-data fit, or change any frozen Phase 0H result.
After mentor approval, the approved text and candidate matrix will be copied
to a frozen v1.0.0 protocol with hashes before Sample A is opened by the new
development runner.

## 1. Locked constraints and data firewall

The following definitions are immutable during A/B model development:

- `ruoff_c1s_main_cf_v1`;
- `ruoff_c1s_f1s_semi_sf3p95_v1`;
- `ruoff_reproduction_sf3p95_v1` (`S_C=1`, `S_F=3.95`);
- `thermo_k_alpha_sf4p118_v1` (`S_C=1`, `S_F=4.118`);
- the weighted and legacy C1s diagnostic formulas.

Sensitivity factors will never be estimated from Samples A or B. The profile
used for a physical result is chosen from documented instrument/provenance,
not agreement with a reference composition. The 3.95 profile remains the
Ruoff-reproduction profile; 4.118 is used only where Thermo K-Alpha provenance
justifies it.

The development runner will accept only sample IDs `A` and `B`. It will not
load any reference JSON while fitting, scoring, screening, bootstrapping, or
selecting a model. It will reject sample ID `C` and paths containing Sample C.
No Sample C spectrum, fit, summary, or composition result may be opened until
one configuration has been frozen from A/B evidence. Existing Sample C
reference metadata may remain for already-frozen arithmetic tests, but the
new development code will not import it.

Published Ruoff composition is a post-selection validation result. A separate
reporting command may load A/B references only after candidate metrics are
sealed and the selected configuration hash is recorded. Reference error is
not a candidate score, tie-breaker, bound choice, or peak-presence test.

## 2. Frozen Phase 0H provenance

This protocol derives only from the read-only final package
`results/phase0h_scientific_conclusions_v1_0_0`:

- frozen plan SHA-256:
  `1f932b278de41dc14154191833f45b5fcf55f3b5a01edd7a661ddcbcf2f556bf`;
- final-summary SHA-256:
  `2d90e57a7fffd284597f521637c5e18c2bfee22d6e212206692c62a3bb7bf301`;
- frozen provenance SHA-256:
  `5b41766f2a30f4f44b17fb5cf9c70f9c71ff42c8bdcdc032cc0bae87fd62e9d7`;
- dataset: 92 cells, 21,800 usable trials; 42 cells at `N=400` and 50
  at `N=100`.

No additional Monte Carlo trials are authorized by this protocol.

## 3. Actionable Phase 0H → A/B lessons

`Yes` below means the frozen trials demonstrated a material effect or a
material safety/availability consequence. It does not mean that Phase 0H
identified a universally superior real-data choice.

| Model dimension | Spectrum reproduction | Center | FWHM | Peak area | Model 1 | Model 2 | False-valid | Withholding | Quantitative evidence and A/B consequence |
|---|---|---|---|---|---|---|---|---|---|
| Noise | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | At PeakSNR 100/50/20, all three whole-cell gates failed; FWHM failed even at 100. Both models first failed composition limits at 20. Model 2 withheld 44–48%. Real fits require uncertainty and residual-structure checks, not R² alone. |
| Initial conditions | Yes | Yes | Yes | Yes | Yes | Conditional | Yes | Yes | Broad 1/5/10-start cells all failed. Five or ten starts did not restore truth or reduce withholding; a lower residual could select a chemically wrong basin. Starts are therefore stability probes, not a residual-minimization contest. |
| Peak overlap | Envelope can remain excellent | Yes | Yes | Yes | Yes | Conditional | Yes | Yes | All four overlap cells failed. In severe V2, median R² was about 0.9903/0.9957 while worst-peak center P95 was 2.00 eV and Model 1 F/C P95 error was 99.5%; Model 2 was fully withheld. Track component exchange and identifiability explicitly. |
| Peak shape | Yes | Yes | Yes | Yes | Yes | Yes at high mixing | Yes | Yes | Gaussian fits to pseudo-Voigt truth failed peak recovery for `eta=0.2/0.5/0.8`. Model 1 failed composition from `eta=0.2`; Model 2 met limits at 0.2/0.5 but failed at 0.8. A pseudo-Voigt candidate is justified. |
| Background | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Matched Linear, Shirley, and Tougaard all failed strict recovery. Shirley fully withheld Model 2; Tougaard Model 2 F/C P95 error reached 19.56%; quadratic→Linear was dangerous false-valid; zero→AsLS passed by 98.25% withholding, not recovery. Compare backgrounds, but never rank them with cross-background AICc/BIC. |
| Fitting window | Yes | Yes | Yes | Yes | Usually stable aggregate | Usually stable when released | Noisy safety signal | Yes | All nine truncation cells failed peak/QC Gate B while both compositions stayed within B limits when quantitative; Model 2 withheld 41.25–65%. Record in-window versus extrapolated areas and ensure full flanks are present. |
| Charging/global shift | Yes | Yes | Yes | Yes | Yes | Availability-dominant | Yes | Yes | For ±0.25/±0.50 eV, Model 2 withheld 59.25%/84%; released values remained conditionally accurate. This supports independent charge referencing, not widening 686.7–686.9 eV. |
| Missing/extra peaks | Yes | Yes | Yes | Yes | Yes | Yes | Strong effect | Yes | Five of 24 cells passed and 19 failed. The 1% `F_other` case had 32.25% overall false-valid; 2% substrate and 2% shoulder were dangerous false-valid. Optional components require residual and chemical evidence. |
| Acquisition scaling | No fit effect | No | No | Cross-region physical area | No | Decisive | Prevented unsafe result | 100% when wrong/unknown | All six ±10% scale-error cells passed through withholding. Numerical normalization is recoverable, but unknown relative acquisition scaling must block Model 2. |
| Sensitivity factor | No fit effect | No | No | No fit effect | No | Deterministic systematic | N/A | N/A | A ±5% `S_F` change produced about −4.76/+5.26% F/C and 0.71–0.79 percentage-point F-at.% shifts; ±10% produced −9.09/+11.11% and 1.36–1.65 pp. Keep this systematic separate from fit uncertainty. |
| Chemical label | No envelope effect | Classification uses center | No | Selects numerator | No | Decisive | Safely controlled | Yes | All 400 injected label mutations were withheld with zero dangerous acceptances. Preserve ID/label checks and never fall back to array index. |
| Bounds | Envelope can remain excellent | Yes | Yes | Yes | Yes | Conditional | Yes | Yes | All 900 paired Family-15 trials failed the bound-sensitivity criterion; W3 included the only scientific nonconvergence. Use paired modest widening only, and do not infer chemistry from a bound-limited optimum. |

Across all truth-gated trials, failures overlapped but were frequent: center
7,132/20,500; FWHM 10,289/20,500; major-area 5,412/20,500;
minor-fraction 4,652/20,500; F/C 3,593/20,500; F-at.% 2,513/20,500;
false-valid 1,941/20,500; false-invalid 1,162/20,500. There were 12,294
withheld outcomes among 21,800 trials and only one numerical
nonconvergence. Numerical convergence and high R² are therefore necessary
but not evidence of component truth.

Model-level context is kept descriptive: Model 1 met its composition-only
limits in 15/34 A/B cells and failed 19/34. Model 2 met 27/34, failed 3/34,
and fully withheld 4/34. Model 2's conditional accuracy does not override its
acquisition and positional prerequisites.

## 4. Exact small candidate matrix

The machine-readable source is
`config/development/ab_candidate_matrix_v0.1.1.json`. C1s and F1s are
developed independently. The seven candidates per region are one-factor
comparisons around a Gaussian/Linear/current-bound anchor; they are not a
Cartesian product.

| C1s ID | F1s ID | Shape | Background | Bounds | Purpose |
|---|---|---|---|---|---|
| `C01_G_L_CUR` | `F01_G_L_CUR` | Gaussian | Linear, 5 endpoint points | current | Anchor and simplest defensible preprocessing |
| `C02_PV_L_CUR` | `F02_PV_L_CUR` | area-normalized pseudo-Voigt, one region-shared fitted `eta` in [0,0.8], initial 0.2 | Linear | current | Test the Phase 0H-supported shape-mismatch failure without per-peak mixing over-parameterization |
| `C03_G_S_CUR` | `F03_G_S_CUR` | Gaussian | Shirley, 5 endpoint points, 50 iterations, tolerance `1e-5` | current | Test a physically plausible inelastic background; matched Shirley caused severe withholding in Phase 0H |
| `C04_G_T_CUR` | `F04_G_T_CUR` | Gaussian | Tougaard, `B=2866`, `C=1643` | current | Test a physically plausible loss background; Phase 0H showed material area/Model-2 sensitivity |
| `C05_G_A_CUR` | `F05_G_A_CUR` | Gaussian | AsLS, `lambda=1e6`, `p=0.01`, 20 iterations | current | Diagnostic only: retain the preserved implementation/defaults and test whether real residual evidence supports it; do not assume its safe-rejection Phase 0H pass means recovery |
| `C06_G_L_CWIDE` | `F06_G_L_CWIDE` | Gaussian | Linear | each center lower/upper widened by 0.25 eV, limited by window | Paired Family-15 W1 sensitivity probe; not a new production default |
| `C07_G_L_WWIDE` | `F07_G_L_WWIDE` | Gaussian | Linear | FWHM [0.4375,2.3125] eV instead of [0.75,2.0] | Paired Family-15 W2 sensitivity probe; not a new production default |

No tightened-bound candidate is proposed: Phase 0H did not test one, and
the observed bound sensitivity makes further tightening more likely to encode
a prior than reveal data-supported chemistry. No combined center/FWHM
widening is proposed because the corresponding severe-overlap probe was
catastrophic. The known legacy `C_CF23_C_O` reference/bound conflict is
recorded but will not be silently corrected from published composition or
center targets. Numerically, the current 288.1 eV lower bound and the
center-widened 287.85 eV lower bound both exclude the approximately 287.3 eV
Ruoff-reported component position. Whether to add a separately justified
candidate that contains 287.3 eV is an unresolved mentor decision in Section
11; no such candidate is included in v0.1.1. A larger bound revision requires
approval and a new protocol version before it is fit.

The pseudo-Voigt definition is
`(1-eta)*Gaussian + eta*Lorentzian`, with both basis curves normalized to
unit analytic area. One shared `eta` adds one regional parameter. Per-peak
`eta` values are excluded from v0.1.1 because the Phase 0H identifiability
results do not justify that many extra degrees of freedom.

### 4.1 Initialization stability, not residual hunting

Each regional candidate uses five starts: the configured nominal start and
four deterministic diagnostic perturbations. Seeds and distributions are
specified in the candidate JSON. Centers are sampled directly from the
intersection of nominal ±0.20 eV and legal bounds; values are never clipped
onto bounds. FWHM is sampled within 0.85–1.15 times nominal and legal bounds;
areas use `LogU(0.67,1.50)`.

At least four of five starts must converge to one stable basin. A basin is
stable only if ID-matched centers span no more than 0.10 eV, FWHMs differ by
no more than 20% relative to their median, major component fractions span no
more than 3 percentage points, and minor component fractions span no more
than 1.5 points. The best residual may represent the candidate only when this
stability condition is satisfied. Otherwise the candidate is labeled
initialization-unstable; the lowest residual is still reported but is not
selected as chemically established.

### 4.2 Conditional F1s structure probes

The locked three-peak model remains the base. The following are diagnostic
candidate additions, never automatic production components:

- `F_OTHER_6815`: 681.0–682.0 eV, initial 681.5 eV, interpreted only as
  physisorbed/entrapped/interface fluorine;
- `F_SUBSTRATE_6840`: 683.6–684.4 eV, initial 684.0 eV;
- `F_SHOULDER_6858`: 685.4–686.2 eV, initial 685.8 eV.

At most one is added in a probe. The same definition must be run on A and B.
The required sequence is:

1. **Non-bootstrap trigger:** window coverage, a reproducible signed residual
   feature over at least three points, amplitude at least three times a
   predeclared truth-blind robust residual scale, independent chemical
   plausibility, and within-background `Delta BIC <= -10` and
   `Delta AICc <= -6`.
2. **Bootstrap eligibility:** passing that non-bootstrap residual/chemical/IC
   trigger makes the optional-probe candidate eligible for bootstrap.
3. **Bootstrap support:** at least 450/500 valid replicates and a 95% area
   interval whose lower endpoint is greater than zero, with its center/label
   remaining chemically consistent.
4. **Supported activation:** only after bootstrap support may the extra
   component be adopted into a selected configuration.

Bootstrap support is therefore not required merely to execute the diagnostic
probe. It is required before the component is considered supported or active
in a selected model. A component is never activated to move a composition
result toward a publication. None of these components is the Model-2
semi-covalent numerator.

## 5. Predefined model-selection criteria

Selection is region-specific and lexicographic. If no candidate satisfies a
tier, development stops for a revised, independently justified protocol; the
least bad fit is not silently promoted.

### Tier 1 — executable and identifiable

1. All required outputs are finite and at least four of five starts have
   positive exit flags.
2. The four-start stable-basin rule in Section 4.1 passes.
3. No parameter is exactly at a bound in the stable basin. A near-bound flag
   requires the paired bound probe and cannot be dismissed by high R².
4. Peak IDs remain one-to-one. F1s labels are assigned by fitted position,
   never index; ambiguous or duplicate semi-covalent labels withhold Model 2.
5. The retained window contains both flanks of every quantitative component.
   Analytic and in-window areas are reported separately.

### Tier 2 — spectrum and residual evidence

For every start report RMSE, R², residual mean/SD/max, residual runs, and
lag-1 autocorrelation. The Phase 0H deployable criterion `|rho1|<=0.20` is a
predeclared warning boundary; a candidate with reproducible residual
structure is not considered adequate merely because its R² is high.

Conditional AICc/BIC are used only for fits to the same response, window,
background preprocessing, and likelihood. They may compare Gaussian versus
pseudo-Voigt or a conditional added peak within one background. They may not
rank Linear versus Shirley versus Tougaard versus AsLS because those
preprocessing estimators lack comparable effective parameter counts. When
cross-background selection follows the deterministic hierarchy below rather
than an information-criterion ranking.

Pseudo-Voigt replaces Gaussian only if it passes Tier 1, improves both AICc
and BIC by at least 6 within the Linear family, removes reproducible residual
structure, and its bootstrap `eta` interval does not collapse onto zero.

#### Deterministic cross-background hierarchy

For the same sample and region, compare background candidates in this order:

1. **Tier eligibility:** a candidate passing all applicable Tier-1 checks
   outranks any candidate that fails one. If none passes, stop; do not select
   the least bad background.
2. **Initialization stability:** among eligible candidates, more starts in the
   stable basin outrank fewer (`5/5` over `4/5`). An isolated lower-residual
   basin never wins this step.
3. **Residual structure on a common domain:** reconstruct residuals on the
   same max-normalized raw-intensity domain as
   `y_normalized-(background+peak_envelope)`. A candidate with both
   `|rho1|<=0.20` and runs-test `p>=0.05` outranks one failing either check.
   Among candidates in the same residual class, a candidate is materially
   better only when common-domain NRMSE is lower by more than 5% relative
   without worsening `|rho1|` by more than 0.05, or `|rho1|` is lower by more
   than 0.05 without worsening NRMSE by more than 5%.
4. **Parameter and bound sensitivity:** fewer recurrent exact-bound events
   outrank more; if equal, fewer near-bound components outrank more only when
   the count differs by at least two across the five starts. A background is
   penalized when its paired estimates vary beyond 0.15 eV center, 25% FWHM,
   15% relative major area, or 1.5 percentage points minor fraction under the
   predeclared modest bound probe.
5. **Bootstrap identifiability:** a valid-replicate rate higher by more than
   5 percentage points is materially better. If valid rates are closer, a
   candidate is materially better only when the median relative width of its
   applicable center/FWHM/fraction 95% intervals is at least 10% smaller and
   no applicable interval is more than 10% wider.

Two candidates are **practically indistinguishable** only if they have the
same Tier-1 status and stable-start count; the same residual-structure class;
common-domain NRMSE within 5% relative and `|rho1|` within 0.05; exact-bound
counts equal and near-bound counts differing by fewer than two; all paired
parameter changes inside the stated stability limits; bootstrap valid rates
within 5 percentage points; and applicable bootstrap interval widths within
10% relative. If the hierarchy reaches this equivalence without a material
winner, select Linear by predeclared parsimony. Published composition and
cross-background AICc/BIC never break the tie.

### Tier 3 — physical peak/QC evidence

- Centers and FWHMs must be chemically plausible without using published
  fluorination percentages. Raw and calibrated centers are both retained.
- Current bounds are preferred. A widened-bound result is eligible only when
  a recurrent current-bound hit disappears, the estimate remains away from
  the new bound, the stable basin improves, and the same change is not merely
  trading area between unresolved peaks.
- Report exact/near-bound flags per parameter and their frequencies across
  starts and bootstrap replicates.
- For C1s, report covariance/correlation and paired area changes between
  `C_F` and `C_CF_sp3`, `C_CF23_C_O`, and adjacent fluorinated components.
  If `|rho|>=0.90` or the `C_F` fraction 95% interval is wider than 10
  percentage points, flag Model 1 as component-exchange limited.
- For F1s, retain ionic/substrate-bound, semi-covalent, covalent, and possible
  681.5-eV other-F evidence separately. An unexplained residual feature is
  not relabeled to preserve the locked three-peak chemistry.

### Tier 4 — robustness across A and B

The identical matrix and criteria are applied first to A, then to B. A model
must retain its qualitative residual behavior, parameter stability, and
component interpretation in both samples. Modest background/bound changes
must not cause changes larger than 0.15 eV in centers, 25% in FWHM, 15%
relative in major areas, 1.5 percentage points in minor fractions, or 10%
relative in Model-1 F/C without being labeled method-sensitive. These are
the Phase 0H A-tier per-trial limits, reused here as stability flags—not as
claims of real-data truth.

Only after Tiers 1–4 and bootstrap review are sealed may a separate report
compare predictions with published A/B composition. Those comparisons cannot
retroactively change the selected configuration.

## 6. C1s and F1s development tracks

### C1s

The objective is a defensible six-component decomposition. All six stable
IDs are retained in the base candidates. Development emphasizes residual
structure, bounds, FWHM plausibility, bootstrap identifiability, and area
exchange involving the main `C_F` component. Model 1 is calculated and
tracked after each fit because it is scientifically relevant, but it is not
an optimizer target or selection score. Weighted/legacy values remain labeled
diagnostics.

### F1s, classification, and charging

F1s development retains position-derived chemical classification. The broad
configured class boundaries remain unchanged. The strict 686.7–686.9 eV
Model-2 positional rule also remains unchanged and is not a fit constraint.
The semi-covalent peak is never forced into that interval.

Two energy states are recorded:

- `E0_REPORTED_AXIS`: the supplied binding-energy axis, unchanged;
- `E1_DOCUMENTED_COMMON_SHIFT`: permitted only when an acquisition record or
  an independent calibration feature establishes the shift. The calibration
  feature cannot be the semi-covalent F1s peak and cannot be chosen to improve
  published fluorination agreement.

The correction, anchor, expected energy, measured energy, sign convention,
uncertainty, affected acquisitions, and provenance are stored. If C1s and F1s
were acquired in different charging contexts, each requires its own defensible
reference; a common shift is not assumed. With no independent reference, E0
is reported, absolute-position uncertainty is explicit, and position-qualified
Model 2 is withheld.

For a quantitative Model-2 report, the semi-covalent label must be unique in
the point fit, at least 95% of valid bootstrap replicates must preserve that
unique label, and its bootstrap 95% center interval must lie wholly inside
686.7–686.9 eV. This is a reporting/QC condition; it does not change the
composition equation or its allowed range.

## 7. Acquisition-scaling provenance audit

Max normalization is numerical only. Fitted normalized areas are first
multiplied by each region's stored software normalization scale. Cross-region
physical area additionally requires the relative acquisition response. The
audit records, for C1s and F1s separately:

- original raw versus CPS/export units and every export normalization;
- acquisition date/run and whether the regions share one session;
- pass energy, dwell time, energy step, number of scans/sweeps, X-ray power,
  spot size, analyzer lens/transmission mode, detector settings, and any
  instrument transmission correction;
- charge-neutralization and binding-energy calibration records;
- the formula and provenance for each acquisition scale factor and its
  uncertainty.

Only the relative C1s/F1s acquisition factor is required to cancel a common
overall unit multiplier, but it must be documented. CPS data must not be
divided by dwell time or scans twice. Figure-digitization or Ruoff-specific
benchmark corrections are never promoted to general production corrections.

`xps.buildQuantificationScaling` remains the numerical gate. Model 2 is
quantitative only when both regional factors are known, positive, finite, and
provenanced. If relative scaling remains unknown, F1s is still fitted and
classified, but Model 2 is recorded as withheld; unity is not assumed.

## 8. Bootstrap and uncertainty plan

After the non-bootstrap screen, at most two QC-eligible finalists per region
enter uncertainty analysis. Use 500 deterministic replicates per finalist.
The bootstrap never sees published composition.

1. Form raw-domain residuals from the normalized observation minus the sum
   of the candidate background and fitted peak envelope.
2. Center the residuals. Use a circular moving-block residual bootstrap to
   preserve local correlation. Choose block length from the first nonpositive
   lag of the residual autocorrelation, bounded to 3–25 samples; if no such lag
   exists, use 25. Record the selected length.
3. Generate `y* = background + fitted peaks + resampled residual`, then rerun
   the candidate's background preprocessing and fit. Do not clip negative
   bootstrap intensities.
4. Use seeds
   `610000000 + 100000*sample_index + 10000*region_index +
   100*candidate_index + replicate_index`, MATLAB `twister`.
5. Preserve IDs. Exceptions, nonconvergence, label ambiguity, and withheld
   composition are counted rather than silently discarded. At least 450/500
   valid replicates are required to quote a two-sided interval; otherwise the
   candidate is labeled bootstrap-unstable.

Report median and percentile 2.5/97.5 intervals for centers, FWHMs, analytic
and in-window component areas, area fractions, shared `eta`, Model-1 F/C and
F-at.%, and all component-area correlations. Model-2 uncertainty is reported
only when acquisition scaling is valid. Pair C1s and F1s replicate indices,
resample the regional residuals independently, restore software/acquisition
scales, and propagate documented acquisition-factor uncertainty. Report
Model-2 F/C and F-at.% intervals, label/position acceptance frequency, and
withholding frequency.

These intervals are conditional empirical fit/model uncertainties under the
selected peak, background, residual-resampling, window, and bound assumptions.
They are not a complete physical XPS uncertainty budget. Binding-energy
calibration, acquisition-scaling uncertainty, and sensitivity-factor
systematics remain separate, named uncertainty contributions and are not
made to disappear inside a bootstrap interval.

Sensitivity-factor uncertainty is not folded into the fit bootstrap. It is a
separate systematic table using the two frozen profiles where their
provenance is applicable.

## 9. Ordered A/B workflow and freeze points

1. Mentor reviews this v0.1.1 document, thresholds, and candidate JSON.
2. Approved artifacts become immutable v1.0.0 files with SHA-256 hashes.
3. The acquisition audit is completed as far as records allow; unknown items
   are explicitly retained.
4. Run every C1s and F1s base candidate on Sample A without loading reference
   composition. Store all starts, residuals, peaks, flags, and fingerprints.
5. Review Sample A only against the predefined spectral/QC criteria. Apply
   conditional F1s probes only when their predeclared triggers are met.
6. Seal the Sample A candidate report. Run the identical definitions on
   Sample B; do not revise the matrix between samples.
7. Screen A/B together, bootstrap no more than two eligible finalists per
   region, and select/freeze one configuration. If none is adequate, issue a
   versioned protocol amendment; do not pick by published composition.
8. Seal selected configuration, code/config fingerprint, uncertainty report,
   and acquisition-scaling status.
9. Only then run a separate A/B publication-reference comparison.
10. Only after all previous outputs are immutable may Sample C be opened once
    for blind validation. No C-driven refitting is allowed.

## 10. Implementation file plan after protocol approval

No implementation listed here is authorized until the protocol is frozen.

| File | Action | Purpose / constraint |
|---|---|---|
| `PHASE_1_AB_MODEL_DEVELOPMENT_PROTOCOL_v1.0.0.md` | add from approved draft | Frozen human-readable protocol |
| `PHASE_1_AB_PROTOCOL_LOCK_v1.0.0.json` | add | Hash protocol, candidate matrix, production base config, composition profiles, sensitivity profiles, and code revision |
| `config/development/ab_candidate_matrix_v1.0.0.json` | add from approved draft | Machine-readable candidate definitions; never overwrite `legacy_current_v1.json` |
| `config/development/ab_acquisition_manifest_v1.0.0.json` | add | Region-by-region acquisition metadata, relative-scale derivation, uncertainty, and provenance |
| `+xps/evaluatePeakShape.m` | add | Area-normalized Gaussian and shared-eta pseudo-Voigt basis |
| `+xps/fitSpectrum.m` | change after tests | Add the shared-eta pseudo-Voigt option while keeping the Gaussian code path and results backward compatible |
| `+xps/applyBindingEnergyCalibration.m` | add | Apply and record only independently justified shifts; preserve raw centers |
| `+xps/auditAcquisitionScaling.m` | add | Validate metadata and produce the existing scaling structure or a withheld status |
| `+xps/scoreABCandidate.m` | add | Compute truth-blind residual, bound, stability, window, label, and within-family IC metrics; contains no reference-composition input |
| `+xps/bootstrapSpectrumFit.m` | add | Deterministic moving-block bootstrap with failure/withholding accounting |
| `runABModelDevelopment.m` | add | Non-graphical A/B-only runner with the Sample-C/reference firewall and immutable per-candidate outputs |
| `reviewABCandidateFits.m` | add | Build the blind spectral/QC comparison and apply the lexicographic criteria |
| `freezeABSelectedConfiguration.m` | add | Freeze one selected regional configuration and all fingerprints before reference comparison |
| `evaluateABReferencesAfterFreeze.m` | add | Separate post-freeze A/B Ruoff-reference report; cannot influence selection artifacts |
| `testABDevelopmentProtocol.m` | add | Validate matrix size/IDs, one-factor structure, hashes, locked formulas, and C/reference firewall |
| `testPseudoVoigtFit.m` | add | Area normalization, `eta=0/1` limits, parameter count, and Gaussian backward compatibility |
| `testBindingEnergyCalibration.m` | add | Sign, common/independent shifts, raw-center preservation, and no semi-peak self-calibration |
| `testAcquisitionScalingAudit.m` | add | Known/unknown relative scale, units, no double normalization, and withholding |
| `testABBootstrap.m` | add | Fixed seeds, block construction, interval schema, component IDs, and failed-replicate accounting |
| `testABReferenceFirewall.m` | add | Reject Sample C and prove reference files cannot be loaded in fit/selection mode |

Existing `runSampleABenchmark.m` remains a benchmark/reporting artifact and is
not the selection runner. Existing production composition/config files are not
edited during candidate search. Once a model is selected, it receives a new
versioned configuration file; `config/legacy_current_v1.json` is retained for
reproducibility.

## 11. Review decisions still required

The mentor-review checklist is:

- **`C_CF23_C_O` center bounds:** the legacy lower bound is 288.1 eV. The
  proposed +0.25 eV center-widening candidate lowers it only to 287.85 eV.
  Neither contains the approximately 287.3 eV Ruoff-reported component
  position. Should a separately and chemically justified center-bound
  candidate containing approximately 287.3 eV be added before freeze? It is
  not included without explicit approval.
- **Optional F1s sequence:** approve the sequence
  non-bootstrap residual/chemical/IC trigger → bootstrap eligibility →
  bootstrap support → adoption. Bootstrap is not a prerequisite for running
  the diagnostic probe, but it is mandatory before selected-model activation.
- **Cross-background hierarchy:** approve the ordered Tier, initialization,
  common-domain residual, bound-sensitivity, and bootstrap-identifiability
  comparison and the numerical definition of practical indistinguishability;
  Linear is the deterministic final tie-breaker.
- **Uncertainty scope:** confirm that moving-block bootstrap intervals are
  conditional empirical fit/model uncertainty only, while calibration,
  acquisition scaling, and sensitivity-factor systematics remain separate.
- Approve the shared-eta pseudo-Voigt parameterization; exact five-start
  stability limits; optional-component trigger/support thresholds; real-data
  stability flags; 500-replicate moving-block bootstrap; and Model-2 bootstrap
  positional QC.

Approval freezes these choices before any Sample A candidate is fitted.

