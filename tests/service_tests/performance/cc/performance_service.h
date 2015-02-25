// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#ifndef PERFORMANCE_SERVICE_H
#define PERFORMANCE_SERVICE_H

#include <inttypes.h>
#include "struct.h"

class TreeNode;
class TreeNodeBuilder;

class PerformanceService {
 public:
  static void setup();
  static void tearDown();
  static int32_t echo(int32_t n);
  static void echoAsync(int32_t n, void (*callback)(int32_t));
  static int32_t countTreeNodes(TreeNodeBuilder node);
  static TreeNode buildTree(int32_t n);
  static void buildTreeAsync(int32_t n, void (*callback)(TreeNode));
};

class TreeNode : public Reader {
 public:
  static const int kSize = 8;
  TreeNode(Segment* segment, int offset)
      : Reader(segment, offset) { }

  List<TreeNode> getChildren() const { return ReadList<TreeNode>(0); }
};

class TreeNodeBuilder : public Builder {
 public:
  static const int kSize = 8;

  explicit TreeNodeBuilder(const Builder& builder)
      : Builder(builder) { }
  TreeNodeBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  List<TreeNodeBuilder> initChildren(int length);
};

#endif  // PERFORMANCE_SERVICE_H
