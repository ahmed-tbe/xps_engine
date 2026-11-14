function seed = seedFor(familyID,cellIndex,trialID,streamID)
%SEEDFOR Frozen Phase 0H deterministic seed formula.

arguments
    familyID (1,1) double {mustBeInteger,mustBePositive}
    cellIndex (1,1) double {mustBeInteger,mustBePositive}
    trialID (1,1) double {mustBeInteger,mustBePositive}
    streamID (1,1) double {mustBeInteger,mustBeNonnegative}
end

seed = 100000000*familyID + 100000*cellIndex + 100*trialID + streamID;
if seed > double(intmax("uint32"))
    error("xpsh:seedFor:OutOfRange", ...
        "Seed %.0f exceeds MATLAB twister's uint32 range.",seed);
end
end
