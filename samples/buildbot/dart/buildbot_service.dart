// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

library buildbot_service;

import "dart:ffi";
import "dart:service" as service;
import "struct.dart";

final Channel _channel = new Channel();
final Port _port = new Port(_channel);
final Foreign _postResult = Foreign.lookup("PostResultToService");

bool _terminated = false;
BuildBotService _impl;

abstract class BuildBotService {
  void sync(PatchSetBuilder result);

  static void initialize(BuildBotService impl) {
    if (_impl != null) {
      throw new UnsupportedError();
    }
    _impl = impl;
    _terminated = false;
    service.register("BuildBotService", _port);
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
      case _SYNC_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(16);
        PatchSetBuilder builder = mb.initRoot(new PatchSetBuilder(), 8);
        _impl.sync(builder);
        var result = getResultMessage(builder);
        request.setInt64(48, result);
        _postResult.icall$1(request);
        break;
      default:
        throw UnsupportedError();
    }
  }

  const int _TERMINATE_METHOD_ID = 0;
  const int _SYNC_METHOD_ID = 1;
}

class Node extends Reader {
}

class NodeBuilder extends Builder {
}

class Str extends Reader {
  List<int> get chars => readList(new _uint8List(), 0);
}

class StrBuilder extends Builder {
  List<int> initChars(int length) {
    return NewList(new _uint8BuilderList(), 0, length, 1);
  }
}

class Patch extends Reader {
  List<int> get path => readList(new _uint8List(), 0);
  Node get content => new Node()
      .._segment = _segment
      .._offset = _offset + 8;
}

class PatchBuilder extends Builder {
  List<int> initPath(int length) {
    return NewList(new _uint8BuilderList(), 0, length, 1);
  }
  NodeBuilder initContent() {
    return new NodeBuilder()
        .._segment = _segment
        .._offset = _offset + 8;
  }
}

class PatchSet extends Reader {
  List<Patch> get patches => readList(new _PatchList(), 0);
}

class PatchSetBuilder extends Builder {
  List<PatchBuilder> initPatches(int length) {
    return NewList(new _PatchBuilderList(), 0, length, 8);
  }
}

class _uint8List extends ListReader implements List<uint8> {
  int operator[](int index) => _segment.memory.getUint8(_offset + index * 1);
}

class _uint8BuilderList extends ListBuilder implements List<uint8> {
  int operator[](int index) => _segment.memory.getUint8(_offset + index * 1);
  void operator[]=(int index, int value) => _segment.memory.setUint8(_offset + index * 1, value);
}

class _PatchList extends ListReader implements List<Patch> {
  Patch operator[](int index) => readListElement(new Patch(), index, 8);
}

class _PatchBuilderList extends ListBuilder implements List<PatchBuilder> {
  PatchBuilder operator[](int index) => readListElement(new PatchBuilder(), index, 8);
}
