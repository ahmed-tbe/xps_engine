function writeJsonAtomic(filename,value)
%WRITEJSONATOMIC Write JSON through a same-directory temporary file.

filename = string(filename);
folder = string(fileparts(filename));
if strlength(folder)>0 && ~isfolder(folder),mkdir(folder);end
temporary = string(tempname(folder))+".json";
cleanup = onCleanup(@()deleteIfPresent(temporary)); %#ok<NASGU>
fid = fopen(temporary,"wt");
if fid < 0
    error("xpsh:writeJsonAtomic:OpenFailed","Cannot open %s.",temporary);
end
fileCleanup = onCleanup(@()fclose(fid));
fprintf(fid,"%s",jsonencode(value,PrettyPrint=true));
clear fileCleanup
[ok,message] = movefile(temporary,filename,"f");
if ~ok
    error("xpsh:writeJsonAtomic:RenameFailed","%s",message);
end
end

function deleteIfPresent(filename)
if isfile(filename),delete(filename);end
end
