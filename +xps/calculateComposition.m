function comp = calculateComposition(c1sPeaks,f1sPeaks,SC,SF,alpha)
%CALCULATECOMPOSITION Legacy and candidate composition calculations.
%
% IMPORTANT:
%   F/C is a ratio, not an atomic percentage.
%   F at.% = (F/C)/(1+F/C)*100
%
% The first milestone locks alpha=0 and the legacy C1s expression.
% The F1s/C1s outputs are only physically quantitative when their input
% areas share a restored acquisition scale; this function does not infer
% that scale from independently normalized spectra.

if nargin < 3 || isempty(SC), SC = 1.0; end
if nargin < 4 || isempty(SF), SF = 4.4118; end
if nargin < 5 || isempty(alpha), alpha = 0; end

ids = string({c1sPeaks.id});
A = @(id) c1sPeaks(ids==id).area;

A_sp2 = A("sp2_C_C");
A_CF  = A("C_F");
A_amb = A("C_CF23_C_O");
A_CF2 = A("CF2");
A_CF3 = A("CF3");
A_Ctotal = sum([c1sPeaks.area]);
A_Cfilm = A_Ctotal;  % explicit milestone-1 assumption

% Locked legacy C1s model
legacyFC = ((A_Ctotal-A_sp2)/A_Ctotal)*(1/3);
comp.legacy = ratioFields(legacyFC);

% Weighted C1s candidate
weightedFC = (A_CF + alpha*A_amb + 2*A_CF2 + 3*A_CF3)/A_Cfilm;
comp.weighted = ratioFields(weightedFC);
comp.weighted.alpha = alpha;

% F1s
AfCarbon = sum([f1sPeaks([f1sPeaks.include_in_carbon_bound_F]).area]);
AfTotal  = sum([f1sPeaks([f1sPeaks.include_in_total_F]).area]);

carbonBoundFC = (AfCarbon/SF)/(A_Cfilm/SC);
totalFFC = (AfTotal/SF)/(A_Cfilm/SC);

comp.carbonBound = ratioFields(carbonBoundFC);
comp.totalF = ratioFields(totalFFC);

comp.areas = struct( ...
    "A_Ctotal",A_Ctotal, ...
    "A_Cfilm",A_Cfilm, ...
    "A_sp2",A_sp2, ...
    "A_CF",A_CF, ...
    "A_ambiguous",A_amb, ...
    "A_CF2",A_CF2, ...
    "A_CF3",A_CF3, ...
    "A_F_carbon_bound",AfCarbon, ...
    "A_F_total",AfTotal);

comp.sensitivityFactors = struct("SC",SC,"SF",SF);
comp.crossRegionAreaScaleStatus = ...
    "caller must restore any independent preprocessing scales before using F1s/C1s ratios physically";
end

function out = ratioFields(FC)
out.F_over_C = FC;
if FC > 0
    out.F_atpct = FC/(1+FC)*100;
    out.C_over_F = 1/FC;
    out.CxF = sprintf("C%.3gF",1/FC);
else
    out.F_atpct = NaN;
    out.C_over_F = NaN;
    out.CxF = "invalid";
end
end
