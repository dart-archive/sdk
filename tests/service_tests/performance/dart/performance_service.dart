// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

library performance_service;

import "dart:ffi";
import "dart:service" as service;
import "struct.dart";

final Channel _channel = new Channel();
final Port _port = new Port(_channel);
final Foreign _postResult = Foreign.lookup("PostResultToService");

bool _terminated = false;
PerformanceService _impl;

abstract class PerformanceService {
  int echo(int n);
  int countTreeNodes(TreeNode node);
  void buildTree(int n, TreeNodeBuilder result);

  static void initialize(PerformanceService impl) {
    if (_impl != null) {
      throw new UnsupportedError();
    }
    _impl = impl;
    _terminated = false;
    service.register("PerformanceService", _port);
  }

  static bool hasNextEvent() {
    return !_terminated;
  }

  static void handleNextEvent() {
    var request = _channel.receive();
    switch (request.getInt32(0)) {
      case _TERMINATE_METHOD_ID:
        _terminated = true;
        _postResult.icall$1(request);
        break;
      case _ECHO_METHOD_ID:
        var result = _impl.echo(request.getInt32(40));
        request.setInt32(40, result);
        _postResult.icall$1(request);
        break;
      case _COUNT_TREE_NODES_METHOD_ID:
        var result = _impl.countTreeNodes(getRoot(new TreeNode(), request));
        request.setInt32(40, result);
        _postResult.icall$1(request);
        break;
      case _BUILD_TREE_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(16);
        TreeNodeBuilder builder = mb.initRoot(new TreeNodeBuilder(), 8);
        _impl.buildTree(request.getInt32(40), builder);
        var result = getResultMessage(builder);
        request.setInt64(40, result);
        _postResult.icall$1(request);
        break;
      default:
        throw UnsupportedError();
    }
  }

  const int _TERMINATE_METHOD_ID = 0;
  const int _ECHO_METHOD_ID = 1;
  const int _COUNT_TREE_NODES_METHOD_ID = 2;
  const int _BUILD_TREE_METHOD_ID = 3;
}

class TreeNode extends Reader {
  List<TreeNode> get children => readList(new _TreeNodeList(), 0);
}

class TreeNodeBuilder extends Builder {
  List<TreeNodeBuilder> initChildren(int length) {
    return NewList(new _TreeNodeBuilderList(), 0, length, 8);
  }
}

class _TreeNodeList extends ListReader implements List<TreeNode> {
  TreeNode operator[](int index) => readListElement(new TreeNode(), index, 8);
}

class _TreeNodeBuilderList extends ListBuilder implements List<TreeNodeBuilder> {
  TreeNodeBuilder operator[](int index) => readListElement(new TreeNodeBuilder(), index, 8);
}
