function assertNoNewFigures(existingFigures)
%ASSERTNONEWFIGURES Close and reject figures created during trial execution.

current = findall(groot,"Type","figure");
isNew = ~ismember(current,existingFigures);
newFigures = current(isNew);
if ~isempty(newFigures)
    close(newFigures);
    error("xpsh:assertNoNewFigures:FigureCreated", ...
        "Phase 0H optimizer execution created %d forbidden figure(s).", ...
        numel(newFigures));
end
end
