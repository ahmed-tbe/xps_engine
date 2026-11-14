function peaks = truthAsFittedPeaks(truth)
%TRUTHASFITTEDPEAKS Adapt generated truth schema to composition peak schema.
%
% Generated Phase 0H truth peaks store their human-readable assignment in
% `label`. The composition API expects fitted-like peaks with `assignment`.

arguments
    truth (1,:) struct
end
required=["id","label","center_eV","FWHM_eV","physical_area"];
for field=required
    if ~isfield(truth,field)
        error("xpsh:truthAsFittedPeaks:InvalidTruthSchema", ...
            "Generated truth peaks are missing required field '%s'.",field);
    end
end
template=struct("id","","assignment","","center_eV",NaN, ...
    "FWHM_eV",NaN,"area",NaN);
peaks=repmat(template,numel(truth),1);
for i=1:numel(truth)
    peaks(i).id=string(truth(i).id);
    peaks(i).assignment=string(truth(i).label);
    peaks(i).center_eV=truth(i).center_eV;
    peaks(i).FWHM_eV=truth(i).FWHM_eV;
    peaks(i).area=truth(i).physical_area;
end
end
