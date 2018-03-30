function tests = cellMappingTest
% unit test for cell mapping functions
  tests = functiontests(localfunctions);
end

function testCMGrid(testCase)
  % testing cell mapping grid object
  
  % empty input
  cmg = CMGrid();
  verifyInstanceOf(testCase, cmg, 'CMGrid')
  fnGrid = fieldnames(cmg);
  for f = 1:numel(fnGrid)
    verifyEmpty(testCase, cmg.(fnGrid{f}))
  end
  
  % random input
  dim = 3;
  nData = 50*dim;
  X = rand(nData, dim);
  y = randn(nData, 1);
  lb = zeros(1, dim);
  ub = ones(1, dim);
  blocks = [4, 4, 3*ones(1, dim-2)];
  cmg = CMGrid(X, y, lb, ub, blocks);
  nCells = cmg.nCells;
  % function verification
  verifyNotEmpty(testCase, cmg.getMin)
  verifyNotEmpty(testCase, cmg.getMax)
  verifyNotEmpty(testCase, cmg.getMean)
  verifySize(testCase, cmg.getCellMin, [nCells, dim])
  verifySize(testCase, cmg.getCellMax, [nCells, dim])
  verifySize(testCase, cmg.getCellMean, [nCells, 1])
  verifySize(testCase, cmg.getDistCtr2Min, [nCells, 1])
  verifySize(testCase, cmg.getDistCtr2Max, [nCells, 1])
  verifySize(testCase, cmg.getMaxMinAngle, [nCells, 1])
  verifySize(testCase, cmg.getMaxMinDiff, [nCells, 1])
  verifySize(testCase, cmg.getNearCtrPoint, [nCells, dim])
  % in sparse data the gradient homogeneity can be even empty (3 points per
  % cell needed)
  cmg.getGradHomogeneity();
  verifySize(testCase, cmg.isCellEmpty(ones(1, dim)), [1, 1])
end

function testCMCell(testCase)
% testing cell mapping objects

  % empty input
  cm = CMCell();
  verifyInstanceOf(testCase, cm, 'CMCell')
  verifyEmpty(testCase, cm.getMin)
  verifyEmpty(testCase, cm.getMax)
  verifyEmpty(testCase, cm.getDistCtr2Min)
  verifyEmpty(testCase, cm.getDistCtr2Max)
  verifyEmpty(testCase, cm.getMaxMinAngle)
  verifyEmpty(testCase, cm.getMaxMinDiff)
  verifyEmpty(testCase, cm.getNearCtrPoint)
  verifyEmpty(testCase, cm.getGradHomogeneity)
  
  % random input without settings
  dim = 3;
  X = rand(30, dim);
  y = rand(30, 1);
  cm = CMCell(X, y, dim, 0, 1);
  cmFields = {'X', 'y', 'dim', 'lb', 'ub', 'center', 'minx', 'miny', ...
              'maxx', 'maxy'};
  for f = 1:numel(cmFields)
    verifyNotEmpty(testCase, cm.(cmFields{f}))
  end
  
  % random input with settings
  lb = [-1, 0, min(X(:, 3))];
  ub = [max(X(:, 1)), 1, 0];
  cm = CMCell(X, y, dim, lb, ub);
  for f = 1:numel(cmFields)
    verifyNotEmpty(testCase, cm.(cmFields{f}))
  end
  verifyNotEmpty(testCase, cm.getMin)
  verifyNotEmpty(testCase, cm.getMax)
  verifyNotEmpty(testCase, cm.getDistCtr2Min)
  verifyNotEmpty(testCase, cm.getDistCtr2Max)
  verifyNotEmpty(testCase, cm.getMaxMinAngle)
  verifyNotEmpty(testCase, cm.getMaxMinDiff)
  verifyNotEmpty(testCase, cm.getNearCtrPoint)
  verifyNotEmpty(testCase, cm.getGradHomogeneity)
end

function testCreateCMGrid(testCase)
% testing creating cell mapping grid

  % empty input should not generate error
  verifyNotEmpty(testCase, createCMGrid());
  
  % random input without settings
  dim = 50;
  nData = 50*dim;
  X = rand(nData, dim);
  y = rand(nData, 1);
%   [cmg, cmId, cmEmpty] = createCMGrid(X, y);
%   verifyEqual(testCase, size(cmg), [1, 1])
%   verifyEqual(testCase, cmId, ones(dim, 1))
%   verifyEqual(testCase, cmEmpty, false)
  
  % random input with settings
  lb = zeros(1, dim);
  ub = ones(1, dim);
  blocks =  3*ones(1, dim);
  [cmg, cmId, cmEmpty] = createCMGrid(X, y, lb, ub, blocks);
%   verifyEqual(testCase, size(cmg), [1, prod(blocks)])
%   verifyEqual(testCase, size(cmId), [dim, prod(blocks)])
%   verifyEqual(testCase, size(cmEmpty), [1, prod(blocks)])
end