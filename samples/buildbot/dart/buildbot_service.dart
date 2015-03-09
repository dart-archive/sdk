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
  void refresh(PresenterPatchSetBuilder result);

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
      case _REFRESH_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(24);
        PresenterPatchSetBuilder builder = mb.initRoot(new PresenterPatchSetBuilder(), 16);
        _impl.refresh(builder);
        var result = getResultMessage(builder);
        request.setInt64(48, result);
        _postResult.icall$1(request);
        break;
      default:
        throw UnsupportedError();
    }
  }

  const int _TERMINATE_METHOD_ID = 0;
  const int _REFRESH_METHOD_ID = 1;
}

class PresenterPatchSet extends Reader {
  bool get isConsolePatchSet => 1 == this.tag;
  ConsolePatchSet get consolePatchSet => new ConsolePatchSet()
      .._segment = _segment
      .._offset = _offset + 0;
  int get tag => _segment.memory.getUint16(_offset + 8);
}

class PresenterPatchSetBuilder extends Builder {
  ConsolePatchSetBuilder initConsolePatchSet() {
    tag = 1;
    return new ConsolePatchSetBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  void set tag(int value) {
    _segment.memory.setUint16(_offset + 8, value);
  }
}

class ConsoleNodeData extends Reader {
  StrData get title => new StrData()
      .._segment = _segment
      .._offset = _offset + 0;
  StrData get status => new StrData()
      .._segment = _segment
      .._offset = _offset + 8;
  List<CommitNodeData> get commits => readList(new _CommitNodeDataList(), 16);
}

class ConsoleNodeDataBuilder extends Builder {
  StrDataBuilder initTitle() {
    return new StrDataBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  StrDataBuilder initStatus() {
    return new StrDataBuilder()
        .._segment = _segment
        .._offset = _offset + 8;
  }
  List<CommitNodeDataBuilder> initCommits(int length) {
    return NewList(new _CommitNodeDataBuilderList(), 16, length, 24);
  }
}

class CommitNodeData extends Reader {
  StrData get author => new StrData()
      .._segment = _segment
      .._offset = _offset + 0;
  StrData get message => new StrData()
      .._segment = _segment
      .._offset = _offset + 8;
  int get revision => _segment.memory.getInt32(_offset + 16);
}

class CommitNodeDataBuilder extends Builder {
  StrDataBuilder initAuthor() {
    return new StrDataBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  StrDataBuilder initMessage() {
    return new StrDataBuilder()
        .._segment = _segment
        .._offset = _offset + 8;
  }
  void set revision(int value) {
    _segment.memory.setInt32(_offset + 16, value);
  }
}

class ConsolePatchSet extends Reader {
  List<ConsoleNodePatchData> get patches => readList(new _ConsoleNodePatchDataList(), 0);
}

class ConsolePatchSetBuilder extends Builder {
  List<ConsoleNodePatchDataBuilder> initPatches(int length) {
    return NewList(new _ConsoleNodePatchDataBuilderList(), 0, length, 32);
  }
}

class ConsoleNodePatchData extends Reader {
  bool get isReplace => 1 == this.tag;
  ConsoleNodeData get replace => new ConsoleNodeData()
      .._segment = _segment
      .._offset = _offset + 0;
  bool get isTitle => 2 == this.tag;
  StrData get title => new StrData()
      .._segment = _segment
      .._offset = _offset + 0;
  bool get isStatus => 3 == this.tag;
  StrData get status => new StrData()
      .._segment = _segment
      .._offset = _offset + 0;
  bool get isCommits => 4 == this.tag;
  ListCommitNodePatchData get commits => readStruct(new ListCommitNodePatchData(), 0);
  int get tag => _segment.memory.getUint16(_offset + 24);
}

class ConsoleNodePatchDataBuilder extends Builder {
  ConsoleNodeDataBuilder initReplace() {
    tag = 1;
    return new ConsoleNodeDataBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  StrDataBuilder initTitle() {
    tag = 2;
    return new StrDataBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  StrDataBuilder initStatus() {
    tag = 3;
    return new StrDataBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  ListCommitNodePatchDataBuilder initCommits() {
    tag = 4;
    return NewStruct(new ListCommitNodePatchDataBuilder(), 0, 16);
  }
  void set tag(int value) {
    _segment.memory.setUint16(_offset + 24, value);
  }
}

class CommitNodePatchData extends Reader {
  bool get isReplace => 1 == this.tag;
  CommitNodeData get replace => new CommitNodeData()
      .._segment = _segment
      .._offset = _offset + 0;
  bool get isRevision => 2 == this.tag;
  int get revision => _segment.memory.getInt32(_offset + 0);
  bool get isAuthor => 3 == this.tag;
  StrData get author => new StrData()
      .._segment = _segment
      .._offset = _offset + 0;
  bool get isMessage => 4 == this.tag;
  StrData get message => new StrData()
      .._segment = _segment
      .._offset = _offset + 0;
  int get tag => _segment.memory.getUint16(_offset + 20);
}

class CommitNodePatchDataBuilder extends Builder {
  CommitNodeDataBuilder initReplace() {
    tag = 1;
    return new CommitNodeDataBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  void set revision(int value) {
    tag = 2;
    _segment.memory.setInt32(_offset + 0, value);
  }
  StrDataBuilder initAuthor() {
    tag = 3;
    return new StrDataBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  StrDataBuilder initMessage() {
    tag = 4;
    return new StrDataBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  void set tag(int value) {
    _segment.memory.setUint16(_offset + 20, value);
  }
}

class ListCommitNodePatchData extends Reader {
  bool get isReplace => 1 == this.tag;
  List<CommitNodeData> get replace => readList(new _CommitNodeDataList(), 0);
  int get tag => _segment.memory.getUint16(_offset + 8);
}

class ListCommitNodePatchDataBuilder extends Builder {
  List<CommitNodeDataBuilder> initReplace(int length) {
    tag = 1;
    return NewList(new _CommitNodeDataBuilderList(), 0, length, 24);
  }
  void set tag(int value) {
    _segment.memory.setUint16(_offset + 8, value);
  }
}

class StrData extends Reader {
  List<int> get chars => readList(new _uint8List(), 0);
}

class StrDataBuilder extends Builder {
  List<int> initChars(int length) {
    return NewList(new _uint8BuilderList(), 0, length, 1);
  }
}

class _CommitNodeDataList extends ListReader implements List<CommitNodeData> {
  CommitNodeData operator[](int index) => readListElement(new CommitNodeData(), index, 24);
}

class _CommitNodeDataBuilderList extends ListBuilder implements List<CommitNodeDataBuilder> {
  CommitNodeDataBuilder operator[](int index) => readListElement(new CommitNodeDataBuilder(), index, 24);
}

class _ConsoleNodePatchDataList extends ListReader implements List<ConsoleNodePatchData> {
  ConsoleNodePatchData operator[](int index) => readListElement(new ConsoleNodePatchData(), index, 32);
}

class _ConsoleNodePatchDataBuilderList extends ListBuilder implements List<ConsoleNodePatchDataBuilder> {
  ConsoleNodePatchDataBuilder operator[](int index) => readListElement(new ConsoleNodePatchDataBuilder(), index, 32);
}

class _uint8List extends ListReader implements List<uint8> {
  int operator[](int index) => _segment.memory.getUint8(_offset + index * 1);
}

class _uint8BuilderList extends ListBuilder implements List<uint8> {
  int operator[](int index) => _segment.memory.getUint8(_offset + index * 1);
  void operator[]=(int index, int value) => _segment.memory.setUint8(_offset + index * 1, value);
}
