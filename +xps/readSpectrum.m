function S = readSpectrum(filename)
%READSPECTRUM Read two-column XPS text/CSV data without changing values.
%
% Output:
%   S.energy     binding energy
%   S.intensity  raw intensity
%   S.originalOrder  original row ordering

M = readmatrix(filename);

if size(M,2) < 2
    error("File %s does not contain at least two numeric columns.", filename);
end

M = M(:,1:2);
valid = all(isfinite(M),2);
M = M(valid,:);

if isempty(M)
    error("No valid numeric rows found in %s.", filename);
end

S.energy = M(:,1);
S.intensity = M(:,2);
S.originalOrder = (1:size(M,1)).';
S.energyDirection = sign(S.energy(end)-S.energy(1));
S.sourceFile = string(filename);
% A plain two-column spectrum contains no independently interpretable
% dwell-time, pass-energy, scan-count, transmission, or other acquisition
% correction metadata. Callers must obtain those factors externally before
% treating a C1s/F1s ratio as physical quantification.
S.acquisitionMetadataAvailable = false;
S.acquisitionMetadataStatus = ...
    "two-column file contains energy and intensity only";

% For fitting, use ascending energy internally. Do not overwrite the raw
% values; preserve the original arrays above.
[~,idx] = sort(S.energy,"ascend");
S.energyFit = S.energy(idx);
S.intensityFit = S.intensity(idx);
S.sortIndex = idx;
end
