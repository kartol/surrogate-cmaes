function getDataMetaFeatures(folder, varargin)
%GETDATAMETAFEATURES Calculates metafeatures on large set of data.
% getDataMetaFeatures(folder) calculates metafeatures on all data files in
% folder generated using modelTestSet function.
%
% getDataMetaFeatures(file) calculates metafeatures in file generated using
% modelTestSets function.
%
% getDataMetaFeatures(dataset) calculates metafeatures directly on dataset
% generated using modelTestSets.
%
% getDataMetaFeatures(..., settings) calculates metafeatures using
% additional settings.
%
% Input:
%   [...]    - data input folder, file, or structure generated using
%              modelTestSets function | string or struct
%   settings - pairs of property (string) and value, or struct with 
%              properties as fields:
%     'Design'    - sampling design of source data (use only if data was 
%                   generated by using one) | {'lhs', 'ilhs', 'lhsnorm'}
%     'Dim'       - dimension number of data (used only when first input is
%                   a structure) | integer
%     'Features'  - list of features to be calculated | cell-array of
%                   string
%     'Fun'       - function id of data (used only when first input is
%                   a structure) | integer
%     'Inst'      - instance id of data (used only when first input is
%                   a structure) | integer
%     'MetaInput' - input sets for metafeature calculation | {'archive',
%                   'test', 'train', 'traintest'}
%     'MixTrans'  - results of different transformation settings for one
%                   input set are returned in one structure | boolean
%                 - previously calculated results are replaced by new ones
%                 - this can cause the number of resulting fields will be
%                   lower than the number of elements in values vector
%     'Output'    - output folder | string
%     'Rewrite'   - rewrite already computed results | boolean | false
%     'TrainOpts' - training set options | structure with fields 
%                   evoControlTrainNArchivePoints, evoControlTrainRange,
%                   trainRange, trainsetSizeMax, and trainSetType
%     'TransData' - transformation of data | {'none', 'cma'}
%                     'none' - raw data X are used for calculation
%                     'cma'  - X_t = ( (sigma * BD) \ X')';
%                 - should have the same lenght as 'MetaInput'
%     'UseFeat'   - feature ids from 'Features' to be used for specific
%                   input set | cell-array of boolean or double
%                 - should have the same lenght as 'MetaInput' (one vector
%                   for one input), 'true' can be used for calculation of
%                   all metafeatures
%     'Warnings'  - show metafeature warnings during computation | boolean
%                   | true
%
% See Also:
%   getMetaFeatures, testModels, modelTestSets

  if nargin < 1
    help getDataMetaFeatures
    return
  end
  
  listFeatures = {'basic', ...
              'cm_angle', ...
              'cm_convexity', ...
              'cm_gradhomo', ...
              'cmaes', ...
              'dispersion', ...
              'ela_distribution', ...
              'ela_levelset', ...
              'ela_metamodel', ...
              'gcm', ...
              'infocontent', ...
              'linear_model', ...
              'nearest_better', ...
              'pca' ...
             };
  
  % parse settings
  settings = settings2struct(varargin{:});
  design = defoptsi(settings, 'Design', '');
  % parse options
  settings.lb = defopts(settings, 'lb', '-5*ones(1, dim)');
  settings.ub = defopts(settings, 'ub', ' 5*ones(1, dim)');
  settings = defoptsiStr(settings, 'Dim', [], 'dim');
  settings = defoptsiStr(settings, 'Features', listFeatures, 'features');
  settings = defoptsiStr(settings, 'Fun', [], 'fun');
  settings = defoptsiStr(settings, 'Id', [], 'id');
  settings = defoptsiStr(settings, 'Inst', [], 'inst');
  settings = defoptsiStr(settings, 'MetaInput', {'archive'}, 'metaInput');
  settings = defoptsiStr(settings, 'MixTrans', false, 'mixTrans');
  settings = defoptsiStr(settings, 'UseFeat', [], 'useFeat');
  settings = defoptsiStr(settings, 'Rewrite', false, 'rewrite');
  settings = defoptsiStr(settings, 'TrainOpts', struct(), 'trainOpts');
  settings = defoptsiStr(settings, 'TransData', {'none'}, 'transform');
  if ~iscell(settings.transform)
    settings.transform = {settings.transform};
  end
  % not enough transformation settings -> fill with no transformation
  if numel(settings.metaInput) > numel(settings.transform)
    settings.transform(end+1 : numel(settings.metaInput)) = {'none'};
  end
  settings = defoptsiStr(settings, 'Warnings', true, 'warnings');
  
  % direct calculation of data -> input is structure
  if isstruct(folder)
    fun = settings.fun;
    dim = settings.dim;
    inst = settings.inst;
    id = settings.id;
    fileString = sprintf('data_f%s_%sD_i%s_id%s_fts.mat', ...
                   prtShortInt(fun), prtShortInt(dim), ...
                   prtShortInt(inst), prtShortInt(id));
    outputFile = defoptsi(settings, 'Output', fileString);
    if settings.rewrite || ~isfile(outputFile) 
      res = getSingleDataMF(folder, settings);
    end
    % save results
    save(outputFile, 'res', 'fun', 'dim', 'inst')
    return
  end
    
  % data may be divided between multiple folders
  if (~iscell(folder))
    folder = {folder};
  end
  
  % get data according to design
  if isempty(design)
    settings = defoptsiStr(settings, 'Output', [], 'output');
    getRegularDataMetaFeatures(folder, settings);
  else
    getDesignedDataMetaFeatures(folder, design);
  end
  
end

function getRegularDataMetaFeatures(folder, settings)
% get metafeatures from data in folder without specified generation design

  % gather all MAT-files
  datalist = {};
  for f = 1:length(folder)
    if isdir(folder{f})
      actualDataList = searchFile(folder{f}, '*.mat');
    elseif isfile(folder{f}) && strcmp(folder{f}(end-3:end), '.mat') 
      actualDataList = folder(f);
    else
      warning('%s is not a directory or MAT-file', folder{f})
      actualDataList = {};
    end
    if numel(actualDataList) > 0
      datalist(end+1 : end+length(actualDataList)) = actualDataList;
    end
  end
  
  % return if no data to calculates
  if isempty(datalist)
    warning('No data to calculate in input folders. Ending getDataMetaFeatures.')
    return
  end

  % create feature folder
  outputFolder = defoptsi(settings, 'Output', 'default_folder');
  if strcmp(outputFolder, 'default_folder') || isempty(outputFolder)
    % TODO: adaptively create folders according to the original file
    % structure
    for fol = 1:numel(folder)
      if isdir(folder{1})
        outputFolder = [folder{1}, '_fts'];
      elseif isfile(folder{1})
        [datapath, dataname] = fileparts(folder{1});
        outputFolder = fullfile(datapath, [dataname, '_fts']);
      % error if no input folder is a really a file or folder
      elseif fol == numel(folder)
        error('No input folder is actually file or folder')
      end
    end
  end
  [~, ~] = mkdir(outputFolder);
  
  % list through all data
  for dat = 1:length(datalist)
    % load data
    fprintf('Loading %s\n', datalist{dat})
    warning('off', 'MATLAB:load:variableNotFound')
    data = load(datalist{dat}, '-mat', 'ds', 'fun', 'dim', 'inst');
    warning('on', 'MATLAB:load:variableNotFound')
    if all(isfield(data, {'ds', 'fun', 'dim', 'inst'}))
      
      % get dataset size (function * dimension * instances * models)
      [nFun, nDim, nInst, nId] = size(data.ds);
      
      % important information about the dataset to be saved in resulting
      % file
      fun = data.fun;
      dim = data.dim;
      inst = data.inst;
      modId = 1:nId;
      % check input information to be calculated
      calcFun = checkCalcVal(fun, settings.fun, 'Function');
      calcDim = checkCalcVal(dim, settings.dim, 'Dimension');
      calcInst = checkCalcVal(inst, settings.inst, 'Instance');
      calcId = checkCalcVal(modId, settings.id, 'Model id');
      % save data
      [~, filename] = fileparts(datalist{dat});
      % TODO: check uniqueness of output filenames
      outputFile = fullfile(outputFolder, [filename, '_fts.mat']);
      % try to load result file
      if isfile(outputFile)
        fprintf('Loading output file %s\n', outputFile)
        out = load(outputFile, 'res');
        res = out.res;
        % clear due to memory requirements
        clear out
      else
        res = cell(nFun, nDim, nInst, nId);
      end
      
      % function loop
      for f = 1:numel(calcFun)
        % dimension loop
        for d = 1:numel(calcDim)
          % instance loop
          for im = 1:numel(calcInst)
            % model loop
            for id = 1:numel(calcId)
              % get original ids
              fId = ismember(fun, calcFun(f));
              dId = ismember(dim, calcDim(d));
              imId = ismember(inst, calcInst(im));
              mId = ismember(modId, calcId(id));
              % print calculation status
              countState = sprintf('f%d, %dD, inst %d, id %d', ...
                                   calcFun(f), calcDim(d), ...
                                   calcInst(im), calcId(id));
              lState = numel(countState);
              fprintf('%s\n', req(84 + lState))
              fprintf('%s  %s  %s\n', ...
                      req(40), countState, req(40));
              fprintf('%s\n', req(84 + lState))
              % empty output or always rewriting option causes metafeature
              % calculation
              if ~isempty(data.ds{fId, dId, imId, mId}) && ...
                 (isempty(res{fId, dId, imId, mId}) || settings.rewrite)
                % metafeature calculation for different generations
                res{fId, dId, imId, mId} = getSingleDataMF(data.ds{fId, dId, imId, mId}, settings);
                % save results
                save(outputFile, 'res', 'fun', 'dim', 'inst')
              % skip calculation due to missing data
              elseif isempty(data.ds{fId, dId, imId, mId})
                fprintf('Data is missing in %s\n', datalist{dat})
              % skip already calculated
              else
                fprintf('Already saved in %s\n', outputFile)
              end
            end
          end
        end
      end
      
    else
      fprintf('Variable ''ds'', ''fun'', ''dim'', or ''inst'' not found in %s.\n', datalist{dat})
    end
    
  end

end

function res = getSingleDataMF(ds, opts)
% calculate metafeatures in different generations
  
  % parse settings
  normalizeY = defopts(opts.trainOpts, 'normalizeY', false);

  nFeat  = numel(opts.features);
  nInput = numel(opts.metaInput);

  % get generations
  generations = ds.generations;
  nGen = numel(generations);
  
  % prepare result variable
  res.ft(1:nGen) = struct();
  res.values = [];
  
  useFeat = cell(1, nInput);
  % feature settings for individual input sets
  if isempty(opts.useFeat) || (islogical(opts.useFeat) && opts.useFeat)
    useFeat(1:nInput) = {true(1, nFeat)};
  else
    for iSet = 1:nInput
      % can be set using one logical value
      if islogical(opts.useFeat{iSet}) && numel(opts.useFeat{iSet}) == 1
        useFeat{iSet}(1:nInput) = ~opts.useFeat{iSet};
      else
        useFeat{iSet} = opts.useFeat{iSet};
      end
    end
  end
  
  % generation loop
  for g = 1:nGen
    fprintf('%s  Generation %d (%d/%d) %s\n', ...
            req(40), generations(g), g, nGen, req(40))
    % CMA-ES feature settings
    if any(strcmp(opts.features, 'cmaes'))
      opts.cmaes.cma_cov = ds.BDs{g}*ds.BDs{g}';
      opts.cmaes.cma_evopath_c = ds.pcs{g};
      opts.cmaes.cma_evopath_s = ds.pss{g};
      opts.cmaes.cma_generation = generations(g);
      opts.cmaes.cma_mean = ds.means{g};
      % irun is the number of runs => #restarts = irun - 1
      opts.cmaes.cma_restart = ds.iruns(g) - 1;
      opts.cmaes.cma_step_size = ds.sigmas{g};
    end
    
    % meta input set loop
    for iSet = 1:nInput
      mtInput = lower(opts.metaInput{iSet});
      
      % get correct input
      switch mtInput
        case 'archive'
          X = ds.archive.X(ds.archive.gens < generations(g), :);
          y = ds.archive.y(ds.archive.gens < generations(g), :);
        case 'test'
          X = ds.testSetX{g};
          y = NaN(size(X, 1), 1);
        case 'train'
          dsTrain = createTrainDS(ds, generations, g);
          [X, y] = getTrainData(dsTrain, g, opts.trainOpts);
        case {'testtrain', 'traintest'}
          dsTrain = createTrainDS(ds, generations, g);
          [X, y] = getTrainData(dsTrain, g, opts.trainOpts);
          X = [X; ds.testSetX{g}];
          y = [y; NaN(size(ds.testSetX{g}, 1), 1)];
        otherwise
          error('%s is not correct input set name (see help getDataMetafeatures)', ...
                mtInput)
      end
      % transform input space data
      if strcmpi(opts.transform{iSet}, 'cma') && ~isempty(X)
        X = ( (ds.sigmas{g} * ds.BDs{g}) \ X')';
      end
      % transform output space data
      if normalizeY
        y = (y - nanmean(y)) / nanstd(y);
      end
      
      % create metafeature options without additional settings
      optsMF = safermfield(opts, {'dim', 'fun', 'inst', ...
                              'metaInput', 'mixTrans', 'output', ...
                              'rewrite', ...
                              'transform', 'useFeat', 'warnings'...
                             });
      % omit selected features
      optsMF.features = optsMF.features(useFeat{iSet});
      
      % suppress warnings
      if ~opts.warnings
        % empty cells in cell-mapping
        warning('off', 'mfts:emptyCells')
        % division by NaNs and zeros
        warning('off', 'MATLAB:rankDeficientMatrix')
        % division by NaN and zero matrices
        warning('off', 'MATLAB:illConditionedMatrix')
        % regression design matrix is rank deficient to within machine 
        % precision in linear model
        warning('off', 'stats:LinearModel:RankDefDesignMat')
      end
      
      % calculate metafeatures
      [res_fts, values{iSet}] = getMetaFeatures(X, y, optsMF);
      
      % result structure mixing
      if opts.mixTrans
        % check if input set was used before
        if isfield(res.ft(g), mtInput)
          res.ft(g).(mtInput) = catstruct(res.ft(g).(mtInput), res_fts);
        else
          res.ft(g).(mtInput) = res_fts;
        end
      % create unique fieldnames
      else
        res.ft(g).([mtInput, '_', lower(opts.transform{iSet})]) = res_fts;
      end
      
      % enable warnings
      if ~opts.warnings
        warning('on', 'mfts:emptyCells')
        warning('on', 'MATLAB:rankDeficientMatrix')
        warning('on', 'MATLAB:illConditionedMatrix')
        warning('on', 'stats:LinearModel:RankDefDesignMat')
      end
    end
    res.values(:, g) = cell2mat(values');
  end
      
end

function ds = createTrainDS(ds, generations, g)
% create training ds

  % get training archive
  trainArchive = Archive(ds.archive.dim, ds.archive.tolX);
  trainArchive.X = ds.archive.X(ds.archive.gens < generations(g), :);
  trainArchive.y = ds.archive.y(ds.archive.gens < generations(g), :);
  trainArchive.gens = ds.archive.gens(ds.archive.gens < generations(g));
  % create training dataset
  ds.archive = trainArchive;
end

function [X, y] = getTrainData(ds, g, opts)
% get training data for model (derived from DoublyTrainedEC, Model,
% Archive, and Population)
%
% Input:
%   ds   - dataset
%   g    - generation
%   opts - options with following fields:
%
%     evoControlTrainNArchivePoints - number of archive points to be used
%                                     for model training at maximum
%     evoControlTrainRange - range of training set (test set independent)
%                          - used only iff trainSetType == 'parameter'
%     trainRange           - range of training set (test set dependent)
%                          - used only when trainSetType ~= 'parameter'
%     trainsetSizeMax      - maximal size of training set
%     trainSetType         - type of training set | 
%                            {'allpoints', 'clustering', 'nearest', 
%                            'nearesttopopulation', 'parameter', 'recent'}

  % parse options
  opts.evoControlTrainNArchivePoints = ...
    defopts(opts, 'evoControlTrainNArchivePoints', '15*dim');
  opts.evoControlTrainRange = defopts(opts, 'evoControlTrainRange', 10);
  opts.trainRange = defopts(opts, 'trainRange', 1);
  opts.trainsetSizeMax = defopts(opts, 'trainsetSizeMax', '15*dim');
  opts.trainsetType = defopts(opts, 'trainsetType', 'parameters');
 
  % cmaes state variables
  xmean = ds.means{g};
  sigma = ds.sigmas{g};
  BD = ds.BDs{g};
  % dimension can be used in myeval function
  dim = ds.dim;
  
  % population should be object of class Population but structure should be
  % sufficient for getting training data
  population.x = ds.testSetX{g}';
  
  nArchivePoints = myeval(opts.evoControlTrainNArchivePoints);
  if strcmp(opts.trainsetType, 'parameters')
    [X, y] = ds.archive.getDataNearPoint(nArchivePoints, ...
             xmean, opts.evoControlTrainRange, ...
             sigma, BD);
  else
    [X, y] = ds.archive.getTrainsetData(opts.trainsetType,...
             myeval(opts.trainsetSizeMax), xmean, opts.trainRange,...
             sigma, BD, population);
  end
end
  
function getDesignedDataMetaFeatures(folder, design)
% get metafeatures from data in folder generated through specified design

  funIds = 1:24;
  dims = [2, 5, 10];
  instIds = [1:5 41:50];
  Ns = {'50 * dim'};
%   design = {'lhs'};

%   exppath = fullfile('exp', 'experiments');
%   input_path = fullfile(exppath, 'data_metalearn');
  input_path = folder;
  in_fname_template = strjoin({'data_metalearn_', ...
    '%dD_', ...
    'f%d_', ...
    'inst%d_', ...
    'N%d_', ...
    'design-%s.mat'}, '');

  output_path = [folder, '_fts'];
  [~, ~] = mkdir(output_path);
  out_fname_template = 'metafeatures_N-%s_design-%s.mat';

  t0 = tic;
  for N_cell = Ns
    for design_cell = design
      des = design_cell{:};
      % 3d cell for results; N and design type will be distinguished by file name
      mfts = cell(max(dims), max(funIds), max(instIds));

      for dim = dims
        for funId = funIds
          for instId = instIds
            % debug
            fprintf('%dD, f%d, inst%d ...\n', dim, funId, instId);

            % load input data
            N = myeval(N_cell{:});
            in_fname = sprintf(in_fname_template, dim, funId, instId, N, des);
            in_fname = fullfile(input_path, sprintf('%dD', dim), in_fname);
            data = load(in_fname);

            % compute metafeatures
            opts.lb = -5 * ones(1, dim);
            opts.ub = 5 * ones(1, dim);
            opts.features = {'basic', 'cm_angle', 'cm_convexity', ...
                     'cm_gradhomo', 'dispersion', 'ela_distribution', ...
                     'ela_levelset', 'ela_metamodel', 'infocontent', ...
                     'nearest_better', 'pca'};
            [res.ft, res.values] = getMetaFeatures(data.X', data.Y', opts);
            mfts{dim, funId, instId} = res;

            % debug
            fprintf('Elapsed time: %.2f sec.\n', (tic - t0) / 1e6);
          end
        end
      end % dim loop

      % save results
      Nstr = strrep(N_cell{:}, ' * ', '');
      out_fname = sprintf(out_fname_template, Nstr, des);
      out_fname = fullfile(output_path, out_fname);
      save(out_fname, 'funIds', 'dims', 'instIds', 'Ns', 'design', 'mfts');
    end
  end
  
end

function res = req(num)
% row equation symbol
  res = sprintf('%s', ones(1, num)*double('='));
end

function str = prtShortInt(vec)
% print short version of sorted integer vector able to be in file name

  nVec = numel(vec);
  % convert to integer
  vec = int16(vec);
  % sort
  vec = sort(vec);
  % count difference of sorted vector
  vec_diff = diff(vec);

  % first vector element
  if nVec > 0
    str = sprintf('%d', vec(1));
    % cycle and print values
    for i = 2 : nVec
      if vec_diff(i-1) > 1
        str = sprintf('%s~%d', str, vec(i));
      elseif (vec_diff(i-1) == 1) && (i == nVec || vec_diff(i) > 1)
        str = sprintf('%s-%d', str, vec(i));
      end
    end
  else
    str = '';
  end
end

function S = defoptsiStr(S, oldfield, defValue, newfield)
% defoptsi returning whole structure where old field is checked for value
% and replaced by newfields with specified value
  
  if nargin > 3
    newValue = defoptsi(S, oldfield, defValue);
    S = safermfield(S, oldfield);
    S.(newfield) = newValue;
  % default defoptsi
  else
    S.(oldfield) = defoptsi(S, oldfield, defValue);
  end
end

function val = checkCalcVal(dataVal, settingsVal, valName)
% check value to be calculated

  if isempty(settingsVal)
    val = dataVal;
    return
  end
  % check input information to be calculated
  val = dataVal(ismember(dataVal, settingsVal));
  if any(~ismember(settingsVal, val))
    warning('%s %d is not in the dataset', valName, ...
      settingsVal(~ismember(settingsVal, val)))
  end
  
end