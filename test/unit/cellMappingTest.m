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
  dim = 20;
  nData = 50*dim;
  X = rand(nData, dim);
  y = randn(nData, 1);
  lb = zeros(1, dim);
  ub = ones(1, dim);
  blocks = [4, 4, 3*ones(1, dim-2)];
  cmg = CMGrid(X, y, lb, ub, blocks);
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
  X = rand(30, 3);
  y = rand(30, 1);
  cm = CMCell(X, y);
  cmFields = {'X', 'y', 'dim', 'lb', 'ub', 'center', 'minx', 'miny', ...
              'maxx', 'maxy'};
  for f = 1:numel(cmFields)
    verifyNotEmpty(testCase, cm.(cmFields{f}))
  end
  
  % random input with settings
  settings.lb = [-1, 0, min(X(:, 3))];
  settings.ub = [max(X(:, 1)), 1, 0];
  cm = CMCell(X, y, settings);
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
end