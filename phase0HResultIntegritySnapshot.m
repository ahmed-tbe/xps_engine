function snapshot = phase0HResultIntegritySnapshot(folder)
%PHASE0HRESULTINTEGRITYSNAPSHOT Read-only metadata/content identity snapshot.
arguments
    folder (1,1) string
end
if ~isfolder(folder)
    error("phase0HResultIntegritySnapshot:MissingFolder","Missing %s.",folder);
end
items=dir(fullfile(folder,"**","*"));items=items(~[items.isdir]);
relative=strings(numel(items),1);bytes=zeros(numel(items),1);modified=zeros(numel(items),1);
for i=1:numel(items)
    absolute=string(fullfile(items(i).folder,items(i).name));
    relative(i)=replace(extractAfter(absolute,strlength(folder)+1),"\","/");
    bytes(i)=items(i).bytes;modified(i)=items(i).datenum;
end
[relative,order]=sort(relative);bytes=bytes(order);modified=modified(order);
lines=relative+":"+compose("%.0f",bytes)+":"+compose("%.17g",modified);
snapshot=struct("folder",folder,"file_count",numel(items), ...
    "total_bytes",sum(bytes),"metadata_sha256",xpsh.sha256Text(strjoin(lines,newline)));
critical=["manifest.json","unified_provenance.json","phase0h_unified_summary.mat", ...
    "cell_inventory.csv","seed_schedule.csv"];
for name=critical
    file=fullfile(folder,name);
    if isfile(file)
        field=matlab.lang.makeValidName(replace(name,".","_"));
        snapshot.(field)=xpsh.sha256File(file);
    end
end
end
