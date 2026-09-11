function peaks = classifyF1sPeaks(peaks,boundaries)
%CLASSIFYF1SPEAKS Assign F1s chemistry from fitted position, not index.
%
% The optimizer index is retained on each peak by xps.fitSpectrum. Sort by
% fitted center before applying chemistry so assignment cannot depend on
% parameter-array order.
%
% boundaries:
%   ionic_to_semi_covalent
%   semi_covalent_to_covalent

% Sort only for chemical presentation; stable IDs and optimizer_index stay
% attached to their original fitted components.
[~,idx] = sort([peaks.center_eV]);
peaks = peaks(idx);

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
end
