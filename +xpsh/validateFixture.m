function result = validateFixture(fixture)
%VALIDATEFIXTURE Validate a generated Phase 0H fixture without fitting it.

errors = strings(0,1);
warnings = strings(0,1);

if ~fixture.no_fitting_performed
    errors(end+1) = "Dry-run fixture incorrectly reports that fitting occurred.";
end
for regionName = ["C1s","F1s"]
    region = fixture.(regionName);
    if isempty(region.energy) || any(diff(region.energy)<=0)
        errors(end+1) = regionName+" energy grid is not nonempty/ascending.";
    end
    if any(~isfinite(region.observed)) || any(~isfinite(region.background))
        errors(end+1) = regionName+" contains nonfinite signal/background values.";
    end
    if region.software_normalization_scale <= 0 || ...
            ~isfinite(region.software_normalization_scale)
        errors(end+1) = regionName+" normalization scale is invalid.";
    end
    peaks = region.truth_peaks;
    ids = string({peaks.id});
    if numel(unique(ids)) ~= numel(ids)
        errors(end+1) = regionName+" truth peak IDs are not unique.";
    end
    if any(~isfinite([peaks.center_eV])) || any([peaks.FWHM_eV] <= 0) || ...
            any([peaks.physical_area] < 0)
        errors(end+1) = regionName+" truth peak parameters are invalid.";
    end
    containment = [peaks.true_window_containment_fraction];
    if any(containment < -1e-12 | containment > 1+1e-12 | ~isfinite(containment))
        errors(end+1) = regionName+" window-containment fractions are invalid.";
    end
    if region.background_truth_metadata.production_estimator_called
        errors(end+1) = regionName+" truth background called a production estimator.";
    end
end

for v = 1:numel(fixture.fit_variants)
    variant = fixture.fit_variants(v);
    for regionName = ["C1s","F1s"]
        peaks = variant.(regionName+"_peaks");
        starts = variant.(regionName+"_starts");
        ids = string({peaks.id});
        if numel(unique(ids)) ~= numel(ids)
            errors(end+1) = variant.name+" "+regionName+" fit IDs are not unique.";
        end
        if size(starts,1) ~= numel(peaks) || size(starts,2) ~= 3
            errors(end+1) = variant.name+" "+regionName+" start-array shape is invalid.";
        end
        for i = 1:numel(peaks)
            if isempty(starts),continue;end
            center = squeeze(starts(i,1,:)); width = squeeze(starts(i,2,:));
            area = squeeze(starts(i,3,:));
            if any(center < peaks(i).center_bounds_eV(1)-eps | ...
                    center > peaks(i).center_bounds_eV(2)+eps)
                errors(end+1) = variant.name+" "+regionName+ ...
                    " initial center outside allowed bounds for "+ids(i)+".";
            end
            if any(width < peaks(i).FWHM_bounds_eV(1)-eps | ...
                    width > peaks(i).FWHM_bounds_eV(2)+eps)
                errors(end+1) = variant.name+" "+regionName+ ...
                    " initial width outside allowed bounds for "+ids(i)+".";
            end
            if any(~isfinite(area) | area < 0)
                errors(end+1) = variant.name+" "+regionName+ ...
                    " initial area is negative or nonfinite for "+ids(i)+".";
            end
        end
    end
end

% Frozen seed formula check.
seedFields = fieldnames(fixture.seeds);
streamIDs = [1,2,11,12,21,22,31,32,41,42,51,52,61];
for i = 1:numel(seedFields)
    expected = xpsh.seedFor(fixture.family_id,fixture.cell_index, ...
        fixture.trial_id,streamIDs(i));
    if fixture.seeds.(seedFields{i}) ~= expected
        errors(end+1) = "Seed mismatch for stream "+seedFields{i}+".";
    end
end

% Model-specific positional rule must come from the loaded profile.
semi = fixture.composition_model_profile.models.c1s_f1s_semi;
if ~isequal(double(semi.allowed_center_range_eV(:).'),[686.7 686.9])
    errors(end+1) = "Loaded semi-covalent positional range is not the frozen configured range.";
end

switch fixture.family_id
    case 7
        if fixture.C1s.background_truth_metadata.method ~= ...
                fixture.settings.background_truth
            errors(end+1) = "Background truth method was not generated as declared.";
        end
    case 10
        halfRange = fixture.settings.charging_half_range_eV;
        if abs(fixture.charging_shift_eV) > halfRange+eps
            errors(end+1) = "Charging shift is outside its declared interval.";
        end
    case 11
        multiplier = fixture.settings.acquisition_error_multiplier;
        target = fixture.settings.acquisition_error_region;
        if ismember(target,["C1s","both"])
            ratio = fixture.scaling.supplied_C1s_scale / ...
                fixture.scaling.generation_C1s_scale;
            if abs(ratio-multiplier)>1e-12,errors(end+1)="C1s scale error mismatch.";end
        end
        if ismember(target,["F1s","both"])
            ratio = fixture.scaling.supplied_F1s_scale / ...
                fixture.scaling.generation_F1s_scale;
            if abs(ratio-multiplier)>1e-12,errors(end+1)="F1s scale error mismatch.";end
        end
    case 12
        if fixture.sensitivity_profile.status ~= "test_only_derived_profile"
            errors(end+1) = "Sensitivity sweep did not create an explicit derived profile.";
        end
    case 13
        labels = fixture.classification_expectation.ExpectedPostFitLabel;
        if fixture.settings.label_mutation == "remove_semi" && ...
                any(labels=="semi_covalent_F_C")
            errors(end+1) = "Remove-semi mutation retained a semi-covalent label.";
        elseif fixture.settings.label_mutation == "duplicate_semi" && ...
                nnz(labels=="semi_covalent_F_C") ~= 2
            errors(end+1) = "Duplicate-semi mutation did not produce two labels.";
        end
    case 14
        truthIDs = string({fixture.F1s.truth_peaks.id});
        if ~any(contains(truthIDs,"extra"))
            errors(end+1) = "Substrate/shoulder fixture contains no extra F1s truth peak.";
        end
    case 15
        if numel(fixture.fit_variants) ~= 2 || ...
                fixture.fit_variants(2).name ~= "widened_bounds"
            errors(end+1) = "Bound-sensitivity fixture is not paired with widened bounds.";
        end
end

% Mapping arrays must partition the truth and fit IDs.
for regionName = ["C1s","F1s"]
    mapping = fixture.peak_id_mapping.(regionName);
    if numel(unique([mapping.matched_ids;mapping.truth_only_ids])) ~= ...
            numel(mapping.truth_ids)
        errors(end+1) = regionName+" truth ID mapping is incomplete.";
    end
    if numel(unique([mapping.matched_ids;mapping.fit_only_ids])) ~= ...
            numel(mapping.fit_ids)
        errors(end+1) = regionName+" fit ID mapping is incomplete.";
    end
end

result = struct("valid",isempty(errors),"errors",errors, ...
    "warnings",warnings,"cell_key",fixture.cell_key, ...
    "trial_id",fixture.trial_id, ...
    "C1s_truth_peak_count",numel(fixture.C1s.truth_peaks), ...
    "F1s_truth_peak_count",numel(fixture.F1s.truth_peaks), ...
    "fit_variant_count",numel(fixture.fit_variants));
end
