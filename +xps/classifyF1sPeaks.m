function peaks = classifyF1sPeaks(peaks,boundaries)
%CLASSIFYF1SPEAKS Assign F1s chemistry from fitted position, not index.
%
% boundaries:
%   ionic_to_semi_covalent
%   semi_covalent_to_covalent

for i = 1:numel(peaks)
    c = peaks(i).center_eV;

    if c < boundaries.ionic_to_semi_covalent
        peaks(i).chemical_assignment = "ionic_or_substrate_bound_F";
        peaks(i).include_in_carbon_bound_F = false;
        peaks(i).include_in_total_F = true;
    elseif c < boundaries.semi_covalent_to_covalent
        peaks(i).chemical_assignment = "semi_covalent_F_C";
        peaks(i).include_in_carbon_bound_F = true;
        peaks(i).include_in_total_F = true;
    else
        peaks(i).chemical_assignment = "covalent_F_C";
        peaks(i).include_in_carbon_bound_F = true;
        peaks(i).include_in_total_F = true;
    end

    peaks(i).classification_warning = ...
        (abs(c-boundaries.ionic_to_semi_covalent) < 0.10) || ...
        (abs(c-boundaries.semi_covalent_to_covalent) < 0.10);
end

% Sort only for chemical presentation; the original IDs remain attached.
[~,idx] = sort([peaks.center_eV]);
peaks = peaks(idx);
end
