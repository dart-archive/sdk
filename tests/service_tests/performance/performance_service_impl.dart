// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart/performance_service.dart';

class PerformanceServiceImpl implements PerformanceService {
  int echo(int n) => n;

  int countTreeNodes(TreeNode node) {
    int sum = 1;
    List<TreeNode> children = node.children;
    for (int i = 0; i < children.length; i++) {
      sum += countTreeNodes(children[i]);
    }
    return sum;
  }

  void buildTree(int n, TreeNodeBuilder node) {
    if (n > 1) {
      List<TreeNodeBuilder> children = node.initChildren(2);
      buildTree(n - 1, children[0]);
      buildTree(n - 1, children[1]);
    }
  }
}

main() {
  var impl = new PerformanceServiceImpl();
  PerformanceService.initialize(impl);
  while (PerformanceService.hasNextEvent()) {
    PerformanceService.handleNextEvent();
  }
}
