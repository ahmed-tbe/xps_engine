function plotFitComponents(P,R,titleText)
%PLOTFITCOMPONENTS Plot raw, background, components, cumulative fit, residual.

figure("Name",titleText,"Color","w");
tiledlayout(2,1);

nexttile;
plot(P.energy,P.normalized,"k.","DisplayName","normalized raw"); hold on;
if isfield(P,"background_method")
    backgroundLabel = P.background_method + " background";
else
    backgroundLabel = "background";
end
plot(P.energy,P.background,"DisplayName",backgroundLabel);
plot(P.energy,P.y_fit,"DisplayName","background-subtracted");

for i=1:numel(R.peaks)
    plot(R.energy,R.peaks(i).curve,"DisplayName",R.peaks(i).id);
end
plot(R.energy,R.fitted,"k-","LineWidth",1.5,"DisplayName","cumulative fit");

set(gca,"XDir","reverse");
xlabel("Binding energy (eV)");
ylabel("Intensity (normalized)");
title(titleText);
legend("Location","bestoutside");
grid on;

nexttile;
plot(R.energy,R.residual,"k-");
set(gca,"XDir","reverse");
xlabel("Binding energy (eV)");
ylabel("Residual");
grid on;
title(sprintf("Residual | RMSE = %.4g | R^2 = %.5f", ...
    R.metrics.RMSE,R.metrics.R2));
end
