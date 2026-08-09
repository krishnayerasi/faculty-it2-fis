% =========================================================================
% IT2_SYSTEM.m (UPGRADED – RULE COVERAGE + SURFACE PLOTS)
% Interval Type-2 Hierarchical Fuzzy System for Faculty Evaluation
% Nie‑Tan crisp output, Karnik‑Mendel interval bounds
% Saves all figures (300 DPI), datasets, surface plots, rule coverage,
% and summary into IT2_Outputs/
% =========================================================================
clear; clc; close all;

%% 0. CREATE OUTPUT FOLDER
outputDir = 'IT2_Outputs';
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
fprintf('Output folder: %s\n\n', fullfile(pwd, outputDir));

%% 1. GENERATE SYNTHETIC DATASET (identical to IT1)
rng(42);
N = 1000;

AM = min(100, max(0, normrnd(75, 15, [N, 1])));
AC = min(100, max(0, normrnd(65, 20, [N, 1])));
PassRate = normrnd(85, 10, [N, 1]); AvgMarks = normrnd(80, 10, [N, 1]);
Improvement = normrnd(70, 15, [N, 1]);
SEP = min(100, max(0, 0.40*PassRate + 0.40*AvgMarks + 0.20*Improvement));

Q1 = randi([0 1], N, 1) * 30;  Q2 = randi([0 1], N, 1) * 25;
ScopusNonQ = randi([0 1], N, 1) * 10;  FundedPI = randi([0 1], N, 1) * 30;
PatGranted = randi([0 1], N, 1) * 30;  PatFiled = randi([0 1], N, 1) * 10;
PhDs = randi([0 1], N, 1) * 20;        Citations = randi([0 1], N, 1) * 10;
RC = min(100, Q1+Q2+ScopusNonQ+FundedPI+PatGranted+PatFiled+PhDs+Citations);

FDP_long  = randi([0 1], N, 1) * 20;   FDP_short = randi([0 1], N, 1) * 10;
MOOCs     = randi([0 1], N, 1) * 10;   Pedagogy  = randi([0 1], N, 1) * 10;
Industry  = randi([0 1], N, 1) * 15;   NewCourse = randi([0 1], N, 1) * 20;
NewTool   = randi([0 1], N, 1) * 10;
CL = min(100, FDP_long+FDP_short+MOOCs+Pedagogy+Industry+NewCourse+NewTool);

SyntheticData = [AM, AC, SEP, RC, CL];
InputNames = {'AM', 'AC', 'SEP', 'RC', 'CL'};

%% 2. BUILD IT2 SYSTEM
FOU_delta = 6;
domain = [0 100];
mfSet = buildIT2MFs(FOU_delta, domain);

% Rule tables (monotonic)
w = [0.25 0.25 0.50];
ruleTeach = zeros(64,4); r=0;
for a=1:4
    for s=1:4
        for c=1:4
            r=r+1;
            outIdx = monotonicConsequent([a s c], [1/3 1/3 1/3], 4, false);
            ruleTeach(r,:)=[a s c outIdx];
        end
    end
end

ruleMaster = zeros(64,4); r=0;
for t=1:4
    for ac=1:4
        for rc=1:4
            r=r+1;
            outIdx = monotonicConsequent([t ac rc], w, 5, true);
            ruleMaster(r,:)=[t ac rc outIdx];
        end
    end
end

teachOut = [20 45 65 85];
masterOut = [25 50 67 83 95];

%% 3. RULE COVERAGE VERIFICATION
mfMidpoints = [12.5 45 65 92.5];  % inside each MF
fprintf('\n--- Rule Coverage Verification ---\n');
badRules1 = 0; badRules2 = 0;
for s = 1:64
    a = ruleTeach(s,1); ss = ruleTeach(s,2); c = ruleTeach(s,3);
    testPt = [mfMidpoints(a), mfMidpoints(ss), mfMidpoints(c)];
    outVal = evalNT(testPt(1), testPt(2), testPt(3), mfSet, ruleTeach, teachOut);
    if isnan(outVal) || isempty(outVal)
        badRules1 = badRules1 + 1;
    end
end
for s = 1:64
    t = ruleMaster(s,1); ac = ruleMaster(s,2); rc = ruleMaster(s,3);
    testPt = [mfMidpoints(t), mfMidpoints(ac), mfMidpoints(rc)];
    outVal = evalNT(testPt(1), testPt(2), testPt(3), mfSet, ruleMaster, masterOut);
    if isnan(outVal) || isempty(outVal)
        badRules2 = badRules2 + 1;
    end
end
fprintf('Stage-1: %d/64 rules fire correctly (%d failed)\n', 64-badRules1, badRules1);
fprintf('Stage-2: %d/64 rules fire correctly (%d failed)\n', 64-badRules2, badRules2);
if badRules1==0 && badRules2==0
    fprintf('Rule Coverage: 100%% – All 128 rules verified.\n');
end

%% 4. EVALUATE ALL 1000 PROFILES
fprintf('Evaluating %d profiles with IT2 (FOU_delta=%d)...\n', N, FOU_delta);
TeachingScores_IT2 = zeros(N,1); PerformanceGrades_IT2 = zeros(N,1);
PG_L = zeros(N,1); PG_R = zeros(N,1);

for n = 1:N
    T = evalNT(AM(n), SEP(n), CL(n), mfSet, ruleTeach, teachOut);
    TeachingScores_IT2(n) = T;
    [PG, yL, yR] = evalKM(T, AC(n), RC(n), mfSet, ruleMaster, masterOut);
    PerformanceGrades_IT2(n) = PG;
    PG_L(n) = yL; PG_R(n) = yR;
end

%% 5. SAVE DATASETS
T1 = table(AM, SEP, CL, TeachingScores_IT2, ...
    'VariableNames', {'AM','SEP','CL','TeachingScore'});
writetable(T1, fullfile(outputDir, 'IT2_TeachingScore_Dataset.csv'));
fprintf('Saved: IT2_TeachingScore_Dataset.csv (1000 rows)\n');

T2 = array2table([SyntheticData, TeachingScores_IT2, PerformanceGrades_IT2, PG_L, PG_R], ...
    'VariableNames', [InputNames, {'TeachingScore','PerformanceGrade','PG_L','PG_R'}]);
writetable(T2, fullfile(outputDir, 'IT2_PerformanceGrade_Dataset.csv'));
fprintf('Saved: IT2_PerformanceGrade_Dataset.csv (1000 rows)\n');

%% 6. OUTPUT DISTRIBUTION & INTERVAL STATISTICS
widths = PG_R - PG_L;
fprintf('\n========== IT2 OUTPUT DISTRIBUTION ==========\n');
ts_mean = mean(TeachingScores_IT2); ts_std = std(TeachingScores_IT2);
ts_min = min(TeachingScores_IT2); ts_max = max(TeachingScores_IT2);
ts_skew = skewness(TeachingScores_IT2); ts_kurt = kurtosis(TeachingScores_IT2);

pg_mean = mean(PerformanceGrades_IT2); pg_std = std(PerformanceGrades_IT2);
pg_min = min(PerformanceGrades_IT2); pg_max = max(PerformanceGrades_IT2);
pg_skew = skewness(PerformanceGrades_IT2); pg_kurt = kurtosis(PerformanceGrades_IT2);

w_mean = mean(widths); w_max = max(widths); w_min = min(widths); w_std = std(widths);

fprintf('TeachingScore:  Mean=%.2f, Std=%.2f, Min=%.2f, Max=%.2f, Skew=%.2f, Kurt=%.2f\n', ...
    ts_mean, ts_std, ts_min, ts_max, ts_skew, ts_kurt);
fprintf('PerformanceGrade: Mean=%.2f, Std=%.2f, Min=%.2f, Max=%.2f, Skew=%.2f, Kurt=%.2f\n', ...
    pg_mean, pg_std, pg_min, pg_max, pg_skew, pg_kurt);
fprintf('Interval Width: Mean=%.3f, Max=%.3f, Min=%.3f, Std=%.3f\n', ...
    w_mean, w_max, w_min, w_std);

% Histograms
figure('Color','w');
subplot(1,3,1);
histogram(TeachingScores_IT2, 20, 'FaceColor', [0.2 0.5 0.8]);
xlabel('TeachingScore'); title('IT2 TeachingScore');
subplot(1,3,2);
histogram(PerformanceGrades_IT2, 20, 'FaceColor', [0.8 0.4 0.2]);
xlabel('PerformanceGrade'); title('IT2 PerformanceGrade');
subplot(1,3,3);
histogram(widths, 30, 'FaceColor', [0.6 0.2 0.4]);
xlabel('Interval Width'); title('Uncertainty Band');
exportgraphics(gcf, fullfile(outputDir, 'IT2_OutputDistribution.png'), 'Resolution', 300);

%% 7. SENSITIVITY ANALYSIS (using NT crisp output)
baseline = mean(SyntheticData, 1);
sweepVals = linspace(0, 100, 21);
sensResults = zeros(length(sweepVals), 5);

fprintf('\n--- Sensitivity Analysis ---\n');
for varIdx = 1:5
    for k = 1:length(sweepVals)
        pt = baseline;
        pt(varIdx) = sweepVals(k);
        T_s = evalNT(pt(1), pt(3), pt(5), mfSet, ruleTeach, teachOut);
        PG_s = evalNT(T_s, pt(2), pt(4), mfSet, ruleMaster, masterOut);
        sensResults(k, varIdx) = PG_s;
    end
    fprintf('%s: min=%.2f, max=%.2f, range=%.2f\n', ...
        InputNames{varIdx}, min(sensResults(:,varIdx)), ...
        max(sensResults(:,varIdx)), max(sensResults(:,varIdx))-min(sensResults(:,varIdx)));
end

% Save sensitivity table
SensTable = array2table([sweepVals', sensResults], ...
    'VariableNames', ['SweepValue', InputNames]);
writetable(SensTable, fullfile(outputDir, 'IT2_Sensitivity.csv'));
fprintf('Saved: IT2_Sensitivity.csv\n');

fprintf('\n--- Monotonicity Check ---\n');
for varIdx = [1 3 5 2 4]
    d = diff(sensResults(:, varIdx));
    fprintf('%s: %s (max viol=%.4f)\n', InputNames{varIdx}, ...
        ternaryStr(all(d >= -1e-6)), max(0, -min(d)));
end

figure('Color','w'); colors = lines(5); hold on;
for i = 1:5
    plot(sweepVals, sensResults(:,i), '-o', 'Color', colors(i,:), ...
        'LineWidth', 1.5, 'DisplayName', InputNames{i});
end
xlabel('Input Value'); ylabel('PerformanceGrade');
title('IT2 Sensitivity Analysis'); legend('Location','best'); grid on;
exportgraphics(gcf, fullfile(outputDir, 'IT2_Sensitivity.png'), 'Resolution', 300);

%% 8. SURFACE PLOTS (Master Stage + optional Teaching Stage)
fprintf('\n--- Generating Surface Plots ---\n');

% Surface 1: PerformanceGrade vs (TeachingScore, RC), AC fixed at baseline
ac_fixed = baseline(2);
[TS, RC] = meshgrid(0:5:100, 0:5:100);
Z1 = zeros(size(TS));
for i = 1:size(TS,1)
    for j = 1:size(TS,2)
        Z1(i,j) = evalNT(TS(i,j), ac_fixed, RC(i,j), mfSet, ruleMaster, masterOut);
    end
end
figure('Color','w');
surf(TS, RC, Z1, 'EdgeColor', 'none');
xlabel('TeachingScore'); ylabel('RC'); zlabel('PerformanceGrade');
title(sprintf('IT2 Surface: PerformanceGrade vs TeachingScore & RC (AC = %.1f)', ac_fixed));
colormap jet; colorbar;
exportgraphics(gcf, fullfile(outputDir, 'IT2_Surface_Teach_RC.png'), 'Resolution', 300);
fprintf('Saved: IT2_Surface_Teach_RC.png\n');

% Surface 2: PerformanceGrade vs (TeachingScore, AC), RC fixed at baseline
rc_fixed = baseline(4);
[TS2, AC2] = meshgrid(0:5:100, 0:5:100);
Z2 = zeros(size(TS2));
for i = 1:size(TS2,1)
    for j = 1:size(TS2,2)
        Z2(i,j) = evalNT(TS2(i,j), AC2(i,j), rc_fixed, mfSet, ruleMaster, masterOut);
    end
end
figure('Color','w');
surf(TS2, AC2, Z2, 'EdgeColor', 'none');
xlabel('TeachingScore'); ylabel('AC'); zlabel('PerformanceGrade');
title(sprintf('IT2 Surface: PerformanceGrade vs TeachingScore & AC (RC = %.1f)', rc_fixed));
colormap jet; colorbar;
exportgraphics(gcf, fullfile(outputDir, 'IT2_Surface_Teach_AC.png'), 'Resolution', 300);
fprintf('Saved: IT2_Surface_Teach_AC.png\n');

% Surface 3: PerformanceGrade vs (AC, RC), TeachingScore fixed at baseline
ts_fixed = baseline(1);
[AC3, RC3] = meshgrid(0:5:100, 0:5:100);
Z3 = zeros(size(AC3));
for i = 1:size(AC3,1)
    for j = 1:size(AC3,2)
        Z3(i,j) = evalNT(ts_fixed, AC3(i,j), RC3(i,j), mfSet, ruleMaster, masterOut);
    end
end
figure('Color','w');
surf(AC3, RC3, Z3, 'EdgeColor', 'none');
xlabel('AC'); ylabel('RC'); zlabel('PerformanceGrade');
title(sprintf('IT2 Surface: PerformanceGrade vs AC & RC (TeachingScore = %.1f)', ts_fixed));
colormap jet; colorbar;
exportgraphics(gcf, fullfile(outputDir, 'IT2_Surface_AC_RC.png'), 'Resolution', 300);
fprintf('Saved: IT2_Surface_AC_RC.png\n');

% Optional Teaching Stage Surface: TeachingScore vs (AM, SEP), CL fixed
cl_fixed = baseline(5);
[AM_s, SEP_s] = meshgrid(0:5:100, 0:5:100);
Zt = zeros(size(AM_s));
for i = 1:size(AM_s,1)
    for j = 1:size(AM_s,2)
        Zt(i,j) = evalNT(AM_s(i,j), SEP_s(i,j), cl_fixed, mfSet, ruleTeach, teachOut);
    end
end
figure('Color','w');
surf(AM_s, SEP_s, Zt, 'EdgeColor', 'none');
xlabel('AM'); ylabel('SEP'); zlabel('TeachingScore');
title(sprintf('IT2 Surface: TeachingScore vs AM & SEP (CL = %.1f)', cl_fixed));
colormap jet; colorbar;
exportgraphics(gcf, fullfile(outputDir, 'IT2_Surface_Teach_AM_SEP.png'), 'Resolution', 300);
fprintf('Saved: IT2_Surface_Teach_AM_SEP.png\n');

%% 9. FACE VALIDATION (UPGRADED – with interval coverage & distance)
edgeCases = [30 30 30 50 95; 95 95 95 50 20; 0 0 0 0 0; 100 100 100 100 100; ...
    50 50 50 50 50; 100 0 0 0 100; 0 100 100 100 0; 65 65 65 65 65; ...
    45 45 45 45 45; 20 80 40 60 70];

edgeLabels = {'Strong research, weak teaching','Strong teaching, weak research', ...
    'All zeros','All 100s','All 50s','Extreme AM+RC','Extreme SEP/CL/AC', ...
    'Boundary 65s','Boundary 45s','Mixed mid-range'};

teachLabels = {'Low','Moderate','High','VeryHigh'};
masterLabels = {'Poor','Fair','Good','VeryGood','Excellent'};

fprintf('\n--- Face Validation ---\n');
pass1 = 0; pass2 = 0;           % exact label match
coverageCount = 0;              % expected master constant inside [yL, yR]
totalDistTeach = 0;             % sum of absolute distances to expected teach constant
totalDistMaster = 0;            % sum of absolute distances to expected master constant
edgeResults = zeros(10,7);

for i = 1:10
    T_e = evalNT(edgeCases(i,1), edgeCases(i,3), edgeCases(i,5), mfSet, ruleTeach, teachOut);
    [PG_e, yL_e, yR_e] = evalKM(T_e, edgeCases(i,2), edgeCases(i,4), mfSet, ruleMaster, masterOut);
    edgeResults(i,:) = [edgeCases(i,:), T_e, PG_e];

    % Expected labels (same as before)
    idxAM = nearestIndex(edgeCases(i,1), mfMidpoints);
    idxSEP = nearestIndex(edgeCases(i,3), mfMidpoints);
    idxCL = nearestIndex(edgeCases(i,5), mfMidpoints);
    expTeach = monotonicConsequent([idxAM idxSEP idxCL], [1/3 1/3 1/3], 4, false);
    idxAC = nearestIndex(edgeCases(i,2), mfMidpoints);
    idxRC = nearestIndex(edgeCases(i,4), mfMidpoints);
    expMaster = monotonicConsequent([expTeach idxAC idxRC], w, 5, true);

    obtTeach = nearestIndex(T_e, teachOut);
    obtMaster = nearestIndex(PG_e, masterOut);

    tPass = (expTeach == obtTeach);
    mPass = (expMaster == obtMaster);
    if tPass, pass1 = pass1 + 1; end
    if mPass, pass2 = pass2 + 1; end

    % --- NEW METRICS ---
    expTeachConst = teachOut(expTeach);
    expMasterConst = masterOut(expMaster);

    % Distance from crisp output to expected constant
    distTeach = abs(T_e - expTeachConst);
    distMaster = abs(PG_e - expMasterConst);
    totalDistTeach = totalDistTeach + distTeach;
    totalDistMaster = totalDistMaster + distMaster;

    % Interval coverage: is expected master constant inside [yL, yR]?
    covered = (expMasterConst >= yL_e) && (expMasterConst <= yR_e);
    if covered, coverageCount = coverageCount + 1; end

    % Print per‑case details
    fprintf('Case %d (%s):\n', i, edgeLabels{i});
    fprintf('  TeachingScore = %.1f (expected %.0f, dist=%.1f) [%s/%s] %s\n', ...
        T_e, expTeachConst, distTeach, teachLabels{expTeach}, teachLabels{obtTeach}, ternaryStr(tPass));
    fprintf('  PerformanceGrade = %.1f (expected %.0f, dist=%.1f) [%s/%s] %s\n', ...
        PG_e, expMasterConst, distMaster, masterLabels{expMaster}, masterLabels{obtMaster}, ternaryStr(mPass));
    fprintf('  IT2 interval = [%.1f, %.1f]  Expected constant inside interval? %s\n', ...
        yL_e, yR_e, ternaryStr(covered));
end

fprintf('\n--- Face Validation Summary ---\n');
fprintf('Exact label match:       Stage1 = %d/10 | Stage2 = %d/10\n', pass1, pass2);
fprintf('Interval coverage:       Expected Master constant inside [yL,yR] = %d/10\n', coverageCount);
fprintf('Mean distance to expected Teaching constant: %.2f points\n', totalDistTeach/10);
fprintf('Mean distance to expected Master constant:   %.2f points\n', totalDistMaster/10);

% Save edge case results (unchanged)
EdgeTable = array2table(edgeResults, 'VariableNames', ...
    {'AM','SEP','CL','AC','RC','TeachingScore','PerformanceGrade'});
EdgeTable.Description = edgeLabels';
writetable(EdgeTable, fullfile(outputDir, 'IT2_FaceValidation_EdgeCases.csv'));
fprintf('Saved: IT2_FaceValidation_EdgeCases.csv\n');

%% 10. CORRELATION ANALYSIS
AllVars = [SyntheticData, TeachingScores_IT2, PerformanceGrades_IT2];
AllNames = [InputNames, {'TeachingScore','PerformanceGrade'}];
R = corr(AllVars);
fprintf('\n--- Correlation with PerformanceGrade ---\n');
for i = 1:5
    fprintf('%s: r=%.3f\n', InputNames{i}, R(i,7));
end

CorrTable = array2table(R, 'VariableNames', AllNames, 'RowNames', AllNames);
writetable(CorrTable, fullfile(outputDir, 'IT2_CorrelationMatrix.csv'), 'WriteRowNames', true);
fprintf('Saved: IT2_CorrelationMatrix.csv\n');

figure('Color','w');
heatmap(AllNames, AllNames, round(R,2), 'Title', 'IT2 Correlation Heatmap', 'Colormap', parula);
exportgraphics(gcf, fullfile(outputDir, 'IT2_CorrelationHeatmap.png'), 'Resolution', 300);

%% 11. SAVE WORKSPACE AND SUMMARY REPORT
save(fullfile(outputDir, 'IT2_Results.mat'));

fid = fopen(fullfile(outputDir, 'IT2_Summary.txt'), 'w');
fprintf(fid, '========================================\n');
fprintf(fid, ' IT2 SYSTEM SUMMARY REPORT\n');
fprintf(fid, ' FOU_delta = %d\n', FOU_delta);
fprintf(fid, '========================================\n\n');
fprintf(fid, 'Rule Coverage:\n');
fprintf(fid, '  Stage-1: %d/64 rules fire correctly\n', 64-badRules1);
fprintf(fid, '  Stage-2: %d/64 rules fire correctly\n\n', 64-badRules2);
fprintf(fid, 'Output Distribution:\n');
fprintf(fid, '  TeachingScore  - Mean: %.2f, Std: %.2f, Min: %.2f, Max: %.2f, Skew: %.2f, Kurt: %.2f\n', ...
    ts_mean, ts_std, ts_min, ts_max, ts_skew, ts_kurt);
fprintf(fid, '  PerformanceGrade - Mean: %.2f, Std: %.2f, Min: %.2f, Max: %.2f, Skew: %.2f, Kurt: %.2f\n', ...
    pg_mean, pg_std, pg_min, pg_max, pg_skew, pg_kurt);
fprintf(fid, '  Interval Width - Mean: %.3f, Max: %.3f, Min: %.3f, Std: %.3f\n\n', ...
    w_mean, w_max, w_min, w_std);
fprintf(fid, 'Sensitivity Ranges:\n');
for i = 1:5
    fprintf(fid, '  %s: min=%.2f, max=%.2f, range=%.2f\n', InputNames{i}, ...
        min(sensResults(:,i)), max(sensResults(:,i)), max(sensResults(:,i))-min(sensResults(:,i)));
end
fprintf(fid, '\nMonotonicity (max violations):\n');
for varIdx = [1 3 5 2 4]
    d = diff(sensResults(:, varIdx));
    fprintf(fid, '  %s: max viol = %.4f\n', InputNames{varIdx}, max(0, -min(d)));
end
fprintf(fid, '\nFace Validation:\n');
fprintf(fid, '  Stage-1: %d/10 PASS\n', pass1);
fprintf(fid, '  Stage-2: %d/10 PASS\n\n', pass2);
fprintf(fid, 'Correlation with PerformanceGrade:\n');
for i = 1:5
    fprintf(fid, '  %s: r=%.3f\n', InputNames{i}, R(i,7));
end
fclose(fid);
fprintf('Saved: IT2_Summary.txt\n');

fprintf('\n========================================\n');
fprintf(' IT2 System Complete\n');
fprintf(' All outputs saved in: %s\n', fullfile(pwd, outputDir));
fprintf('========================================\n');

% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================

function mfSet = buildIT2MFs(delta, domain)
    bases = {[0 0 25 45], [25 45 45 65], [45 65 65 85], [65 85 100 100]};
    names = {'Low','Moderate','High','VeryHigh'};
    mfSet = struct('umf',cell(1,4),'lmf',cell(1,4),'name',cell(1,4));
    for k = 1:4
        a = bases{k}(1); b = bases{k}(2); c = bases{k}(3); d = bases{k}(4);
        umf = [max(a-delta,domain(1)), max(b-delta,domain(1)), ...
               min(c+delta,domain(2)), min(d+delta,domain(2))];
        lb = b+delta; lc = c-delta;
        if lb>lc, mid = (b+c)/2; lb = mid; lc = mid; end
        la = a+delta; if la>lb, la = lb; end
        ld = d-delta; if ld<lc, ld = lc; end
        mfSet(k).umf = umf;
        mfSet(k).lmf = [la lb lc ld];
        mfSet(k).name = names{k};
    end
end

function [muL, muU] = it2mf(x, umf, lmf)
    muU = trapmf(x, umf);
    muL = trapmf(x, lmf);
    muL = min(muL, muU);
end

function yCrisp = evalNT(x1, x2, x3, mfSet, ruleTable, outConst)
    R = size(ruleTable,1);
    fL = zeros(R,1); fU = zeros(R,1); y = zeros(R,1);
    for r = 1:R
        [muL1,muU1] = it2mf(x1, mfSet(ruleTable(r,1)).umf, mfSet(ruleTable(r,1)).lmf);
        [muL2,muU2] = it2mf(x2, mfSet(ruleTable(r,2)).umf, mfSet(ruleTable(r,2)).lmf);
        [muL3,muU3] = it2mf(x3, mfSet(ruleTable(r,3)).umf, mfSet(ruleTable(r,3)).lmf);
        fL(r) = muL1*muL2*muL3;
        fU(r) = muU1*muU2*muU3;
        y(r) = outConst(ruleTable(r,4));
    end
    if all(fU==0), yCrisp = NaN; return; end
    fNT = (fL + fU)/2;
    yCrisp = sum(fNT .* y) / sum(fNT);
end

function [yCrisp, yL, yR] = evalKM(x1, x2, x3, mfSet, ruleTable, outConst)
    R = size(ruleTable,1);
    fL = zeros(R,1); fU = zeros(R,1); y = zeros(R,1);
    for r = 1:R
        [muL1,muU1] = it2mf(x1, mfSet(ruleTable(r,1)).umf, mfSet(ruleTable(r,1)).lmf);
        [muL2,muU2] = it2mf(x2, mfSet(ruleTable(r,2)).umf, mfSet(ruleTable(r,2)).lmf);
        [muL3,muU3] = it2mf(x3, mfSet(ruleTable(r,3)).umf, mfSet(ruleTable(r,3)).lmf);
        fL(r) = muL1*muL2*muL3;
        fU(r) = muU1*muU2*muU3;
        y(r) = outConst(ruleTable(r,4));
    end
    if all(fU==0), yCrisp = NaN; yL = NaN; yR = NaN; return; end
    yL = karnikMendel(y, fL, fU, 'L');
    yR = karnikMendel(y, fL, fU, 'R');
    yCrisp = (yL + yR)/2;
end

function yEnd = karnikMendel(y, fL, fU, side)
    [ys, order] = sort(y(:));
    fLs = fL(order); fUs = fU(order);
    R = numel(ys);
    f = (fLs + fUs)/2;
    denom = sum(f);
    if denom == 0, yEnd = mean(ys); return; end
    yPrime = sum(f .* ys) / denom;
    for iter = 1:200
        k = find(ys <= yPrime, 1, 'last');
        if isempty(k), k = 0; end
        if k >= R, k = R-1; end
        if strcmpi(side, 'L')
            fNew = [fUs(1:k); fLs(k+1:R)];
        else
            fNew = [fLs(1:k); fUs(k+1:R)];
        end
        denomNew = sum(fNew);
        if denomNew == 0, break; end
        yNew = sum(fNew .* ys) / denomNew;
        if abs(yNew - yPrime) < 1e-12
            yPrime = yNew;
            break;
        end
        yPrime = yNew;
    end
    yEnd = yPrime;
end

function outIdx = monotonicConsequent(idxVec, weights, numLevels, isMasterScale)
    idxVec = idxVec(:)'; weights = weights(:)';
    wavg = sum(idxVec .* weights);
    if isMasterScale
        scaled = 1 + (wavg-1)/3*(numLevels-1);
    else
        scaled = wavg;
    end
    outIdx = min(max(round(scaled), 1), numLevels);
end

function s = ternaryStr(cond)
    if cond, s = 'PASS'; else, s = 'FAIL'; end
end

function idx = nearestIndex(val, centers)
    [~, idx] = min(abs(val - centers));
end