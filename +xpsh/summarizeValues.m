function summary = summarizeValues(values)
%SUMMARIZEVALUES Frozen scalar summary using nearest-rank percentiles.

values = values(:);
finiteValues = values(isfinite(values));
summary.total_count = numel(values);
summary.finite_count = numel(finiteValues);
summary.nonfinite_count = summary.total_count-summary.finite_count;
if isempty(finiteValues)
    summary.mean = NaN; summary.median = NaN; summary.std = NaN;
    summary.p2_5 = NaN; summary.p95 = NaN; summary.p97_5 = NaN;
    summary.worst = NaN;
    return
end
summary.mean = mean(finiteValues);
summary.median = median(finiteValues);
summary.std = std(finiteValues,0);
sorted = sort(finiteValues);
summary.p2_5 = nearestRank(sorted,0.025);
summary.p95 = nearestRank(sorted,0.95);
summary.p97_5 = nearestRank(sorted,0.975);
summary.worst = max(abs(finiteValues));
end

function value = nearestRank(sorted,p)
index = max(1,ceil(p*numel(sorted)));
value = sorted(index);
end
