// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:immi/dart/immi.dart';

// Export generated code for nodes in drawer.immi
import 'package:immi/dart/drawer.dart';
export 'package:immi/dart/drawer.dart';

class Drawer {
  var left;
  var _center;
  var right;

  bool _leftVisible = false;
  bool _rightVisible = false;

  Drawer(this._center, {left, right}) {
    this.left = left;
    this.right = right;
  }

  get center => _center;

  set center(presenter) {
    _center = presenter;
    _leftVisible = false;
    _rightVisible = false;
  }

  DrawerNode present(Node previous) {
    Node previousLeft = new EmptyPaneNode();
    Node previousCenter = null;
    Node previousRight = new EmptyPaneNode();
    if (previous is DrawerNode) {
      previousLeft = previous.left;
      previousCenter = previous.center;
      previousRight = previous.right;
    }
    return new DrawerNode(
        left: _presentPane(left, _leftVisible, previousLeft, 'left'),
        center: center.present(previousCenter),
        right: _presentPane(right, _rightVisible, previousRight, 'right'),
        leftVisible: _leftVisible,
        rightVisible: _rightVisible,
        toggleLeft: _toggleLeft,
        toggleRight: _toggleRight);
  }

  Node _presentPane(presenter, bool visible, Node previous, String pane) {
    if (presenter == null) return new EmptyPaneNode();
    if (!visible) return previous;
    return presenter.present(previous);
  }

  void _toggleLeft() {
    _leftVisible = !_leftVisible;
    if (_leftVisible && _rightVisible) _rightVisible = false;
  }

  void _toggleRight() {
    _rightVisible = !_rightVisible;
    if (_leftVisible && _rightVisible) _leftVisible = false;
  }
}
