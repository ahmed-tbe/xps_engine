function provenance = phase0HPostprocessingProvenance(projectFolder)
%PHASE0HPOSTPROCESSINGPROVENANCE Hash reporting code separately from execution.

arguments
    projectFolder (1,1) string = ""
end
if strlength(projectFolder)==0
    projectFolder=string(fileparts(mfilename("fullpath")));
end
relativeFiles = [ ...
    "aggregatePhase0HFamilySummary.m";
    "auditPhase0HFormalRun.m";
    "generatePhase0HSummaries.m";
    "phase0HPostprocessingProvenance.m"];
records = repmat(struct("path","","sha256",""),numel(relativeFiles),1);
fingerprintParts = strings(numel(relativeFiles),1);
for i=1:numel(relativeFiles)
    fullPath=fullfile(projectFolder,relativeFiles(i));
    records(i).path=relativeFiles(i);
    records(i).sha256=xpsh.sha256File(fullPath);
    fingerprintParts(i)=relativeFiles(i)+":"+string(records(i).sha256);
end
provenance=struct("postprocessing_id","phase0h_postprocessing", ...
    "postprocessing_version","1.0.1", ...
    "postprocessing_sha256",xpsh.sha256Text(strjoin(fingerprintParts,newline)), ...
    "files",records);
end
