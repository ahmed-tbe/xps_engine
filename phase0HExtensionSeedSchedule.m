function schedule = phase0HExtensionSeedSchedule(plan)
%PHASE0HEXTENSIONSEEDSCHEDULE Exact 101:400 deterministic seed schedule.

names=["C_noise","F_noise","C_center","F_center","C_area", ...
    "F_area","C_width","F_width","C_order","F_order", ...
    "C_acquisition","F_acquisition","charging_shift"];
n=plan.new_trial_count;
FamilyID=zeros(n,1);CellIndex=zeros(n,1);CellKey=strings(n,1);
TrialID=zeros(n,1);SeedNamespace=repmat(string(plan.seed_namespace),n,1);
values=zeros(n,numel(names));cursor=0;
for i=1:numel(plan.cells)
    c=plan.cells(i);
    for trialID=c.extension_first_trial:c.extension_last_trial
        cursor=cursor+1;seeds=xpsh.trialSeeds(c,trialID);
        FamilyID(cursor)=c.family_id;CellIndex(cursor)=c.cell_index;
        CellKey(cursor)=string(c.cell_key);TrialID(cursor)=trialID;
        for j=1:numel(names),values(cursor,j)=seeds.(names(j));end
    end
end
schedule=table(FamilyID,CellIndex,CellKey,TrialID,SeedNamespace);
for j=1:numel(names),schedule.("Seed_"+names(j))=values(:,j);end
end
