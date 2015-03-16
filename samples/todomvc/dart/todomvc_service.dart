// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

library todomvc_service;

import "dart:ffi";
import "dart:service" as service;
import "struct.dart";

final Channel _channel = new Channel();
final Port _port = new Port(_channel);
final Foreign _postResult = Foreign.lookup("PostResultToService");

bool _terminated = false;
TodoMVCService _impl;

abstract class TodoMVCService {
  void createItem(BoxedString title);
  void deleteItem(int id);
  void completeItem(int id);
  void uncompleteItem(int id);
  void clearItems();
  void sync(PatchSetBuilder result);
  void reset();

  static void initialize(TodoMVCService impl) {
    if (_impl != null) {
      throw new UnsupportedError();
    }
    _impl = impl;
    _terminated = false;
    service.register("TodoMVCService", _port);
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
      case _CREATE_ITEM_METHOD_ID:
        _impl.createItem(getRoot(new BoxedString(), request));
        _postResult.icall$1(request);
        break;
      case _DELETE_ITEM_METHOD_ID:
        _impl.deleteItem(request.getInt32(48));
        _postResult.icall$1(request);
        break;
      case _COMPLETE_ITEM_METHOD_ID:
        _impl.completeItem(request.getInt32(48));
        _postResult.icall$1(request);
        break;
      case _UNCOMPLETE_ITEM_METHOD_ID:
        _impl.uncompleteItem(request.getInt32(48));
        _postResult.icall$1(request);
        break;
      case _CLEAR_ITEMS_METHOD_ID:
        _impl.clearItems();
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
      case _RESET_METHOD_ID:
        _impl.reset();
        _postResult.icall$1(request);
        break;
      default:
        throw UnsupportedError();
    }
  }

  const int _TERMINATE_METHOD_ID = 0;
  const int _CREATE_ITEM_METHOD_ID = 1;
  const int _DELETE_ITEM_METHOD_ID = 2;
  const int _COMPLETE_ITEM_METHOD_ID = 3;
  const int _UNCOMPLETE_ITEM_METHOD_ID = 4;
  const int _CLEAR_ITEMS_METHOD_ID = 5;
  const int _SYNC_METHOD_ID = 6;
  const int _RESET_METHOD_ID = 7;
}

class Node extends Reader {
  bool get isNil => 1 == this.tag;
  bool get isNum => 2 == this.tag;
  int get num => _segment.memory.getInt32(_offset + 0);
  bool get isBool => 3 == this.tag;
  bool get bool => _segment.memory.getUint8(_offset + 0) != 0;
  bool get isStr => 4 == this.tag;
  String get str => readString(new _uint8List(), 0);
  List<int> get strData => readList(new _uint8List(), 0);
  bool get isCons => 5 == this.tag;
  Cons get cons => new Cons()
      .._segment = _segment
      .._offset = _offset + 0;
  int get tag => _segment.memory.getUint16(_offset + 16);
}

class NodeBuilder extends Builder {
  void setNil() {
    tag = 1;
  }
  void set num(int value) {
    tag = 2;
    _segment.memory.setInt32(_offset + 0, value);
  }
  void set bool(bool value) {
    tag = 3;
    _segment.memory.setUint8(_offset + 0, value ? 1 : 0);
  }
  void set str(String value) {
    tag = 4;
    NewString(new _uint8BuilderList(), 0, value);
  }
  ConsBuilder initCons() {
    tag = 5;
    return new ConsBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  void set tag(int value) {
    _segment.memory.setUint16(_offset + 16, value);
  }
}

class Cons extends Reader {
  Node get fst => readStruct(new Node(), 0);
  Node get snd => readStruct(new Node(), 8);
}

class ConsBuilder extends Builder {
  NodeBuilder initFst() {
    return NewStruct(new NodeBuilder(), 0, 24);
  }
  NodeBuilder initSnd() {
    return NewStruct(new NodeBuilder(), 8, 24);
  }
}

class Patch extends Reader {
  Node get content => new Node()
      .._segment = _segment
      .._offset = _offset + 0;
  List<int> get path => readList(new _uint8List(), 24);
}

class PatchBuilder extends Builder {
  NodeBuilder initContent() {
    return new NodeBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  List<int> initPath(int length) {
    return NewList(new _uint8BuilderList(), 24, length, 1);
  }
}

class PatchSet extends Reader {
  List<Patch> get patches => readList(new _PatchList(), 0);
}

class PatchSetBuilder extends Builder {
  List<PatchBuilder> initPatches(int length) {
    return NewList(new _PatchBuilderList(), 0, length, 32);
  }
}

class BoxedString extends Reader {
  String get str => readString(new _uint8List(), 0);
  List<int> get strData => readList(new _uint8List(), 0);
}

class BoxedStringBuilder extends Builder {
  void set str(String value) {
    NewString(new _uint8BuilderList(), 0, value);
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
  Patch operator[](int index) => readListElement(new Patch(), index, 32);
}

class _PatchBuilderList extends ListBuilder implements List<PatchBuilder> {
  PatchBuilder operator[](int index) => readListElement(new PatchBuilder(), index, 32);
}
