% =========================================================================
% Additional_Figures.m
% Generates:
%   Fig2_MembershipFunctions.png / .pdf  – IT1 vs IT2 membership functions
%   Fig11_Input_Boxplots.png      / .pdf – Distribution of the 5 input KPIs
%
% Standalone script. Does NOT modify IT1_System.m or IT2_System.m.
% Outputs saved in Additional_Figures/ at 600 DPI (PNG) and vector (PDF).
% =========================================================================
clear; clc; close all;

% ---- Output folder ----
outputDir = 'Additional_Figures';
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
fprintf('Output folder: %s\n\n', fullfile(pwd, outputDir));

% ---- Common plotting style (match your other figures) ----
set(0, 'DefaultAxesFontName', 'Helvetica');
set(0, 'DefaultAxesFontSize', 11);
set(0, 'DefaultTextFontName', 'Helvetica');
set(0, 'DefaultTextFontSize', 11);

%% =========================================================
%  FIGURE 2 — MEMBERSHIP FUNCTIONS (IT1 vs IT2)
% =========================================================
x = 0:0.5:100;

% NOTE: All entries are 4-element trapezoids [a b c d].
% Triangular MFs are stored as degenerate trapezoids (b == c):
%   [25 45 65] -> [25 45 45 65]
%   [45 65 85] -> [45 65 65 85]
mfBase = {[0 0 25 45], [25 45 45 65], [45 65 65 85], [65 85 100 100]};

names = {'Low','Moderate','High','VeryHigh'};
colors = [0.85 0.33 0.10;   % Low     - orange
          0.93 0.69 0.13;   % Moderate- yellow
          0.20 0.55 0.90;   % High    - blue
          0.10 0.65 0.35];  % VeryHigh- green
delta = 6;

fig2 = figure('Color','w', 'Position',[100 100 900 500]);
hold on;
hLeg = gobjects(12,1);
legLabels = cell(12,1);
idx = 0;
for k = 1:4
    a = mfBase{k}(1); b = mfBase{k}(2); c = mfBase{k}(3); d = mfBase{k}(4);

    % IT1 crisp
    idx = idx + 1;
    hLeg(idx) = plot(x, trapmf(x, mfBase{k}), '--', 'Color', colors(k,:), ...
        'LineWidth', 1.4);
    legLabels{idx} = sprintf('%s (IT1)', names{k});

    % IT2 UMF
    umf = [max(a-delta,0), max(b-delta,0), min(c+delta,100), min(d+delta,100)];
    idx = idx + 1;
    hLeg(idx) = plot(x, trapmf(x, umf), '-', 'Color', colors(k,:), ...
        'LineWidth', 1.8);
    legLabels{idx} = sprintf('%s (IT2 UMF)', names{k});

    % IT2 LMF
    lb = b+delta; lc = c-delta;
    if lb > lc, mid = (b+c)/2; lb = mid; lc = mid; end
    la = a+delta; if la > lb, la = lb; end
    ld = d-delta; if ld < lc, ld = lc; end
    lmf = [la lb lc ld];
    idx = idx + 1;
    hLeg(idx) = plot(x, trapmf(x, lmf), ':', 'Color', colors(k,:), ...
        'LineWidth', 1.4);
    legLabels{idx} = sprintf('%s (IT2 LMF)', names{k});
end
xlabel('Input Value (0-100)');
ylabel('Membership Degree');
title('Membership Functions: IT1 (dashed) vs IT2 UMF (solid) and LMF (dotted), \delta = 6');
legend(hLeg, legLabels, 'Location','eastoutside','FontSize',8,'NumColumns',1);
grid on;
box on;
xlim([0 100]); ylim([0 1.05]);

% Save Fig 2
exportgraphics(fig2, fullfile(outputDir, 'Fig2_MembershipFunctions.png'), ...
    'Resolution', 600);
exportgraphics(fig2, fullfile(outputDir, 'Fig2_MembershipFunctions.pdf'), ...
    'ContentType', 'vector');
fprintf('Saved: Fig2_MembershipFunctions.png (600 DPI) and .pdf (vector)\n');

%% =========================================================
%  FIGURE 11 — INPUT KPI BOXPLOTS
% =========================================================
rng(42);
N = 1000;

AM = min(100, max(0, normrnd(75, 15, [N, 1])));
AC = min(100, max(0, normrnd(65, 20, [N, 1])));
PassRate   = normrnd(85, 10, [N, 1]);
AvgMarks   = normrnd(80, 10, [N, 1]);
Improvement = normrnd(70, 15, [N, 1]);
SEP = min(100, max(0, 0.40*PassRate + 0.40*AvgMarks + 0.20*Improvement));

Q1 = randi([0 1], N, 1) * 30;   Q2 = randi([0 1], N, 1) * 25;
ScopusNonQ = randi([0 1], N, 1) * 10;   FundedPI = randi([0 1], N, 1) * 30;
PatGranted = randi([0 1], N, 1) * 30;   PatFiled = randi([0 1], N, 1) * 10;
PhDs = randi([0 1], N, 1) * 20;         Citations = randi([0 1], N, 1) * 10;
RC = min(100, Q1+Q2+ScopusNonQ+FundedPI+PatGranted+PatFiled+PhDs+Citations);

FDP_long  = randi([0 1], N, 1) * 20;   FDP_short = randi([0 1], N, 1) * 10;
MOOCs     = randi([0 1], N, 1) * 10;   Pedagogy  = randi([0 1], N, 1) * 10;
Industry  = randi([0 1], N, 1) * 15;   NewCourse = randi([0 1], N, 1) * 20;
NewTool   = randi([0 1], N, 1) * 10;
CL = min(100, FDP_long+FDP_short+MOOCs+Pedagogy+Industry+NewCourse+NewTool);

Data = [AM, SEP, CL, AC, RC];

fig11 = figure('Color','w', 'Position',[100 100 800 500]);
boxplot(Data, 'Labels', {'AM','SEP','CL','AC','RC'}, ...
    'Symbol', '.', 'Colors', [0.20 0.30 0.70]);
ylabel('Score (0-100)');
xlabel('Input KPI');
title('Distribution of Input KPIs across 1000 Synthetic Faculty Profiles');
grid on;
box on;
ylim([0 100]);

% Save Fig 11
exportgraphics(fig11, fullfile(outputDir, 'Fig11_Input_Boxplots.png'), ...
    'Resolution', 600);
exportgraphics(fig11, fullfile(outputDir, 'Fig11_Input_Boxplots.pdf'), ...
    'ContentType', 'vector');
fprintf('Saved: Fig11_Input_Boxplots.png (600 DPI) and .pdf (vector)\n');

%% =========================================================
fprintf('\n=== Additional figures complete ===\n');
fprintf('All files saved in: %s\n', fullfile(pwd, outputDir));
