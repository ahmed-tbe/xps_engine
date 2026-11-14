function hexadecimal = sha256File(filename)
%SHA256FILE Return lowercase SHA-256 for a file.

arguments
    filename (1,1) string
end
if ~isfile(filename)
    error("xpsh:sha256File:MissingFile","File not found: %s",filename);
end
fid = fopen(filename,"rb");
if fid < 0,error("xpsh:sha256File:OpenFailed","Cannot open: %s",filename);end
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes = fread(fid,Inf,"*uint8");
digest = java.security.MessageDigest.getInstance("SHA-256");
digest.update(typecast(bytes,"int8"));
raw = typecast(digest.digest(),"uint8");
hexadecimal = lower(string(reshape(dec2hex(raw,2).',1,[])));
end
