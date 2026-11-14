function schedule = seedSchedule(plan)
%SEEDSCHEDULE Generate all initial-trial seeds without sampling or fitting.

cells = plan.cells;
nRows = sum([cells.trials]);
familyID = zeros(nRows,1);
cellIndex = zeros(nRows,1);
cellKey = strings(nRows,1);
trialID = zeros(nRows,1);
streamNames = string(fieldnames(plan.stream_ids));
seedValues = zeros(nRows,numel(streamNames));

row = 0;
for i = 1:numel(cells)
    for trial = 1:cells(i).trials
        row = row+1;
        familyID(row) = cells(i).family_id;
        cellIndex(row) = cells(i).cell_index;
        cellKey(row) = cells(i).cell_key;
        trialID(row) = trial;
        for j = 1:numel(streamNames)
            streamID = plan.stream_ids.(streamNames(j));
            seedValues(row,j) = xpsh.seedFor( ...
                familyID(row),cellIndex(row),trial,streamID);
        end
    end
end

schedule = table(familyID,cellIndex,cellKey,trialID, ...
    VariableNames=["FamilyID","CellIndex","CellKey","TrialID"]);
for j = 1:numel(streamNames)
    schedule.("Seed_"+streamNames(j)) = seedValues(:,j);
end
end
