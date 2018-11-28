classdef CMGrid
% cell mapping grid class
  properties 
    X      % data in grid
    y      % data values in grid
    dim    % data dimension
    lb     % lower bound
    ub     % upper bound
    blocks   % number of blocks per dimension
    pointId  % identifier to apropriate cell
    cellId   % coordinates of cell in grid
    nCells   % number of non-empty cells
    cmCells = CMCell()  % individual CMCells
    opts    = struct()  % grid options structure
  end
  
  methods
    function obj = CMGrid(X, y, varargin)
      % Cell-mapping grid constructor.
      % obj = CMGrid(X, y, lb, ub, blocks, options)
      % 
      % Input:
      %   X       - input data
      %   y       - data values
      %   lb      - lower bound
      %   ub      - upper bound
      %   blocks  - number of blocks per dimension
      %   options - additional grid options | pairs of property (string) 
      %             and value, or struct with properties as fields:
      %     BlockType - type of block boundaries: 
      %                   'uniform'  - boundaries are in uniform distance
      %                   'quantile' - boundaries are calculated according
      %                                to quantiles in each dimension
      %                                separately
      
      obj = obj.emptyCMGrid();
      if nargin < 2
        help CMGrid
        return
      end
      
      nArgs = numel(varargin);
      % parse lower bounds
      if nArgs < 1 || isempty(varargin{1})
        lb = min(X) - eps;
      else
        lb = varargin{1};
      end
      % parse lower bounds
      if nArgs < 2 || isempty(varargin{2})
        ub = max(X) + eps;
      else
        ub = varargin{2};
      end
      % parse blocks
      if nArgs < 3 || isempty(varargin{3})
        blocks = 1;
      else
        blocks = varargin{3};
      end
      % parse grid options
      if nArgs < 4 || isempty(varargin{4})
        obj.opts = struct();
      else
        obj.opts = varargin{4};
      end
      obj.opts = settings2struct(obj.opts);
      obj.opts.blockType = defoptsi(obj.opts, 'blockType', 'uniform');
      
      % in case of empty set return empty grid
      if isempty(X)
        return
      end
      
      % basic values
      obj.X = X;
      obj.y = y;
      [nData, dataDim] = size(X);
      obj.dim = dataDim;

      % checkout blocks settings input
      obj.lb = checkBlockVal(lb, 'lb', dataDim);
      assert(all(obj.lb <= min(X)), 'Some points are out of lower bounds. Check your settings.')
      obj.ub = checkBlockVal(ub, 'ub', dataDim);
      assert(all(obj.ub >= max(X)), 'Some points are out of upper bounds. Check your settings.')
      obj.blocks = checkBlockVal(blocks, 'blocks', dataDim);
      assert(all(obj.blocks > 0 & mod(blocks, 1) == 0), 'Block numbers has to be natural.')

      % init
      maxBlocks = max(obj.blocks);
      blockLB = [lb', NaN(dataDim, maxBlocks - 1)];
      blockUB = [NaN(dataDim, maxBlocks - 1), ub'];
      pointCellId = zeros(nData, dataDim);

      % find cells for each point
      blockSize = (obj.ub-obj.lb) ./ obj.blocks;
      for d = 1 : dataDim
        % block bounds in uniform distance
        if strcmp(obj.opts.blockType, 'uniform')
          % lower bounds
          blockLB(d, 2:obj.blocks(d)) = obj.lb(d) + (1:(obj.blocks(d)-1)) * blockSize(d);
          % upper bounds
          blockUB(d, 1:end-1) = blockLB(d, 1:end-1) + blockSize(d);
        % block bounds in quantile-based distance
        else
          blockSize = quantile(X(:, d), obj.blocks(d) - 1);
          % lower bounds
          blockLB(d, 2:obj.blocks(d)) = blockSize';
          % upper bounds
          blockUB(d, 1:obj.blocks(d)-1) = blockSize';
          blockUB(isnan(blockUB)) = obj.ub(d);
        end
        % for each point find containing cells 
        for i = 1:nData
          pointCellId(i, d) = find(X(i, d) <= blockUB(d, 1:obj.blocks(d)), 1, 'first');
        end
      end
      
      % identify cells and points in them
      [obj.cellId, ~, obj.pointId] = unique(pointCellId, 'rows');
      obj.nCells = size(obj.cellId, 1);
      
      % create cells
      cellLB = NaN(1, dataDim);
      cellUB = NaN(1, dataDim);
      for c = 1:obj.nCells
        % find points related to actual cell
        actualPointId = (c == obj.pointId);
        for d = 1:dataDim
          cellLB(d) = blockLB(d, (obj.cellId(c, d)));
          cellUB(d) = blockUB(d, (obj.cellId(c, d)));
        end
        % not empty cell
        cellX = X(actualPointId, :);
        celly = y(actualPointId);
        obj.cmCells(c, 1) = CMCell(cellX, celly, dataDim, cellLB, cellUB);
      end
      
    end
    
    function [x, y] = getMax(obj)
    % get point with maximal objective value
      [y, id] = max(obj.y);
      x = obj.X(id, :);
    end
    
    function [x, y] = getMin(obj)
    % get point with minimal objective value
      [y, id] = min(obj.y);
      x = obj.X(id, :);
    end
    
    function y_mean = getMean(obj)
    % get mean objective value
      y_mean = mean(obj.y);
    end
     
    function [X, y] = getCellMin(obj)
    % get points with minimal objective values in all non-empty cells
      X = NaN(obj.nCells, obj.dim);
      y = NaN(obj.nCells, 1);
      for c = 1:obj.nCells
        inCell = c == obj.pointId;
        [y(c), id] = min(obj.y(inCell));
        cellX = obj.X(inCell, :);
        X(c, :) = cellX(id, :);
      end
    end
    
    function [X, y] = getCellMax(obj)
    % get points with maximal objective values in all non-empty cells
      X = NaN(obj.nCells, obj.dim);
      y = NaN(obj.nCells, 1);
      for c = 1:obj.nCells
        inCell = c == obj.pointId;
        [y(c), id] = max(obj.y(inCell));
        cellX = obj.X(inCell);
        X(c, :) = cellX(id, :);
      end
    end
    
    function y = getCellMean(obj)
    % get mean objective values in all non-empty cells
      y = NaN(obj.nCells, 1);
      for c = 1:obj.nCells
        y(c) = mean(obj.y(c == obj.pointId));
      end
    end
    
    function d = getDistCtr2Min(obj, distance)
    % get distance from cell center to the point with minimal objective
    % value within the cell in all cells
      if nargin < 2
        distance = 'euclidean';
      end
      d = cell2mat(arrayfun(@(i) obj.cmCells(i).getDistCtr2Min(distance), ...
                                 1:obj.nCells, ...
                                 'UniformOutput', false))';
    end
    
    function d = getDistCtr2Max(obj, distance)
    % get distance from cell center to the point with maximal objective
    % value within the cell in all cells
      if nargin < 2
        distance = 'euclidean';
      end
      d = cell2mat(arrayfun(@(i) obj.cmCells(i).getDistCtr2Max(distance), ...
                                 1:obj.nCells, ...
                                 'UniformOutput', false))';
    end
    
    function ang = getMaxMinAngle(obj)
    % In all cells:
    % Get angle between the point with maximal objective value, the cell 
    % center, and the point with minimal objective value within the cell.
      ang = cell2mat(arrayfun(@(i) obj.cmCells(i).getMaxMinAngle, ...
                                   1:obj.nCells, ...
                                   'UniformOutput', false))';
    end
    
    function df = getMaxMinDiff(obj)
    % get difference between the points with minimal and maximal objective 
    % values in all cells
      df = cell2mat(arrayfun(@(i) obj.cmCells(i).getMaxMinDiff, ...
                                  1:obj.nCells, ...
                                  'UniformOutput', false))';
    end
    
    function gradHomo = getGradHomogeneity(obj, cl_distance, dist_param)
    % get gradient homogeneity of all cells containing 3 or more points
      if nargin < 3
        if nargin < 2
          cl_distance = 'euclidean';
        end
        dist_param = defMetricParam(cl_distance, obj.X);
      end
      gradHomo = cell2mat(arrayfun(@(i) ...
          obj.cmCells(i).getGradHomogeneity(cl_distance, dist_param), ...
          1:obj.nCells, 'UniformOutput', false))';
    end
    
    function [X, y] = getNearCtrPoint(obj, cl_distance, dist_param)
    % get point nearest to the cell center in all non-empty cells
      if nargin < 3
        if nargin < 2
          cl_distance = 'euclidean';
        end
        dist_param = defMetricParam(cl_distance, obj.X);
      end
      
      X = NaN(obj.nCells, obj.dim);
      y = NaN(obj.nCells, 1);
      for i = 1:obj.nCells
        [X(i, :), y(i)] = obj.cmCells(i).getNearCtrPoint(cl_distance, dist_param);
      end
    end
    
    function y = getNearCtrGridPointY(obj, cl_distance, dist_param)
    % get point nearest to the cell center from the whole grid
    % Be careful, this method has great memory requirements.
      if nargin < 3
        if nargin < 2
          cl_distance = 'euclidean';
        end
        dist_param = defMetricParam(cl_distance, obj.X);
      end
      
      % calculate cell boulds
      maxBlocks = max(obj.blocks);
      blockLB = NaN(maxBlocks, obj.dim);
      blockUB = NaN(maxBlocks, obj.dim);
      blockSize = (obj.ub-obj.lb) ./ obj.blocks;
      for d = 1 : obj.dim
        % lower bounds
        blockLB(1:obj.blocks(d), d) = obj.lb(d) + (0:(obj.blocks(d)-1)) * blockSize(d);
        % upper bounds
        blockUB(:, d) = blockLB(:, d) + blockSize(d);
      end
      
      sumCells = prod(obj.blocks);
      y = NaN(obj.blocks);
      % in case of empty grid return NaN
      if isempty(obj)
        return
      end
      % run loop accross all cells (even empty ones)
      for i = 1 : sumCells
        cellCoordinates = ind2coor(i, obj.blocks);
        % get cell center
        cellCenter = (blockLB(cellCoordinates) + blockUB(cellCoordinates)) / 2;
        % minkowski and mahalanobis settings
        if any(strcmp(cl_distance, {'minkowski', 'mahalanobis'})) && nargin == 3
          [~, id] = pdist2(obj.X, cellCenter, cl_distance, dist_param, 'Smallest', 1);
        % other distances
        else
          [~, id] = pdist2(obj.X, cellCenter, cl_distance, 'Smallest', 1);
        end
        y(i) = obj.y(id);
      end
      
    end
    
    function res = isCellEmpty(obj, testedId)
    % return if cell with given coordinates is empty
      res = any(all(repmat(testedId, obj.nCells, 1) == obj.cellId, 2));
    end
    
    function lm = fitPolyModel(obj, modelspec)
    % fit polynomial model in each cell
      lm = {};
      if nargin < 2
        modelspec = 'linear';
      end
      for c = 1:obj.nCells
        lm{c} = obj.cmCells(c).fitPolyModel(modelspec);
      end
    end
    
    function obj = emptyCMGrid(obj)
    % return empty grid
      obj.X = [];
      obj.y = [];
      obj.dim = [];
      obj.lb = [];
      obj.ub = [];
      obj.blocks = [];
      obj.pointId = [];
      obj.cellId = [];
      obj.nCells = [];
      obj.cmCells = CMCell();
      obj.opts = struct();
    end
    
    function state = isempty(obj)
    % CMGrid is empty when it does not contain any data
      state = isempty(obj.X);
    end
    
  end
  
end

function val = checkBlockVal(val, name, dim)
% check value of block setting
  if numel(val) == 1
    val = ones(1, dim) * val;
  elseif numel(val) ~= dim
    error('%s length differs from dimension', name)
  end
end