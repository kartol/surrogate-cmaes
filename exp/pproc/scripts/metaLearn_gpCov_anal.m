% GP covariance metalearning analysis script

%% load data

expfolder = fullfile('exp', 'experiments');
expname = fullfile(expfolder, 'exp_metaLearn_05');
mtfsfile = fullfile(expfolder, 'data_metalearn_fts', 'metafeatures_N-50dim_design-ilhs.mat');

% load model results
[res, settings, params] = metaLearn_loadResults(expname, ...
  'IgnoreSettings', {'rf_nTrees', 'rf_nFeaturesToSample', 'rf_inBagFraction'}, ...
  'ShowOutput', false);

%% select apropriate settings

% find gp settings
isGP = cellfun(@(x) strcmp(x.modelType, 'gp'), settings);
% extract only gp results and settings
% isChosenSet = true(1, numel(settings)); 
isChosenSet = isGP;
chosen_res = res(:, :, isChosenSet);
chosen_settings = settings(isChosenSet);

% load metafeatures
S = load(mtfsfile);
mfts = cellfun(@(x) x.values, S.mfts(S.dims, S.funIds, S.instIds), 'UniformOutput', false);
mfts(:, :, S.instIds) = mfts;

%% anal tables

% error tables for analysis
% 91 mfts ~ 1 error result (for 3 types of error)

[nFunc, nDim, nSettings] = size(chosen_res);

% result id structure
rId.function  = [];
rId.dimension = [];
rId.setting   = [];
rId.instance  = [];
% all data init
all_mfts = [];
all_mse  = [];
all_mae  = [];
all_r2   = [];
for s = 1:nSettings
  % initialize struct fields
  resStruct(s).mfts = [];
  resStruct(s).mse = [];
  resStruct(s).mae = [];
  resStruct(s).r2 = [];
  for f = 1:nFunc % [1:11, 13:nFunc]
    for d = 1:nDim
      if ~isempty(chosen_res{f, d, s})
        actInst = [chosen_res{f, d, s}.inst];
        nActInst = numel(actInst);
        % result structure
        resStruct(s).mse(end+1 : end+nActInst, 1) = [chosen_res{f, d, s}.mse];
        resStruct(s).mae(end+1 : end+nActInst, 1) = [chosen_res{f, d, s}.mae];
        resStruct(s).r2(end+1 : end+nActInst, 1)  = [chosen_res{f, d, s}.r2];
        resStruct(s).mfts(end+1 : end+nActInst, :) = [mfts{d, f, actInst}]';
        % result id structure
        rId.function(end+1 : end+nActInst, 1) = params.functions(f)*ones(nActInst, 1);
        rId.dimension(end+1 : end+nActInst, 1) = params.dimensions(d)*ones(nActInst, 1);
        rId.setting(end+1 : end+nActInst, 1) = s*ones(nActInst, 1);
        rId.instance(end+1 : end+nActInst, 1) = actInst;
      end
    end
  end
  all_mfts = [all_mfts; resStruct(s).mfts];
  all_mse  = [all_mse;  resStruct(s).mse];
  all_mae  = [all_mae;  resStruct(s).mae];
  all_r2   = [all_r2;   resStruct(s).r2];
end

mftsList = strsplit(printStructure(S.mfts{2,1,1}.ft, 'Format', 'field'));
mftsList = mftsList(1:3:end-1);
for m = 1:numel(mftsList)
  fprintf('%s\n', mftsList{m})
end

%% PCA

% remove NaN and Inf rows
nanInfId = find(any(isinf(all_mfts) | isnan(all_mfts), 2));
all_mfts(nanInfId, :) = [];
all_mae(nanInfId) = [];
all_mse(nanInfId) = [];
all_r2(nanInfId) = [];
rId.function(nanInfId) = [];
rId.dimension(nanInfId) = [];
rId.setting(nanInfId) = [];
rId.instance(nanInfId) = [];

% remove constant features (columns)
constId = var(all_mfts) == 0;
all_mfts(:, constId) = [];
rem_mfts = mftsList(constId);
if any(constId)
  fprintf('Removing constant metafeatures:\n')
end
for m = 1:numel(rem_mfts)
  fprintf('%s\n', rem_mfts{m})
end
mftsList(constId) = [];
% remove linearly dependent features (columns)
[all_mfts, independentId] = licols(all_mfts, eps);
dependentId = ~ismember(1:length(mftsList), independentId);
rem_mfts = mftsList(dependentId);
if any(dependentId)
  fprintf('Removing linearly dependent metafeatures:\n')
end
for m = 1:numel(rem_mfts)
  fprintf('%s\n', rem_mfts{m})
end
mftsList(dependentId) = [];
% remove features dependent on y-values shift
 yShiftFeat = {};
% yShiftFeat = {'basic.objective_min', 'basic.objective_max', ...
%               'ela_metamodel.lin_simple_intercept'};
%               'ela_metamodel.lin_simple_coef_max', ...
%               'ela_metamodel.lin_simple_coef_min', ...
for m = 1:numel(yShiftFeat)
  yShiftId = strcmp(mftsList, yShiftFeat{m});
  all_mfts(:, yShiftId) = [];  
  if any(yShiftId)
    fprintf('Removing %s dependent on y-values shift\n', yShiftFeat{m})
  end
  mftsList(yShiftId) = [];
end

[nObs, nFeat] = size(all_mfts);

% normalize metafeatures (due to objective max - huge variance)
% TODO: Can we do this?
mean_mfts = mean(all_mfts);
var_mfts = var(all_mfts);
norm_mfts = (all_mfts - repmat(mean_mfts, nObs, 1)) ./ repmat(var_mfts, nObs, 1);
% norm_mfts = all_mfts;
var_norm_mfts = var(norm_mfts);

% calculate variance
var_norm_mfts_norm = var_norm_mfts/sum(var_norm_mfts);
[~, varId] = sort(var_norm_mfts_norm, 'descend');

% find how many metafeatures explain defined level of variance
var_level = 0.9;
var_exp = find(cumsum(var_norm_mfts_norm(varId)) > var_level, 1, 'first');

% PCA
[pca_coeff, pca_mfts, ~, ~, explained] = pca(norm_mfts);
fprintf('%0.2f%% explained by first two components\n', explained(1) + explained(2))
% PCA - level based
% norm_mfts = norm_mfts(:, varId(1:var_exp));
% mftsList = mftsList(varId(1:var_exp));
% nFeat = numel(mftsList);
% [pca_coeff, pca_mfts, ~, ~, explained] = pca(norm_mfts);
% fprintf('%0.2f%% explained by first two components\n', explained(1) + explained(2))

% calculate decomposition of components
pca_comp_norm_1 = abs(pca_coeff(:, 1))/sum(abs(pca_coeff(:, 1)));
[~, pca_compId1] = sort(pca_comp_norm_1, 'descend');

pca_comp_norm_2 = abs(pca_coeff(:, 2))/sum(abs(pca_coeff(:, 2)));
[~, pca_compId2] = sort(pca_comp_norm_2, 'descend');

isOverOnePerc = pca_comp_norm_1 > 0.01;
fprintf('\n%40s: %30s (%0.2f%% explained): %30s (%0.2f%% explained): \n\n', ...
        'Variance', ...
        'First component', explained(1), ...
        'Second component', explained(2))
% list decomposition
for m = 1:nFeat
  fprintf('%40s  %6.2f  %40s  %6.2f  %40s  %6.2f\n', ...
          mftsList{varId(m)}, 100*var_norm_mfts_norm(varId(m)), ...
          mftsList{pca_compId1(m)}, 100*pca_comp_norm_1(pca_compId1(m)), ...
          mftsList{pca_compId2(m)}, 100*pca_comp_norm_2(pca_compId2(m)))
end
% list decomposition - level based
% for m = 1:nFeat
%   fprintf('%40s  %6.2f  %40s  %6.2f  %40s  %6.2f\n', ...
%           mftsList{m}, 100*var_norm_mfts_norm(m), ...
%           mftsList{pca_compId1(m)}, 100*pca_comp_norm_1(pca_compId1(m)), ...
%           mftsList{pca_compId2(m)}, 100*pca_comp_norm_2(pca_compId2(m)))
% end

%% visualisation

% if exist('isoutlier') == 5
%   useDataId = ~isoutlier(all_r2, 'median');
% else
  useDataId = true(size(all_r2));
% end

% selectedDataId = useDataId;
% footprintPlot(pca_mfts(useDataId, :), pca_mfts(selectedDataId, :), all_r2(selectedDataId), ...
%     'Title', sprintf('%dD', params.dimensions(d)), ...
%     'ValueName', 'R^2', ...
%     'Statistic', @max);

%% Dimension plots

close all

% dimension visualisation
% fprintf('Dimension plots\n')
for d = 1:nDim
  selectedDataId = (rId.dimension == params.dimensions(d));
%   footprintPlot(pca_mfts(useDataId, :), pca_mfts(selectedDataId, :), all_mae(selectedDataId), ...
%     'Title', sprintf('%dD', params.dimensions(d)), ...
%     'ValueName', 'MAE');
%   footprintPlot(pca_mfts(useDataId, :), pca_mfts(selectedDataId, :), all_mse(selectedDataId), ...
%     'Title', sprintf('%dD', params.dimensions(d)), ...
%     'ValueName', 'MSE');
  footprintPlot(pca_mfts(useDataId, :), pca_mfts(selectedDataId, :), all_r2(selectedDataId), ...
    'Title', sprintf('%dD', params.dimensions(d)), ...
    'ValueName', 'R^2');
end

%% Function plots

close all

% function visualisation
% fprintf('Function plots\n')
for f = 1:nFunc
  selectedDataId = (rId.function == params.functions(f));
%   footprintPlot(pca_mfts(useDataId, :), pca_mfts(selectedDataId, :), all_mae(selectedDataId), ...
%     'Title', sprintf('f%d', params.functions(f)), ...
%     'ValueName', 'MAE');
%   footprintPlot(pca_mfts(useDataId, :), pca_mfts(selectedDataId, :), all_mse(selectedDataId), ...
%     'Title', sprintf('f%d', params.functions(f)), ...
%     'ValueName', 'MSE');
  footprintPlot(pca_mfts(useDataId, :), pca_mfts(selectedDataId, :), all_r2(selectedDataId), ...
    'Title', sprintf('f%d', params.functions(f)), ...
    'ValueName', 'R^2');
end

%% Settings plots

close all

% settings visualisation
% fprintf('Settings plots\n')
for s = 1:nSettings
%   selectedDataId = (rId.setting == s);
%   footprintPlot(pca_mfts(useDataId, :), pca_mfts(selectedDataId, :), all_mae(selectedDataId), ...
%     'Title', sprintf('%s', chosen_settings{s}.hypOptions.covFcn), ...
%     'ValueName', 'MAE');
%   footprintPlot(pca_mfts(useDataId, :), pca_mfts(selectedDataId, :), all_mse(selectedDataId), ...
%     'Title', sprintf('%s', chosen_settings{s}.hypOptions.covFcn), ...
%     'ValueName', 'MSE');
  for d = 1:nDim
    selectedDataId = (rId.setting == s) & (rId.dimension == params.dimensions(d));
    switch chosen_settings{s}.modelType
      case 'gp'
        plotTitle = sprintf('%s %dD', chosen_settings{s}.hypOptions.covFcn, params.dimensions(d));
      case 'forest'
        splitType = func2str(chosen_settings{s}.tree_splitFunc);
        splitGainType = func2str(chosen_settings{s}.tree_splitGainFunc);
        plotTitle = sprintf('bag - %s, %s %dD', ...
          splitType(1:end-5), ...
          splitGainType(1:end-9), ...
          params.dimensions(d));
      case 'xgb'
        splitType = func2str(chosen_settings{s}.tree_splitFunc);
        plotTitle = sprintf('xgb - %s %dD', ...
          splitType(1:end-5), ...
          params.dimensions(d));
      otherwise
        plotTitle = sprintf('Settings %d, ', s);
    end
    footprintPlot(pca_mfts(useDataId, :), pca_mfts(selectedDataId, :), all_r2(selectedDataId), ...
      'Title', plotTitle, ...
      'ValueName', 'R^2');
  end
end

%% final part
close all