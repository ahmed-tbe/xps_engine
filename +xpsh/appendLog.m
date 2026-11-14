function appendLog(logFile,message)
%APPENDLOG Append one timestamped line to the execution log and console.

stamp = string(datetime("now","TimeZone","America/Chicago", ...
    "Format","yyyy-MM-dd'T'HH:mm:ssXXX"));
line = "["+stamp+"] "+string(message);
fprintf("%s\n",line);
fid = fopen(logFile,"at");
if fid < 0,error("xpsh:appendLog:OpenFailed","Cannot append %s.",logFile);end
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,"%s\n",line);
end
