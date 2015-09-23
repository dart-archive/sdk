// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'node.dart' show
    Node;

class NodeStack {
  List<Node> data = <Node>[];

  int get size => data.length;

  // Stack interface.
  void pushNode(Node node) {
    data.add(node);
  }

  Node popNode() {
    return data.removeLast();
  }

  /// Returns the top of the stack or [null] if the stack is empty.
  Node topNode() {
    return data.isNotEmpty ? data.last : null;
  }
}

class Popper<T extends Node> {
  NodeStack stack;
  Popper(this.stack);

  T popNodeIfMatching() {
    return (stack.topNode() is T) ? stack.popNode() : null;
  }

  List<T> popNodesWhileMatching() {
    List<T> result = <T>[];
    while (stack.topNode() is T) {
      result.add(stack.popNode());
    }
    return result;
  }

  List<T> popNodes(int count) {
    List<T> result = new List<T>(count);
    assert(count <= stack.data.length);
    int oldLength = stack.data.length;
    int newLength = oldLength - count;
    for (int i = newLength; i < oldLength; ++i) {
      result[i - newLength] = stack.data[i];
    }
    stack.data.length = newLength;
    return result;
  }
}
