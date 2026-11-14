# Phase 0H scientific conclusions v1.0.0

## Scope and provenance

This is read-only post-processing of the frozen final Phase 0H dataset. It uses 92 cells and 21,800 usable trials: 42 cells at final N=400 and 50 cells at N=100. No Monte Carlo trials were run during preparation of this report, no thresholds or model definitions were changed, and Sample C was not used.

- Frozen plan SHA-256: `1f932b278de41dc14154191833f45b5fcf55f3b5a01edd7a661ddcbcf2f556bf`
- Frozen final-summary SHA-256: `2d90e57a7fffd284597f521637c5e18c2bfee22d6e212206692c62a3bb7bf301`
- Frozen provenance SHA-256: `5b41766f2a30f4f44b17fb5cf9c70f9c71ff42c8bdcdc032cc0bae87fd62e9d7`
- Conclusions post-processing SHA-256: `e4ea97b895ca78b955e1c57e684fa210695cad98f475b29ae7d5b7b741c48e18`
- Source-integrity check after post-processing: passed

All gate counts below are the final mixed-N results after the predeclared N=400 extensions. They are not the preliminary N=100 outcomes.

## Executive summary

The optimizer almost always returned a numerical solution: 21,799 of 21,800 trials converged (99.9954%). That did not translate into chemically identifiable component fits. Every ordinary Gate A/B cell failed the frozen whole-pipeline gate, and all three paired A/B cells failed. FWHM was the most common peak-level problem: 34 cells and 10,289 of 20,500 applicable trials exceeded the assigned truth-error limit. Center, major-area, and minor-fraction failures were also widespread. Many failed cells still had median regional R² values around 0.99 or better, demonstrating that a good total-envelope fit is not evidence that individual components are correct.

Composition was more stable than individual peak recovery, especially for `ruoff_c1s_f1s_semi_sf3p95_v1` when its QC allowed a result. Across the 34 quantitative A/B cells, Model 1 met the assigned composition-only limits in 15 cells and failed in 19. Model 2 met them in 27 cells, failed in 3, and withheld all outputs in 4. These are descriptive model-only assessments against the frozen numeric limits; they do not replace the frozen whole-cell gate results, and Model 1 was not retroactively added to the frozen Gate A/B decision.

Model 2's advantage is conditional accuracy plus safety withholding. Its weakness is availability and dependence on the strict semi-covalent F1s position rule: 59.25% of G1 charging trials and 84% of G2 trials were withheld. The accepted charging-shift results are concentrated in an approximately 0 to +0.2 eV shift interval. This directly supports investigating charge referencing before positional classification; it does not support widening the classification window without validation.

Gate C safety behavior was mixed: 22 of 45 cells passed and 23 failed. All four explicit label-mutation cells were safely withheld, with zero dangerous acceptances among 400 injected trials. All six acquisition-scale-error cells also passed through withholding. In contrast, small omitted/extra components, 1% `F_other`, a 2% substrate peak, a 2% shoulder, quadratic-background mismatch, and one combined-stress case produced dangerous false-valid behavior.

The SF sweep behaved exactly as the equation predicts. A ±5% change in S_F moved F/C by approximately −4.76%/+5.26% and F at.% by about 0.71–0.79 percentage points; a ±10% change moved F/C by approximately −9.09%/+11.11% and F at.% by about 1.36–1.65 points. Sensitivity-factor choice is therefore a direct systematic composition uncertainty, not an optimizer failure.

## Final frozen gate outcomes

| Gate class | Pass | Fail | Descriptive only |
|---|---:|---:|---:|
| Gate A | 0 | 11 | 0 |
| Gate A paired | 0 | 2 | 0 |
| Gate B | 0 | 20 | 0 |
| Gate B paired | 0 | 1 | 0 |
| Gate C | 22 | 23 | 0 |
| Order | 1 | 0 | 0 |
| Scale | 2 | 2 | 0 |
| Descriptive sensitivity cells | 0 | 0 | 8 |

## Three separate validation questions

### A. Spectrum reproduction

Numerical convergence was excellent, but it was not diagnostic of correctness. The single preserved scientific nonconvergence occurred in the strongest bound/overlap cell, F15_W3. Many failed cells still had median C1s/F1s R² at or above approximately 0.99. Examples include F04_V2, where median R² was about 0.9903/0.9957 while the worst-peak 95th-percentile center error was 2.00 eV and Model 1's 95th-percentile F/C error was 99.5%; and F15_W3, where median R² was about 0.9904/0.9956 while component and composition recovery were catastrophic. Residual/RMSE/R² are necessary diagnostics, but they cannot establish chemical identifiability by themselves.

### B. Individual peak recovery

Peak recovery is the main reason the strict A/B gates failed. Across the 20,500 trials to which A/B/C truth-error limits were assigned, 10,289 exceeded a FWHM criterion, 7,132 a center criterion, 5,412 a major-area criterion, and 4,652 a minor-fraction criterion. The repeated 150% worst-peak FWHM error and near-bound frequency of 100% in most fitting cells indicate that at least one component frequently sits near an allowed limit. The near-bound statistic is therefore sensitive but nonspecific; the exact-bound and paired-bound results are more discriminating.

### C. Composition recovery

`ruoff_c1s_main_cf_v1` is always numerically available in the evaluated A/B cells, but it is less robust to overlap, shape mismatch, background behavior, charging, and combined stress. It met the assigned composition-only limits in 15/34 A/B cells and failed in 19/34. Its worst A/B 95th-percentile errors were 99.5% in F/C and 31.74 percentage points in F at.%.

`ruoff_c1s_f1s_semi_sf3p95_v1` met assigned composition-only limits in 27/34 A/B cells, failed in 3/34 (SNR 20, pseudo-Voigt eta 0.8, and matched Tougaard), and fully withheld in 4/34 (strong overlap, matched Shirley, strong bound/overlap, and combined stress C2). Among cells with quantitative output, its worst A/B 95th-percentile errors were 19.56% in F/C and 2.66 percentage points in F at.%. High withholding in several otherwise composition-accurate cells means this accuracy is conditional and must be reported together with availability.

## Model comparison

| Primary model | A/B meets assigned composition limits | A/B fails | A/B fully withheld | Main strength | Main weakness |
|---|---:|---:|---:|---|---|
| `ruoff_c1s_main_cf_v1` | 15 | 19 | 0 | No cross-region acquisition scale; always returns a value | Strongly inherits C1s component non-identifiability and can return unsafe values without withholding |
| `ruoff_c1s_f1s_semi_sf3p95_v1` | 27 | 3 | 4 | Better conditional composition stability and effective safety withholding | Requires valid cross-region scaling and a position/label-qualified semi-covalent F1s component; can lose availability under charging or ambiguity |

The first noise level at which both models fail their assigned composition limits is PeakSNR 20. Model 1 fails already at the mildest pseudo-Voigt mismatch tested (eta=0.2), the mildest overlap cell, and the matched-linear background cell. Model 2 remains within composition limits through eta=0.5 and the milder overlap cases when quantitative, but fails at eta=0.8 and matched Tougaard; matched Shirley and severe overlap are withheld rather than quantified.

## Family-by-family interpretation

The full 92-row table contains the requested medians, 95th percentiles, model errors, QC rates, and failure reasons. The table below is the compact family interpretation; ranges such as N=100/400 mean that cells in the family have those final sample sizes.

| Family | Cells/scenario | Final N | Frozen result | Scientific interpretation |
|---|---|---:|---|---|
| 1 Noise | F01_N1–N3, PeakSNR 100/50/20 | 400 each | 0/3 pass | Convergence stayed 100%. Peak widths failed even at SNR 100; centers/areas deteriorated with noise. Both models first fail composition limits at SNR 20. Model 2 withheld 44–48%. |
| 2 Initial conditions | moderate 1 start; broad 1/5/10 starts | 400 each | 0/4 pass | Five and ten starts did not restore component truth and did not reduce Model 2 withholding relative to one broad start. Selecting a lower residual among more starts can select a chemically wrong decomposition. |
| 3 Peak order | noise-free and noisy canonical/permuted pairs | 100/400 | Order pass; noisy A fail | Pair criterion passed in both cells. The noisy cell failed ordinary peak/composition criteria, not order invariance. |
| 4 Overlap | spacing factor 0.75/0.50; FWHM 1.0/1.4 eV | 100/400 | 0/4 pass | Strong non-identifiability despite high R². Model 1 fails from the first overlap stress. Model 2 remains composition-accurate when quantitative in V1/V3/V4, but V2 is fully withheld. |
| 5 Missing/extra peaks | zero, omitted, extra, unmodelled C, F_other | 100/400 | 5 pass, 19 fail | Primary dangerous-false-valid family. Small or absent components are often not diagnosed safely. The 1% F_other cell failed with 32.25% overall false-valid; 5% passed; 10% failed a composition-dimension false-valid criterion despite zero overall false-valid. |
| 6 Peak shape | pseudo-Voigt eta 0.2/0.5/0.8 fit as Gaussian | 100/400 | 0/3 pass | Model 1 composition fails from eta 0.2. Model 2 meets limits at eta 0.2/0.5 and fails at eta 0.8. Peak recovery fails throughout. |
| 7 Background | matched/mismatched Linear, Shirley, Tougaard, quadratic, zero→AsLS | 100/400 | 3 pass, 4 fail | Matched Linear, Shirley, and Tougaard all fail strict A recovery; Shirley is fully withheld and Tougaard also fails Model 2 composition. Mismatched Shirley/Tougaard and zero→AsLS Gate C passes are largely safe rejection, not accurate recovery. Quadratic→Linear is dangerous false-valid. No AICc/BIC cross-family ranking was used. |
| 8 Window truncation | trim low/high/both by 0.5/1/2 eV | 100/400 | 0/9 pass | Peak widths and false-invalid behavior fail Gate B. Both composition models remain within B composition limits when quantitative, showing aggregate chemistry can survive while component recovery does not. Model 2 withholding is 41.25–65%. |
| 9 Scale controls | exact normalized, file-unit, unknown scale | 100 | 1 pass, 2 fail | Q1/Q2 have essentially exact peak recovery but fail the Scale gate because QC withholds all compositions; this is availability/QC coupling, not numerical normalization error. Q3 passes its unknown-scale safety condition with all trials QC-invalid and no false-valid result. |
| 10 Charging shift | common ±0.25 and ±0.50 eV | 400 | 0/2 pass | Model 1 composition fails both cells. Model 2 stays accurate when released, but withholding rises from 59.25% to 84%. Accepted results cluster near the strict semi-covalent positional window. |
| 11 Acquisition-scale error | ±10% on F, C, or both | 100 | 6/6 Gate C pass | Incorrect scaling is correctly prevented from producing an accepted cross-region result: Model 2 is withheld in 100% of trials. These passes demonstrate safe rejection, not immunity to acquisition-scale error. |
| 12 Sensitivity sweep | S_F around 3.95 and 4.118, multipliers 0.9–1.1 | 100 | 2 Scale pass; 8 descriptive | Exact inverse dependence of F/C on S_F. ±5% S_F gives about 4.76–5.26% F/C error; ±10% gives about 9.09–11.11%. |
| 13 Label misclassification | swaps, removal, duplicate semi label | 100 | 4/4 Gate C pass | All 400 label-mutated trials were withheld; dangerous acceptance was zero. This is strong safety behavior but has an expected availability cost. |
| 14 Substrate/shoulder | 684.0 eV 2/10%; 685.8 eV 2/5% | 100/400 | 2 pass, 2 fail | The 2% substrate and 2% shoulder are dangerous false-valid cases; the 10% substrate and 5% shoulder are detected/withheld sufficiently to pass. Detection is amplitude-dependent. |
| 15 Bound sensitivity | center, FWHM, severe overlap pair | 100/400 | 0/3 pass | All paired bound criteria fail. W3 contains the one scientific nonconvergence and catastrophic component/composition error. Bounds materially influence the inferred chemistry. |
| 16 Combined stress | C1–C4 predeclared combinations | 100/400 | 1 pass, 3 fail | C1 has accurate conditional Model 2 composition but fails peaks; C2 is fully withheld; C3 is dangerous false-valid; C4 passes through complete withholding. |

## Important physical and modeling findings

- **Noise:** composition is usable before peak-level identifiability is. At PeakSNR 100 and 50, both models meet composition-only limits, yet whole-cell A gates fail, driven especially by FWHM and QC behavior. At PeakSNR 20, both models fail composition limits.
- **Random starts:** more starts did not produce monotonic scientific improvement. Five/ten starts can improve an objective while retaining or worsening component ambiguity. Multi-start count should not be selected from residual alone.
- **Peak-order invariance:** the paired order criterion passes. The noisy order cell's failure is attributable to the base fit, not array order.
- **Overlap:** this is a dominant failure mode. Broad/closely spaced peaks produce accurate-looking envelopes with wrong components. Model 2 is safer because severe cases are withheld.
- **Peak-shape mismatch:** Gaussian fits are not robust to even mild pseudo-Voigt truth at the individual-peak level. Model 2 composition tolerates eta up to 0.5 in this fixture; Model 1 does not.
- **Backgrounds:** no background family is declared universally superior. Recovery stability, residual structure, and withholding show that estimator/model interaction matters. Cross-background AICc/BIC ranking is not used because preprocessing baselines do not have defensibly comparable effective parameter counts.
- **Truncated windows:** aggregate composition is relatively stable, but peak widths/areas and deployable QC are not. Full analytic area and in-window area must remain distinct in real-data reporting.
- **Missing/extra peaks:** QC is not sufficiently reliable for low-amplitude or omitted components. This is a stronger concern than optimizer convergence.
- **681.3–681.6 eV F_other:** the locked model can miss this component. The 1% case is dangerous; 5% is detected adequately; 10% still fails a composition-dimension false-valid criterion. This component should be explicitly investigated on A/B rather than silently relabeled ionic F.
- **Charging:** the current strict 686.7–686.9 eV semi-covalent rule is highly shift-sensitive. A charge-reference investigation is required on Samples A/B before using Model 2 quantitatively.
- **Acquisition scaling:** errors are safely withheld in the predeclared tests. This confirms that unknown/incorrect acquisition factors must block cross-region quantification; it does not justify assuming unity.
- **Sensitivity factors:** SF uncertainty propagates deterministically and materially. It should be reported as systematic uncertainty and kept separate from fitting uncertainty.
- **Chemical labels:** explicit mutations are caught and withheld. The label-QC safety behavior is strong.
- **Substrate/shoulder features:** small 2% features can evade QC; larger 5–10% features are detected more safely.
- **Bounds:** boundary choices materially change fitted components and composition. Frequent exact/near-bound fits require component-level audit before accepting A/B results.
- **Combined stress:** multiple individually tolerable effects are not guaranteed to remain tolerable in combination. Safe withholding works in some combinations but not C3.

## Gate-failure decomposition

The counts overlap; one trial or cell may fail several criteria. The A/B/C truth-error denominator is 20,500 trials. Withholding uses all 21,800 trials. Bound sensitivity reports the 900 paired trials evaluated. Misclassification reports dangerous acceptance among the 400 injected label-mutation trials.

| Category | Failing cells | Affected trials | Denominator | Interpretation |
|---|---:|---:|---:|---|
| Center accuracy | 28 | 7,132 | 20,500 | Peak-identifiability failure |
| FWHM accuracy | 34 | 10,289 | 20,500 | Most frequent peak-identifiability failure |
| Major peak area | 26 | 5,412 | 20,500 | Peak quantification failure |
| Minor peak fraction | 26 | 4,652 | 20,500 | Minor-component identifiability failure |
| F/C | 34 | 3,593 | 20,500 | Aggregate fluorination failure |
| F at.% | 33 | 2,513 | 20,500 | Aggregate fluorination failure |
| False-valid | 23 | 1,941 | 20,500 | Unsafe QC acceptance |
| False-invalid | 21 | 1,162 | 20,500 | Unnecessary QC rejection |
| Label misclassification | 0 | 0 | 400 | Zero dangerous acceptances; all injected mutations withheld |
| Withholding | 77 | 12,294 | 21,800 | Protective in some cells, availability loss in others |
| Bound sensitivity | 3 | 900 | 900 | All three paired bound cells failed |
| Convergence | 0 gate-failing cells | 1 | 21,800 | One preserved scientific nonconvergence; cell-level convergence gate still passed |

The dominant strict-gate problem is individual-peak identifiability, not universal failure of aggregate fluorination. FWHM error alone affected about half of applicable trials, while F/C and F-at.% errors affected about 17.5% and 12.3%, respectively. That distinction is especially clear for Model 2 and the truncation cells.

## Implications for Sample A/B development

The following are evidence-supported investigations, not production changes:

1. Establish a defensible common energy reference/charging correction before applying the strict F1s positional classification.
2. Compare Gaussian and pseudo-Voigt peak shapes on Samples A/B using residual structure, component stability, and held-out criteria; do not choose using Sample C.
3. Compare physically plausible Linear/Shirley/Tougaard backgrounds on A/B. Do not rank preprocessing families with AICc/BIC; examine residual structure and area stability.
4. Audit center/FWHM bounds wherever exact or near-bound flags recur, using predeclared alternatives and paired stability checks.
5. Recover acquisition metadata before reporting cross-region F/C. Unknown acquisition scaling must continue to block physical quantification.
6. Inspect A/B F1s spectra for a distinct 681.3–681.6 eV `F_other` contribution and for 684.0/685.8 eV substrate or shoulder structure.
7. Treat sensitivity-factor choice as a reported systematic uncertainty; retain both 3.95 and 4.118 profiles as documented alternatives until the physical basis is resolved.
8. Use multi-start fitting only with component/QC stability checks. More starts are not justified by residual improvement alone.
9. Preserve Sample C as blind validation. Do not inspect or fit it while selecting A/B settings.

## Deliverable map

- `model_comparison.csv`: model-only A/B and Gate-C quantitative/withheld counts
- `family_summary.csv`: all 16 stress families
- `per_cell_summary.csv`: complete 92-cell metrics and failure reasons
- `gate_failure_decomposition.csv`: criterion and trial-count decomposition
- `model1_robustness.csv` and `model2_robustness.csv`: complete model-by-cell results
- `qc_false_valid_false_invalid.csv`: peak, composition, and overall QC rates kept separate
- `sensitivity_factor_sweep.csv`: both S_F profiles and all multipliers
- `sample_AB_investigation_priorities.csv`: evidence-linked A/B development issues
- `plots/`: nine post-processing figures requested in the frozen interpretation prompt

No real-data fitting or configuration selection was performed.
