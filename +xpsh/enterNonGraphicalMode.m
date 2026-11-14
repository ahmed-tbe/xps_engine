function guard = enterNonGraphicalMode
%ENTERNONGRAPHICALMODE Defensively suppress figures during optimizer work.

testFigures = findall(groot,"Type","figure","Tag","Phase0HTestFigure");
if ~isempty(testFigures),close(testFigures);end
guard.existing_figures = findall(groot,"Type","figure");
guard.previous_default_visibility = string(get(groot,"DefaultFigureVisible"));
set(groot,"DefaultFigureVisible","off");
guard.cleanup = onCleanup(@()set(groot,"DefaultFigureVisible", ...
    char(guard.previous_default_visibility)));
end
