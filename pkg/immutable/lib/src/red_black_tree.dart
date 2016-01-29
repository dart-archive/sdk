// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of immutable;

class RedBlackTree {
  final Node root;

  factory RedBlackTree() => new RedBlackTree._(null);

  const RedBlackTree._(this.root);

  lookup(Comparable key) {
    Node current = root;

    while (current != null) {
      int indicator = key.compareTo(current.key);
      if (indicator < 0) {
        current = current.left;
      } else if (indicator > 0) {
        current = current.right;
      } else {
        return current.value;
      }
    }
    return null;
  }

  RedBlackTree insert(Comparable key, value) {
    var newRoot;
    if (root == null) {
      newRoot = new Node(false, null, null, key, value);
    } else {
      newRoot = root.insert(key, value);
      if (newRoot.isRed) {
        newRoot = new Node(
            false, newRoot.left, newRoot.right, newRoot.key, newRoot.value);
      }
    }

    return new RedBlackTree._(newRoot);
  }
}

class Node {
  final bool isRed;
  final Node left;
  final Node right;
  final Comparable key;
  final value;

  const Node(this.isRed, this.left, this.right, this.key, this.value);

  Node _rebalance(Node node) {
    // Here we check for all cases to repair the "black -> red -> red"
    // imbalance.

    var left = node.left;
    var right = node.right;

    bool leftIsRed = left != null && left.isRed;
    bool rightIsRed = right != null && right.isRed;

    if (leftIsRed && rightIsRed) {
      var leftLeft = left.left;
      var leftRight = left.right;
      bool leftLeftIsRed = leftLeft != null && leftLeft.isRed;
      bool leftRightIsRed = leftRight != null && leftRight.isRed;

      var rightLeft = right.left;
      var rightRight = right.right;
      bool rightLeftIsRed = rightLeft != null && rightLeft.isRed;
      bool rightRightIsRed = rightRight != null && rightRight.isRed;

      if (leftLeftIsRed ||
          leftRightIsRed ||
          rightLeftIsRed ||
          rightRightIsRed) {
        left = new Node(false, left.left, left.right, left.key, left.value);
        right =
            new Node(false, right.left, right.right, right.key, right.value);
        return new Node(true, left, right, node.key, node.value);
      } else {
        return node;
      }
    }

    if (leftIsRed) {
      var leftLeft = left.left;
      var leftRight = left.right;
      bool leftLeftIsRed = leftLeft != null && leftLeft.isRed;
      bool leftRightIsRed = leftRight != null && leftRight.isRed;

      if (leftLeftIsRed) {
        var moveToRight =
            new Node(true, leftRight, node.right, node.key, node.value);
        var newRoot =
            new Node(false, leftLeft, moveToRight, left.key, left.value);
        return newRoot;
      }
      if (leftRightIsRed) {
        var moveToRight =
            new Node(true, leftRight.right, node.right, node.key, node.value);
        var newLeft =
            new Node(true, leftLeft, leftRight.left, left.key, left.value);
        var newRoot = new Node(
            false, newLeft, moveToRight, leftRight.key, leftRight.value);
        return newRoot;
      }
    }

    if (rightIsRed) {
      var rightLeft = right.left;
      var rightRight = right.right;
      bool rightLeftIsRed = rightLeft != null && rightLeft.isRed;
      bool rightRightIsRed = rightRight != null && rightRight.isRed;

      if (rightLeftIsRed) {
        var moveToLeft =
            new Node(true, rightLeft.left, node.left, node.key, node.value);
        var newRight =
            new Node(true, rightLeft.right, rightRight, right.key, right.value);
        var newRoot = new Node(
            false, moveToLeft, newRight, rightLeft.key, rightLeft.value);
        return newRoot;
      }
      if (rightRightIsRed) {
        var moveToLeft =
            new Node(true, node.left, rightLeft, node.key, node.value);
        var newRoot =
            new Node(false, moveToLeft, rightRight, right.key, right.value);
        assert(newRoot.left.isRed && newRoot.right.isRed);
        return newRoot;
      }
    }
    return node;
  }

  Node insert(key, value) {
    int indicator = key.compareTo(this.key);

    if (indicator == 0) {
      return new Node(isRed, left, right, key, value);
    } else if (indicator < 0) {
      var newLeft;
      if (left == null) {
        newLeft = new Node(true, null, null, key, value);
      } else {
        newLeft = left.insert(key, value);
      }
      return _rebalance(new Node(isRed, newLeft, right, this.key, this.value));
    } else {
      var newRight;
      if (right == null) {
        newRight = new Node(true, null, null, key, value);
      } else {
        newRight = right.insert(key, value);
      }
      return _rebalance(new Node(isRed, left, newRight, this.key, this.value));
    }
  }
}
