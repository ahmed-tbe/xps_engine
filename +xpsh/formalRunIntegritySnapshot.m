function snapshot = formalRunIntegritySnapshot(formalFolder)
%FORMALRUNINTEGRITYSNAPSHOT Read-only identity snapshot of the formal output.

arguments
    formalFolder (1,1) string
end
required=["manifest.json","cell_inventory.csv","seed_schedule.csv"];
for file=required
    if ~isfile(fullfile(formalFolder,file))
        error("xpsh:formalRunIntegritySnapshot:MissingFile", ...
            "Missing formal-run file %s.",file);
    end
end
items=dir(fullfile(formalFolder,"**","*"));
items=items(~[items.isdir]);
relative=strings(numel(items),1); bytes=zeros(numel(items),1);
modified=zeros(numel(items),1);
for i=1:numel(items)
    absolute=string(fullfile(items(i).folder,items(i).name));
    prefix=string(formalFolder)+string(filesep);
    relative(i)=replace(extractAfter(absolute,strlength(prefix)),"\","/");
    bytes(i)=items(i).bytes;
    modified(i)=items(i).datenum;
end
[relative,order]=sort(relative);bytes=bytes(order);modified=modified(order);
metadataLines=relative+":"+compose("%.0f",bytes)+":"+compose("%.17g",modified);
snapshot=struct("folder",formalFolder,"file_count",numel(items), ...
    "total_bytes",sum(bytes),"latest_write_datenum",max(modified), ...
    "metadata_sha256",xpsh.sha256Text(metadataLines), ...
    "manifest_sha256",xpsh.sha256File(fullfile(formalFolder,"manifest.json")), ...
    "inventory_sha256",xpsh.sha256File(fullfile(formalFolder,"cell_inventory.csv")), ...
    "seed_schedule_sha256",xpsh.sha256File(fullfile(formalFolder,"seed_schedule.csv")));
end
