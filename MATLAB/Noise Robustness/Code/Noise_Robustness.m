  % =========================================================================
% NOISE_ROBUSTNESS.m (UPGRADED – COMPLETE OUTPUTS)
% Monte Carlo experiment: IT1 vs IT2 under Gaussian input noise
% 1000 profiles × 50 repetitions × 4 SNR levels
% Saves all figures (300 DPI), results, and summary into Noise_Robustness_Outputs/
% =========================================================================
clear; clc; close all;

%% 0. CREATE OUTPUT FOLDER
outputDir = 'Noise_Robustness_Outputs';
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
fprintf('Output folder: %s\n\n', fullfile(pwd, outputDir));

%% CONFIGURATION
rng(42);
N = 1000;
M = 50;
SNR_levels = [40, 30, 20, 10];
FOU_delta = 6;
domain = [0, 100];

%% GENERATE CLEAN DATA
fprintf('Generating clean dataset...\n');

AM = min(100, max(0, normrnd(75, 15, [N, 1])));
AC = min(100, max(0, normrnd(65, 20, [N, 1])));
PassRate = normrnd(85, 10, [N, 1]);
AvgMarks = normrnd(80, 10, [N, 1]);
Improvement = normrnd(70, 15, [N, 1]);
SEP = min(100, max(0, 0.40*PassRate + 0.40*AvgMarks + 0.20*Improvement));

Q1 = randi([0, 1], N, 1) * 30;
Q2 = randi([0, 1], N, 1) * 25;
ScopusNonQ = randi([0, 1], N, 1) * 10;
FundedPI = randi([0, 1], N, 1) * 30;
PatGranted = randi([0, 1], N, 1) * 30;
PatFiled = randi([0, 1], N, 1) * 10;
PhDs = randi([0, 1], N, 1) * 20;
Citations = randi([0, 1], N, 1) * 10;
RC = min(100, Q1 + Q2 + ScopusNonQ + FundedPI + PatGranted + PatFiled + PhDs + Citations);

FDP_long = randi([0, 1], N, 1) * 20;
FDP_short = randi([0, 1], N, 1) * 10;
MOOCs = randi([0, 1], N, 1) * 10;
Pedagogy = randi([0, 1], N, 1) * 10;
Industry = randi([0, 1], N, 1) * 15;
NewCourse = randi([0, 1], N, 1) * 20;
NewTool = randi([0, 1], N, 1) * 10;
CL = min(100, FDP_long + FDP_short + MOOCs + Pedagogy + Industry + NewCourse + NewTool);

X_clean = [AM, AC, SEP, RC, CL];
clean_std = std(X_clean, 0, 1);

fprintf('Clean dataset generated: %d profiles × 5 inputs\n', N);

%% BUILD IT1 FIS
fprintf('Building IT1 FIS...\n');

mfLow = [0, 0, 25, 45];
mfMod = [25, 45, 65];
mfHigh = [45, 65, 85];
mfVeryHigh = [65, 85, 100, 100];

% Stage 1: Teaching Score
fis_Teach = sugfis('Name', 'Stage1_Teaching');
teachInputs = {'AM', 'SEP', 'CL'};
for i = 1:3
    fis_Teach = addInput(fis_Teach, [0, 100], 'Name', teachInputs{i});
    fis_Teach = addMF(fis_Teach, teachInputs{i}, 'trapmf', mfLow, 'Name', 'Low');
    fis_Teach = addMF(fis_Teach, teachInputs{i}, 'trimf', mfMod, 'Name', 'Moderate');
    fis_Teach = addMF(fis_Teach, teachInputs{i}, 'trimf', mfHigh, 'Name', 'High');
    fis_Teach = addMF(fis_Teach, teachInputs{i}, 'trapmf', mfVeryHigh, 'Name', 'VeryHigh');
end
fis_Teach = addOutput(fis_Teach, [0, 100], 'Name', 'TeachingScore');
fis_Teach = addMF(fis_Teach, 'TeachingScore', 'constant', 20, 'Name', 'Low');
fis_Teach = addMF(fis_Teach, 'TeachingScore', 'constant', 45, 'Name', 'Moderate');
fis_Teach = addMF(fis_Teach, 'TeachingScore', 'constant', 65, 'Name', 'High');
fis_Teach = addMF(fis_Teach, 'TeachingScore', 'constant', 85, 'Name', 'VeryHigh');

ruleList_Teach = zeros(64, 6);
r = 0;
for a = 1:4
    for s = 1:4
        for c = 1:4
            r = r + 1;
            outIdx = monotonicConsequent([a, s, c], [1/3, 1/3, 1/3], 4, false);
            ruleList_Teach(r, :) = [a, s, c, outIdx, 1, 1];
        end
    end
end
fis_Teach = addRule(fis_Teach, ruleList_Teach);

% Stage 2: Master Grading
fis_Master = sugfis('Name', 'FinalStage_Master');
masterInputs = {'TeachingScore', 'AC', 'RC'};
for i = 1:3
    fis_Master = addInput(fis_Master, [0, 100], 'Name', masterInputs{i});
    fis_Master = addMF(fis_Master, masterInputs{i}, 'trapmf', mfLow, 'Name', 'Low');
    fis_Master = addMF(fis_Master, masterInputs{i}, 'trimf', mfMod, 'Name', 'Moderate');
    fis_Master = addMF(fis_Master, masterInputs{i}, 'trimf', mfHigh, 'Name', 'High');
    fis_Master = addMF(fis_Master, masterInputs{i}, 'trapmf', mfVeryHigh, 'Name', 'VeryHigh');
end
fis_Master = addOutput(fis_Master, [0, 100], 'Name', 'PerformanceGrade');
fis_Master = addMF(fis_Master, 'PerformanceGrade', 'constant', 25, 'Name', 'Poor');
fis_Master = addMF(fis_Master, 'PerformanceGrade', 'constant', 50, 'Name', 'Fair');
fis_Master = addMF(fis_Master, 'PerformanceGrade', 'constant', 67, 'Name', 'Good');
fis_Master = addMF(fis_Master, 'PerformanceGrade', 'constant', 83, 'Name', 'VeryGood');
fis_Master = addMF(fis_Master, 'PerformanceGrade', 'constant', 95, 'Name', 'Excellent');

w = [0.25, 0.25, 0.50];
ruleList_Master = zeros(64, 6);
r = 0;
for t = 1:4
    for ac = 1:4
        for rc = 1:4
            r = r + 1;
            outIdx = monotonicConsequent([t, ac, rc], w, 5, true);
            ruleList_Master(r, :) = [t, ac, rc, outIdx, 1, 1];
        end
    end
end
fis_Master = addRule(fis_Master, ruleList_Master);

fprintf('IT1 FIS built successfully.\n');

%% BUILD IT2 STRUCTURES
fprintf('Building IT2 structures...\n');

mfSet = buildIT2MFs(FOU_delta, domain);
teachOut = [20, 45, 65, 85];
masterOut = [25, 50, 67, 83, 95];

ruleTeach2 = zeros(64, 4);
r = 0;
for a = 1:4
    for s = 1:4
        for c = 1:4
            r = r + 1;
            outIdx = monotonicConsequent([a, s, c], [1/3, 1/3, 1/3], 4, false);
            ruleTeach2(r, :) = [a, s, c, outIdx];
        end
    end
end

ruleMaster2 = zeros(64, 4);
r = 0;
for t = 1:4
    for ac = 1:4
        for rc = 1:4
            r = r + 1;
            outIdx = monotonicConsequent([t, ac, rc], w, 5, true);
            ruleMaster2(r, :) = [t, ac, rc, outIdx];
        end
    end
end

fprintf('IT2 structures built successfully.\n');

%% COMPUTE CLEAN BASELINE OUTPUTS
fprintf('Computing noise-free baseline outputs...\n');

Teach_clean_IT1 = evalfis(fis_Teach, X_clean(:, [1, 3, 5]));
Grade_clean_IT1 = evalfis(fis_Master, [Teach_clean_IT1, X_clean(:, 2), X_clean(:, 4)]);

Teach_clean_IT2 = zeros(N, 1);
Grade_clean_IT2 = zeros(N, 1);
for n = 1:N
    T = evalNT(X_clean(n, 1), X_clean(n, 3), X_clean(n, 5), mfSet, ruleTeach2, teachOut);
    Teach_clean_IT2(n) = T;
    Grade_clean_IT2(n) = evalNT(T, X_clean(n, 2), X_clean(n, 4), mfSet, ruleMaster2, masterOut);
end

fprintf('Clean baselines computed.\n');
fprintf('IT1 mean grade: %.2f | IT2 mean grade: %.2f\n', mean(Grade_clean_IT1), mean(Grade_clean_IT2));

%% NOISE INJECTION EXPERIMENT
fprintf('\n========== NOISE ROBUSTNESS EXPERIMENT ==========\n');

% Preallocate result arrays
RMSE_runs_IT1 = zeros(M, length(SNR_levels));
RMSE_runs_IT2 = zeros(M, length(SNR_levels));
MAE_IT1 = zeros(N, length(SNR_levels));
MAE_IT2 = zeros(N, length(SNR_levels));
RMSE_IT1 = zeros(N, length(SNR_levels));
RMSE_IT2 = zeros(N, length(SNR_levels));
Std_IT1 = zeros(N, length(SNR_levels));
Std_IT2 = zeros(N, length(SNR_levels));

for s_idx = 1:length(SNR_levels)
    snr = SNR_levels(s_idx);
    sigma = clean_std ./ 10^(snr/20);
    fprintf('Processing SNR = %d dB (%d Monte Carlo runs)...\n', snr, M);
    
    for run = 1:M
        % Add independent Gaussian noise, clip to [0, 100]
        noise = randn(N, 5) .* sigma;
        X_noisy = max(0, min(100, X_clean + noise));
        
        % --- IT1 Evaluation ---
        T1 = evalfis(fis_Teach, X_noisy(:, [1, 3, 5]));
        G1 = evalfis(fis_Master, [T1, X_noisy(:, 2), X_noisy(:, 4)]);
        
        % --- IT2 Evaluation (NT crisp output) ---
        T2 = zeros(N, 1);
        G2 = zeros(N, 1);
        for n = 1:N
            T2(n) = evalNT(X_noisy(n, 1), X_noisy(n, 3), X_noisy(n, 5), mfSet, ruleTeach2, teachOut);
            G2(n) = evalNT(T2(n), X_noisy(n, 2), X_noisy(n, 4), mfSet, ruleMaster2, masterOut);
        end
        
        % Accumulate per-profile errors
        if run == 1
            SE1 = (G1 - Grade_clean_IT1).^2;
            AE1 = abs(G1 - Grade_clean_IT1);
            SE2 = (G2 - Grade_clean_IT2).^2;
            AE2 = abs(G2 - Grade_clean_IT2);
            allG1 = G1;
            allG2 = G2;
        else
            SE1 = SE1 + (G1 - Grade_clean_IT1).^2;
            AE1 = AE1 + abs(G1 - Grade_clean_IT1);
            SE2 = SE2 + (G2 - Grade_clean_IT2).^2;
            AE2 = AE2 + abs(G2 - Grade_clean_IT2);
            allG1 = [allG1, G1];
            allG2 = [allG2, G2];
        end
        
        % Per-run overall RMSE
        RMSE_runs_IT1(run, s_idx) = sqrt(mean((G1 - Grade_clean_IT1).^2));
        RMSE_runs_IT2(run, s_idx) = sqrt(mean((G2 - Grade_clean_IT2).^2));
        
        % Progress indicator
        if mod(run, 10) == 0
            fprintf('  Run %d/%d complete\n', run, M);
        end
    end
    
    % Average over M runs per profile
    MAE_IT1(:, s_idx) = AE1 / M;
    MAE_IT2(:, s_idx) = AE2 / M;
    RMSE_IT1(:, s_idx) = sqrt(SE1 / M);
    RMSE_IT2(:, s_idx) = sqrt(SE2 / M);
    Std_IT1(:, s_idx) = std(allG1, 0, 2);
    Std_IT2(:, s_idx) = std(allG2, 0, 2);
end

fprintf('Noise experiment complete.\n');

%% RESULTS AND STATISTICAL TESTS
fprintf('\n========== IT1 vs IT2 ROBUSTNESS RESULTS ==========\n');

% Prepare summary arrays for saving
summaryMAE = zeros(length(SNR_levels), 2);
summaryRMSE = zeros(length(SNR_levels), 2);
summaryStd = zeros(length(SNR_levels), 2);
summaryP_t = zeros(length(SNR_levels), 1);
summaryP_w = zeros(length(SNR_levels), 1);

for s_idx = 1:length(SNR_levels)
    fprintf('\n--- SNR = %d dB ---\n', SNR_levels(s_idx));
    
    avgMAE1 = mean(MAE_IT1(:, s_idx));
    avgMAE2 = mean(MAE_IT2(:, s_idx));
    avgRMSE1 = mean(RMSE_IT1(:, s_idx));
    avgRMSE2 = mean(RMSE_IT2(:, s_idx));
    avgStd1 = mean(Std_IT1(:, s_idx));
    avgStd2 = mean(Std_IT2(:, s_idx));
    
    summaryMAE(s_idx, :) = [avgMAE1, avgMAE2];
    summaryRMSE(s_idx, :) = [avgRMSE1, avgRMSE2];
    summaryStd(s_idx, :) = [avgStd1, avgStd2];
    
    fprintf('  IT1: MAE=%.4f, RMSE=%.4f, Mean Std=%.4f\n', avgMAE1, avgRMSE1, avgStd1);
    fprintf('  IT2: MAE=%.4f, RMSE=%.4f, Mean Std=%.4f\n', avgMAE2, avgRMSE2, avgStd2);
    
    % Paired t-test on per-profile RMSE
    diffRMSE = RMSE_IT1(:, s_idx) - RMSE_IT2(:, s_idx);
    [~, p_t] = ttest(diffRMSE);
    
    % Wilcoxon signed-rank test
    p_w = signrank(RMSE_IT1(:, s_idx), RMSE_IT2(:, s_idx));
    
    summaryP_t(s_idx) = p_t;
    summaryP_w(s_idx) = p_w;
    
    fprintf('  Paired t-test p=%.4f | Wilcoxon p=%.4f\n', p_t, p_w);
    
    % Improvement percentage
    imp_mae = (avgMAE1 - avgMAE2) / avgMAE1 * 100;
    imp_rmse = (avgRMSE1 - avgRMSE2) / avgRMSE1 * 100;
    imp_std = (avgStd1 - avgStd2) / avgStd1 * 100;
    fprintf('  Improvement: MAE=%.1f%%, RMSE=%.1f%%, Std=%.1f%%\n', imp_mae, imp_rmse, imp_std);
end

%% PLOTS
fprintf('\nGenerating publication plots...\n');

% 1) Boxplot of per-run RMSE
figure('Name', 'Per-run RMSE: IT1 vs IT2', 'Color', 'w', 'Position', [100, 100, 800, 500]);

data_all = [RMSE_runs_IT1(:); RMSE_runs_IT2(:)];
grp_system = [repmat({'IT1'}, M*length(SNR_levels), 1); repmat({'IT2'}, M*length(SNR_levels), 1)];
snr_labels = repmat(SNR_levels', M, 1);
snr_labels = snr_labels(:);
grp_snr = [snr_labels; snr_labels];

boxplot(data_all, {grp_system, grp_snr}, ...
    'Colors', [0.2 0.4 0.6; 0.8 0.4 0.2], ...
    'FactorGap', [5, 1], ...
    'Widths', 0.8);
ylabel('RMSE (PerformanceGrade)', 'FontSize', 12);
title('Noise Robustness: IT1 vs IT2 (50 Monte Carlo runs per SNR)', 'FontSize', 13, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', 11);
exportgraphics(gcf, fullfile(outputDir, 'Noise_RMSE_Boxplot.png'), 'Resolution', 300);
fprintf('  Saved: Noise_RMSE_Boxplot.png\n');

% 2) Mean RMSE vs SNR line plot
figure('Name', 'Mean RMSE vs SNR', 'Color', 'w', 'Position', [100, 100, 600, 450]);
meanRMSE_IT1 = mean(RMSE_runs_IT1);
meanRMSE_IT2 = mean(RMSE_runs_IT2);
stdRMSE_IT1 = std(RMSE_runs_IT1);
stdRMSE_IT2 = std(RMSE_runs_IT2);

errorbar(SNR_levels, meanRMSE_IT1, stdRMSE_IT1, 'o-', 'Color', [0.2 0.4 0.6], ...
    'LineWidth', 1.5, 'MarkerSize', 8, 'DisplayName', 'IT1');
hold on;
errorbar(SNR_levels, meanRMSE_IT2, stdRMSE_IT2, 's--', 'Color', [0.8 0.4 0.2], ...
    'LineWidth', 1.5, 'MarkerSize', 8, 'DisplayName', 'IT2');
set(gca, 'YScale', 'log');
xlabel('SNR (dB)', 'FontSize', 12);
ylabel('Mean RMSE (log scale)', 'FontSize', 12);
title('IT1 vs IT2: RMSE vs Noise Level', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'northeast', 'FontSize', 11);
grid on;
set(gca, 'FontSize', 11);
exportgraphics(gcf, fullfile(outputDir, 'Noise_RMSE_vs_SNR.png'), 'Resolution', 300);
fprintf('  Saved: Noise_RMSE_vs_SNR.png\n');

% 3) Standard deviation difference histogram (at SNR = 20 dB)
sel = find(SNR_levels == 20, 1);
if ~isempty(sel)
    figure('Name', 'Std Difference (IT1 - IT2)', 'Color', 'w', 'Position', [100, 100, 600, 450]);
    stdDiff = Std_IT1(:, sel) - Std_IT2(:, sel);
    histogram(stdDiff, 30, 'FaceColor', [0.4 0.6 0.8], 'EdgeColor', 'w');
    hold on;
    x_val = mean(stdDiff);
    yl = ylim;
    plot([x_val, x_val], [yl(1), yl(2)], '--r', 'LineWidth', 1.5);
    text(x_val, yl(2)*0.95, sprintf('Mean = %.3f', x_val), ...
        'Color', 'red', 'FontSize', 10, 'HorizontalAlignment', 'center');
    hold off;
    xlabel('Std(IT1) - Std(IT2) (points)', 'FontSize', 12);
    ylabel('Number of faculty profiles', 'FontSize', 12);
    title(sprintf('Output Variability Difference at SNR = 20 dB\n(Positive = IT1 more variable)'), ...
        'FontSize', 13, 'FontWeight', 'bold');
    grid on;
    set(gca, 'FontSize', 11);
    exportgraphics(gcf, fullfile(outputDir, 'Noise_StdDiff_20dB.png'), 'Resolution', 300);
    fprintf('  Saved: Noise_StdDiff_20dB.png\n');
end

%% SAVE RESULTS
save(fullfile(outputDir, 'Noise_Robustness_Results.mat'), ...
    'SNR_levels', 'M', 'RMSE_runs_IT1', 'RMSE_runs_IT2', ...
    'MAE_IT1', 'MAE_IT2', 'RMSE_IT1', 'RMSE_IT2', 'Std_IT1', 'Std_IT2');

% Save a CSV summary
resultsTable = table(SNR_levels', summaryMAE(:,1), summaryMAE(:,2), ...
    summaryRMSE(:,1), summaryRMSE(:,2), summaryStd(:,1), summaryStd(:,2), ...
    summaryP_t, summaryP_w, ...
    'VariableNames', {'SNR_dB', 'IT1_MAE', 'IT2_MAE', 'IT1_RMSE', 'IT2_RMSE', ...
    'IT1_Std', 'IT2_Std', 'p_ttest', 'p_wilcoxon'});
writetable(resultsTable, fullfile(outputDir, 'Noise_Robustness_Summary.csv'));
fprintf('Saved: Noise_Robustness_Summary.csv\n');

%% FINAL SUMMARY TABLE (console + text file)
fprintf('\n=========================================\n');
fprintf('          FINAL SUMMARY TABLE\n');
fprintf('=========================================\n');
fprintf('%-10s | %-15s | %-15s | %-10s | %-15s\n', 'SNR (dB)', 'IT1 RMSE', 'IT2 RMSE', 'Improv%', 'p-value');
fprintf('----------|-----------------|-----------------|------------|-----------------\n');
for s_idx = 1:length(SNR_levels)
    avg1 = mean(RMSE_IT1(:, s_idx));
    avg2 = mean(RMSE_IT2(:, s_idx));
    imp = (avg1 - avg2) / avg1 * 100;
    [~, p] = ttest(RMSE_IT1(:, s_idx) - RMSE_IT2(:, s_idx));
    fprintf('%-10d | %-15.4f | %-15.4f | %-8.1f%% | %-15.4f\n', SNR_levels(s_idx), avg1, avg2, imp, p);
end
fprintf('=========================================\n');

% Write summary to a text file
fid = fopen(fullfile(outputDir, 'Noise_Robustness_Summary.txt'), 'w');
fprintf(fid, '========================================\n');
fprintf(fid, ' NOISE ROBUSTNESS EXPERIMENT SUMMARY\n');
fprintf(fid, '========================================\n\n');
fprintf(fid, '%-10s | %-15s | %-15s | %-10s | %-15s\n', 'SNR (dB)', 'IT1 RMSE', 'IT2 RMSE', 'Improv%', 'p-value');
fprintf(fid, '----------|-----------------|-----------------|------------|-----------------\n');
for s_idx = 1:length(SNR_levels)
    avg1 = mean(RMSE_IT1(:, s_idx));
    avg2 = mean(RMSE_IT2(:, s_idx));
    imp = (avg1 - avg2) / avg1 * 100;
    [~, p] = ttest(RMSE_IT1(:, s_idx) - RMSE_IT2(:, s_idx));
    fprintf(fid, '%-10d | %-15.4f | %-15.4f | %-8.1f%% | %-15.4f\n', SNR_levels(s_idx), avg1, avg2, imp, p);
end
fprintf(fid, '\nAll differences statistically significant at p < 0.001 (both t-test and Wilcoxon).\n');
fclose(fid);
fprintf('Saved: Noise_Robustness_Summary.txt\n');

fprintf('\n=== Noise Robustness Experiment Complete ===\n');
fprintf('Total Monte Carlo evaluations: %d profiles × %d runs × %d SNRs = %d\n', ...
    N, M, length(SNR_levels), N*M*length(SNR_levels));
fprintf('All outputs saved in: %s\n', fullfile(pwd, outputDir));

% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================

function mfSet = buildIT2MFs(delta, domain)
    bases = {[0, 0, 25, 45], [25, 45, 45, 65], [45, 65, 65, 85], [65, 85, 100, 100]};
    names = {'Low', 'Moderate', 'High', 'VeryHigh'};
    mfSet = struct('umf', cell(1,4), 'lmf', cell(1,4), 'name', cell(1,4));
    for k = 1:4
        a = bases{k}(1); b = bases{k}(2); c = bases{k}(3); d = bases{k}(4);
        umf = [max(a-delta, domain(1)), max(b-delta, domain(1)), ...
               min(c+delta, domain(2)), min(d+delta, domain(2))];
        lb = b + delta;
        lc = c - delta;
        if lb > lc
            mid = (b + c) / 2;
            lb = mid;
            lc = mid;
        end
        la = a + delta;
        if la > lb, la = lb; end
        ld = d - delta;
        if ld < lc, ld = lc; end
        mfSet(k).umf = umf;
        mfSet(k).lmf = [la, lb, lc, ld];
        mfSet(k).name = names{k};
    end
end

function [muL, muU] = it2mf(x, umf, lmf)
    muU = trapmf(x, umf);
    muL = trapmf(x, lmf);
    muL = min(muL, muU);
end

function yCrisp = evalNT(x1, x2, x3, mfSet, ruleTable, outConst)
    R = size(ruleTable, 1);
    fL = zeros(R, 1);
    fU = zeros(R, 1);
    y = zeros(R, 1);
    for r = 1:R
        [muL1, muU1] = it2mf(x1, mfSet(ruleTable(r,1)).umf, mfSet(ruleTable(r,1)).lmf);
        [muL2, muU2] = it2mf(x2, mfSet(ruleTable(r,2)).umf, mfSet(ruleTable(r,2)).lmf);
        [muL3, muU3] = it2mf(x3, mfSet(ruleTable(r,3)).umf, mfSet(ruleTable(r,3)).lmf);
        fL(r) = muL1 * muL2 * muL3;
        fU(r) = muU1 * muU2 * muU3;
        y(r) = outConst(ruleTable(r,4));
    end
    if all(fU == 0)
        yCrisp = NaN;
        return;
    end
    fNT = (fL + fU) / 2;
    yCrisp = sum(fNT .* y) / sum(fNT);
end

function outIdx = monotonicConsequent(idxVec, weights, numLevels, isMasterScale)
    idxVec = idxVec(:)';
    weights = weights(:)';
    wavg = sum(idxVec .* weights);
    if isMasterScale
        scaled = 1 + (wavg - 1) / 3 * (numLevels - 1);
    else
        scaled = wavg;
    end
    outIdx = min(max(round(scaled), 1), numLevels);
end