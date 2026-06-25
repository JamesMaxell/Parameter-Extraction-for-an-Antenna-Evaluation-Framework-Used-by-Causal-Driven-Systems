%% 合并代码：S参数数据提取、处理与算法分析
%%此代码功能（20260119）：两个代码合并，使得用户输入一个S参数（如S(1,1)）后，
% 程序能够自动从原始CSV文件中提取该S参数的数据，然后进行算法处理并输出图片，
% 而不需要中间保存Excel文件
clc; clear; close all;

%% 第一部分：从CSV文件提取指定S参数数据并预处理

% 用户输入要提取的S参数
prompt = '请输入要提取的S参数（如 S(1,1)）：';
s_param = input(prompt, 's');

% 文件路径设置
input_file = 'S0101_S1601_20_2_80_f_100_20_1100MHz_人脑中含出血点仿真.csv'; % 原始文件名

fprintf('=== S参数数据提取与处理 ===\n');
fprintf('正在提取 S参数: %s\n', s_param);

%% 1. 使用 readtable 读取数据
try
    % 使用 readtable 读取所有数据
    opts = detectImportOptions(input_file);
    opts.PreserveVariableNames = true;
    data_table = readtable(input_file, opts);
    fprintf('表格大小: %d 行 × %d 列\n', height(data_table), width(data_table));
catch
    error('读取文件失败，请检查文件格式和路径。');
end

%% 2. 筛选匹配指定 S 参数的列
all_headers = data_table.Properties.VariableNames;
matching_columns = false(1, length(all_headers));
for i = 1:length(all_headers)
    if contains(all_headers{i}, s_param, 'IgnoreCase', true)
        matching_columns(i) = true;
    end
end

% 总是保留第一列（假设是频率列）
matching_columns(1) = true;

if sum(matching_columns) <= 1
    error('未找到匹配的列，请检查输入的 S 参数是否正确。');
end

% 提取筛选后的数据
filtered_table = data_table(:, matching_columns);
fprintf('找到 %d 个匹配列\n', sum(matching_columns)-1);

%% 3. 清理列标题：从 'dB(S(1,1)) [] - $e2='22'' 提取为 '22'
original_headers = filtered_table.Properties.VariableNames;
new_headers = cell(1, length(original_headers));

for i = 1:length(original_headers)
    header = original_headers{i};
    
    % 对于第一列（频率列），保持不变
    if i == 1
        new_headers{i} = header;
        continue;
    end
    
    % 查找单引号内的数字
    pattern = '''(\d+)''';
    matches = regexp(header, pattern, 'tokens');
    
    if ~isempty(matches) && ~isempty(matches{1})
        % 提取第一个匹配的数字
        new_headers{i} = matches{1}{1};
    else
        % 如果没有匹配，保持原样
        new_headers{i} = header;
    end
end

% 应用新的列标题
filtered_table.Properties.VariableNames = new_headers;

%% 4. 处理缺失值：使用左右两边数据的平均值填充
fprintf('正在处理缺失值...\n');
[n_rows, n_cols] = size(filtered_table);
missing_count = 0;

% 处理每一列（从第二列开始）
for col = 2:n_cols
    for row = 1:n_rows
        current_value = filtered_table{row, col};
        
        % 检查当前值是否为NaN（缺失值）
        if isnan(current_value)
            % 尝试获取左右相邻的非缺失值
            left_value = NaN;
            right_value = NaN;
            
            % 向左寻找非缺失值
            left_idx = row - 1;
            while left_idx >= 1 && isnan(left_value)
                left_value = filtered_table{left_idx, col};
                if isnan(left_value)
                    left_idx = left_idx - 1;
                end
            end
            
            % 向右寻找非缺失值
            right_idx = row + 1;
            while right_idx <= n_rows && isnan(right_value)
                right_value = filtered_table{right_idx, col};
                if isnan(right_value)
                    right_idx = right_idx + 1;
                end
            end
            
            % 根据找到的值计算平均值
            if ~isnan(left_value) && ~isnan(right_value)
                % 左右都有值，取平均
                avg_value = (left_value + right_value) / 2;
                filtered_table{row, col} = avg_value;
                missing_count = missing_count + 1;
            elseif ~isnan(left_value)
                % 只有左边有值，使用左边值
                filtered_table{row, col} = left_value;
                missing_count = missing_count + 1;
            elseif ~isnan(right_value)
                % 只有右边有值，使用右边值
                filtered_table{row, col} = right_value;
                missing_count = missing_count + 1;
            end
        end
    end
end

fprintf('共处理了 %d 个缺失值\n', missing_count);
fprintf('数据提取与预处理完成！\n\n');

%% 第二部分：Theil-Sen估计算法分析

fprintf('=== Theil-Sen估计算法分析 ===\n');

% 将表格转换为cell数组，以便与第二个代码兼容
data_cell = [filtered_table.Properties.VariableNames; table2cell(filtered_table)];

% 检查读取的数据结构
disp('数据大小:');
disp(size(data_cell));

% 从第二行第二列开始读取有效数据，第一列为频率f
f_cells = data_cell(2:end, 1); % 从第二行开始读取频率f
% 确保频率是数值类型
f = zeros(length(f_cells), 1);
for i = 1:length(f_cells)
    if isnumeric(f_cells{i})
        f(i) = f_cells{i};
    elseif ischar(f_cells{i}) || isstring(f_cells{i})
        f(i) = str2double(f_cells{i});
    else
        f(i) = NaN;
    end
end

% 读取表头并转换为数值
header_cells = data_cell(1, 2:end);
x = zeros(1, length(header_cells));
for i = 1:length(header_cells)
    if ischar(header_cells{i}) || isstring(header_cells{i})
        % 去掉可能的单引号
        cell_str = strrep(header_cells{i}, '''', '');
        x(i) = str2double(cell_str);
        if isnan(x(i))
            fprintf('警告: 无法将表头第%d个元素转换为数值: %s\n', i, header_cells{i});
        end
    elseif isnumeric(header_cells{i})
        x(i) = header_cells{i};
    else
        x(i) = NaN;
    end
end

disp('x值:');
disp(x);

% 检查x值是否为正数（因为要取对数）
if any(x <= 0)
    error('x值中有非正数，无法进行对数运算！');
end

% 对x值进行自然对数处理
x_ln = log(x);

% 读取y值
y_cells = data_cell(2:end, 2:end); % 从第三行开始的所有有效y值
[num_y, num_x] = size(y_cells);

% 将y值转换为数值矩阵
y_values = zeros(num_y, num_x);
for i = 1:num_y
    for j = 1:num_x
        if isnumeric(y_cells{i, j})
            y_values(i, j) = y_cells{i, j};
        elseif ischar(y_cells{i, j}) || isstring(y_cells{i, j})
            y_values(i, j) = str2double(y_cells{i, j});
            if isnan(y_values(i, j))
                fprintf('警告: y值(%d,%d)无法转换为数值: %s\n', i, j, y_cells{i, j});
            end
        else
            y_values(i, j) = NaN;
        end
    end
end

% 检查是否有NaN值
nan_count = sum(sum(isnan(y_values)));
if nan_count > 0
    fprintf('警告: y_values中有 %d 个NaN值\n', nan_count);
end

% 初始化存储所有Theil-Sen斜率和截距的矩阵
slopes = zeros(num_y, 1);
mads = zeros(num_y, 1);
mads_mcss = zeros(num_y, 1);

% 计算每组数据的Theil-Sen估计斜率和MAD
for k = 1:num_y
    y = y_values(k, :);
    
    % 找出有效数据点（没有NaN）
    valid_idx = ~isnan(y);
    x_ln_valid = x_ln(valid_idx);
    y_valid = y(valid_idx);
    
    if length(y_valid) < 2
        fprintf('警告: 第%d行有效数据点不足2个，跳过\n', k);
        slopes(k) = NaN;
        mads(k) = NaN;
        mads_mcss(k) = NaN;
        continue;
    end
    
    % 初始化存储所有斜率的向量
    temp_slopes = [];
    
    % 计算任意两点的斜率并存储
    n_valid = length(y_valid);
    for i = 1:n_valid-1
        for j = i+1:n_valid
            % 确保分母不为0
            if x_ln_valid(j) ~= x_ln_valid(i)
                slope = (y_valid(j)-y_valid(i)) / (x_ln_valid(j)-x_ln_valid(i));
                temp_slopes = [temp_slopes; slope];
            end
        end
    end
    
    % 检查是否有斜率数据
    if isempty(temp_slopes)
        slopes(k) = NaN;
        mads(k) = NaN;
        mads_mcss(k) = NaN;
        continue;
    end
    
    % 计算斜率的中位数 (Theil-Sen估计的斜率)
    medianSlope = median(temp_slopes);
    slopes(k) = medianSlope;
    
    % 计算每个斜率与中位数斜率的差的绝对值
    abs_diff = abs(temp_slopes - medianSlope);
    
    % 计算这些绝对值的中位数 (Median Absolute Deviation)
    mad_value = median(abs_diff);
    mads(k) = mad_value;
    
    % 避免除以0
    if medianSlope ~= 0
        mads_mcss(k) = mad_value / abs(medianSlope);
    else
        mads_mcss(k) = NaN;
    end
end

%% 第三部分：绘图

fprintf('正在生成图像...\n');
% 绘制前几组数据点和回归线
figure_count = min(51, ceil(num_y/1)); % 最多绘制51张图

% 创建一个新的图形窗口
figure;

% 根据图表数量确定子图布局
rows = ceil(figure_count/8);  % 行数（向上取整）
cols = min(8, figure_count);  % 列数（最多2列）

for idx = 1:figure_count
    k = (idx-1)*1 + 1;
    if k > num_y
        break;
    end
    
    % 创建子图
    subplot(rows, cols, idx);
    hold on;
    y = y_values(k, :);
    scatter(x_ln, y, 'filled');
    
    % 计算并绘制回归线
    medianSlope = slopes(k);
    if ~isnan(medianSlope)
        intercepts = y - medianSlope * x_ln;
        % 移除NaN值
        intercepts_valid = intercepts(~isnan(intercepts));
        if ~isempty(intercepts_valid)
            medianIntercept = median(intercepts_valid);
            
            xFit = linspace(min(x_ln), max(x_ln), 100);
            yFit = medianSlope * xFit + medianIntercept;
            plot(xFit, yFit, '-r', 'LineWidth', 2);
        end
    end
 
    S_param_name=s_param;
    % 图形设置
    xlabel('ln(e)');%ln(x)
%    ylabel('%d',S_param_name);%y
    ylabel(sprintf('%s', S_param_name));
    title(sprintf('Freq=%dMHz', (k-1)*20+100));
    grid on;
    hold off;
end

% 添加总标题（可选）
sgtitle('Theil-Sen estimate regression analysis');

% 保存图形
% 确保 output 文件夹存在
if ~exist('output', 'dir')
    mkdir('output');
end
% 保存到 output 文件夹
filename_str = fullfile('output', ...
    sprintf('Blood_ball_in_Brain_%s_regression_Line.png', S_param_name));
set(gcf, 'Units', 'normalized', 'Position', [0 0 1 1]);% 最大化当前图形窗口
% set(gcf, 'WindowState', 'maximized'); % MATLAB R2018b及以上版本
drawnow;% 强制更新图形窗口，确保最大化生效
saveas(gcf, filename_str);
fprintf('图形已保存为: %s\n', filename_str);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 第三部分：绘图
fprintf('正在生成图像...\n');

% 获取所有频率点数量
num_frequencies = size(y_values, 1);  % 假设y_values的行对应不同频率

% 遍历每个频率点，单独绘制
for freq_idx = 1:num_frequencies
    % 创建新的图形窗口（每个频率单独一张图）
    figure;
    hold on;
    
    % 获取当前频率下的数据
    y = y_values(freq_idx, :);  % 当前频率下不同介电常数的S11值
    medianSlope = slopes(freq_idx);  % 当前频率下的Theil-Sen斜率
    
    % 绘制散点图
    scatter(x_ln, y, 'filled');
    
    % 计算并绘制回归线
    if ~isnan(medianSlope)
        intercepts = y - medianSlope * x_ln;
        % 移除NaN值
        intercepts_valid = intercepts(~isnan(intercepts));
        if ~isempty(intercepts_valid)
            medianIntercept = median(intercepts_valid);
            
            xFit = linspace(min(x_ln), max(x_ln), 100);
            yFit = medianSlope * xFit + medianIntercept;
            plot(xFit, yFit, '-r', 'LineWidth', 2);
        end
    end
    
    % 计算当前频率值（假设频率从100MHz开始，间隔100MHz）
    current_freq = (freq_idx - 1) * 20 + 100;  % 100, 200, ..., 1100 MHz
    
    % 图形设置
    xlabel('ln(ε_r)');  % 介电常数的自然对数
    ylabel(sprintf('S{(1,1)} (dB)'));  % S11幅度（dB）
    title(sprintf('Theil-Sen Regression at f = %d MHz', current_freq));
    grid on;
    hold off;
    
    % 保存图形
    % 确保 output 文件夹存在
    if ~exist('output', 'dir')
        mkdir('output');
    end
    
    % 生成文件名（包含频率信息）
    filename_str = fullfile('output', ...
        sprintf('TheilSen_Regression_f%dMHz_%s.png', current_freq, S_param_name));
    
    % 设置图形大小并保存
    %set(gcf, 'Units', 'normalized', 'Position', [0.1 0.1 0.6 0.6]);  % 适当大小的窗口
    drawnow;
    saveas(gcf, filename_str);
    
    fprintf('已保存: %s\n', filename_str);
    
    % 可选：关闭当前图形以释放内存（如果需要）
    % close(gcf);
end

fprintf('所有频率点的Theil-Sen回归图已生成完毕！\n');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 第一处修改：归一化MCS图像
figure;
valid_idx = ~isnan(slopes);
if any(valid_idx)
    % 获取有效数据
    slopes_abs = abs(slopes(valid_idx));
    f_valid = f(valid_idx);
    
    % 0-1归一化处理
    if max(slopes_abs) - min(slopes_abs) > 0
        slopes_normalized = (slopes_abs - min(slopes_abs)) / (max(slopes_abs) - min(slopes_abs));
    else
        % 所有值相同的情况
        slopes_normalized = zeros(size(slopes_abs));
    end
    
    % 绘制归一化后的MCS图像
    plot(f_valid, slopes_normalized, '-r', 'LineWidth', 1.5);
    xlabel('Freq(f)/GHz');
    ylabel('Normalized MCS');
    title(sprintf('Normalized MCS vs Frequency of Blood ball in Brain@%s', S_param_name));
    grid on;
    
    % 添加原始值范围标注
    text(0.02, 0.98, sprintf('Original range: [%.4f, %.4f]', min(slopes_abs), max(slopes_abs)), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'BackgroundColor', 'white', 'EdgeColor', 'black');
    
    % 保存到 output 文件夹
    filename_str1 = fullfile('output', ...
        sprintf('Blood_ball_in_Brain_%s_Normalized_MCS_vs_f.jpg', S_param_name));
    saveas(gcf, filename_str1);
    fprintf('归一化MCS图形已保存为: %s\n', filename_str1);
    
    % 输出归一化统计信息
    fprintf('MCS归一化统计信息:\n');
    fprintf('  原始最小值: %.6f\n', min(slopes_abs));
    fprintf('  原始最大值: %.6f\n', max(slopes_abs));
    fprintf('  归一化后最小值: %.6f\n', min(slopes_normalized));
    fprintf('  归一化后最大值: %.6f\n', max(slopes_normalized));
else
    fprintf('没有有效的斜率数据可用于归一化MCS绘图\n');
end

%% 第二处修改：归一化MAD图像
figure;
valid_idx = ~isnan(mads);
if any(valid_idx)
    % 获取有效数据
    mads_valid = mads(valid_idx);
    f_valid = f(valid_idx);
    
    % 0-1归一化处理
    if max(mads_valid) - min(mads_valid) > 0
        mads_normalized = (mads_valid - min(mads_valid)) / (max(mads_valid) - min(mads_valid));
    else
        % 所有值相同的情况
        mads_normalized = zeros(size(mads_valid));
    end
    
    % 绘制归一化后的MAD图像
    plot(f_valid, mads_normalized, '-r', 'LineWidth', 1.5);
    xlabel('Freq(f)/GHz');
    ylabel('Normalized MAD');
    title(sprintf('Normalized MAD vs Frequency of Blood ball in Brain@%s', S_param_name));
    grid on;
    
    % 添加原始值范围标注
    text(0.02, 0.98, sprintf('Original range: [%.4f, %.4f]', min(mads_valid), max(mads_valid)), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'BackgroundColor', 'white', 'EdgeColor', 'black');
    
    % 保存到 output 文件夹
    filename_str2 = fullfile('output', ...
        sprintf('Blood_ball_in_Brain_%s_Normalized_MAD_vs_f.jpg', S_param_name));
    saveas(gcf, filename_str2);
    fprintf('归一化MAD图形已保存为: %s\n', filename_str2);
    
    % 输出归一化统计信息
    fprintf('MAD归一化统计信息:\n');
    fprintf('  原始最小值: %.6f\n', min(mads_valid));
    fprintf('  原始最大值: %.6f\n', max(mads_valid));
    fprintf('  归一化后最小值: %.6f\n', min(mads_normalized));
    fprintf('  归一化后最大值: %.6f\n', max(mads_normalized));
else
    fprintf('没有有效的MAD数据可用于归一化绘图\n');
end

% 绘制MAD/MCS与频率的关系（保持原样，不归一化）
figure;
valid_idx = ~isnan(mads_mcss);
plot(f(valid_idx), mads_mcss(valid_idx), '-r');
xlabel('Freq(f)/GHz');
ylabel('MAD/MCS');
title(sprintf('MAD/MCS vs Frequency of Blood ball in Brain@%s',S_param_name));
grid on;
% 保存MAD/MCS图
filename_mad_mcs = fullfile('output', ...
    sprintf('Blood_ball_in_Brain_%s_MAD_MCS_vs_f.jpg', S_param_name));
saveas(gcf, filename_mad_mcs);
fprintf('MAD/MCS图形已保存为: %s\n', filename_mad_mcs);

%% 第三处修改：归一化RIH图像
figure;
valid_idx = ~isnan(mads_mcss) & (mads_mcss > 0);
if any(valid_idx)
    % 计算RIH = log10(MAD/MCS)
    rih_values = log10(mads_mcss(valid_idx));
    f_valid = f(valid_idx);
    
    % 0-1归一化处理
    if max(rih_values) - min(rih_values) > 0
        rih_normalized = (rih_values - min(rih_values)) / (max(rih_values) - min(rih_values));
    else
        % 所有值相同的情况
        rih_normalized = zeros(size(rih_values));
    end
    
    % 绘制归一化后的RIH图像
    plot(f_valid, rih_normalized, '-r', 'LineWidth', 1.5);
    xlabel('Freq(f)/GHz');
    ylabel('Normalized RIH');
    title(sprintf('Normalized RIH vs Frequency of Blood ball in Brain@%s', S_param_name));
    grid on;
    
    % 添加原始值范围标注
    text(0.02, 0.98, sprintf('Original range: [%.4f, %.4f]', min(rih_values), max(rih_values)), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'BackgroundColor', 'white', 'EdgeColor', 'black');
    
    % 保存到 output 文件夹
    filename_str3 = fullfile('output', ...
        sprintf('Blood_ball_in_Brain_%s_Normalized_RIH_vs_f.jpg', S_param_name));
    saveas(gcf, filename_str3);
    fprintf('归一化RIH图形已保存为: %s\n', filename_str3);
    
    % 输出归一化统计信息
    fprintf('RIH归一化统计信息:\n');
    fprintf('  原始最小值: %.6f\n', min(rih_values));
    fprintf('  原始最大值: %.6f\n', max(rih_values));
    fprintf('  归一化后最小值: %.6f\n', min(rih_normalized));
    fprintf('  归一化后最大值: %.6f\n', max(rih_normalized));
else
    fprintf('没有有效的MAD/MCS数据进行RIH归一化绘图\n');
end

% 显示每组数据的Theil-Sen估计斜率和MAD
fprintf('\n=== 数据统计 ===\n');
for n = 1:min(10, num_y) % 只显示前10行
    if ~isnan(slopes(n)) && ~isnan(mads(n))
        fprintf('频率: %.3f, MCS: %.6f, MAD: %.6f, MAD/MCS: %.6f\n', ...
            f(n), slopes(n), mads(n), mads_mcss(n));
    else
        fprintf('频率: %.3f, 数据无效\n', f(n));
    end
end

% 显示整体统计
fprintf('\n=== 整体统计 ===\n');
valid_slopes = slopes(~isnan(slopes));
valid_mads = mads(~isnan(mads));
valid_ratios = mads_mcss(~isnan(mads_mcss));

fprintf('有效数据行数: %d/%d\n', length(valid_slopes), num_y);
fprintf('MCS平均值: %.6f, 标准差: %.6f\n', mean(valid_slopes), std(valid_slopes));
fprintf('MAD平均值: %.6f, 标准差: %.6f\n', mean(valid_mads), std(valid_mads));
fprintf('MAD/MCS平均值: %.6f, 标准差: %.6f\n', mean(valid_ratios), std(valid_ratios));

fprintf('\n=== 归一化处理完成 ===\n');
fprintf('已生成 %d 张图像\n', figure_count + 4);