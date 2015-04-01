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
  void refresh(BuildBotPatchDataBuilder result);
  void setConsoleCount(int count);
  void setConsoleMinimumIndex(int index);
  void setConsoleMaximumIndex(int index);

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
        MessageBuilder mb = new MessageBuilder(40);
        BuildBotPatchDataBuilder builder = mb.initRoot(new BuildBotPatchDataBuilder(), 32);
        _impl.refresh(builder);
        var result = getResultMessage(builder);
        request.setInt64(48, result);
        _postResult.icall$1(request);
        break;
      case _SET_CONSOLE_COUNT_METHOD_ID:
        _impl.setConsoleCount(request.getInt32(48));
        _postResult.icall$1(request);
        break;
      case _SET_CONSOLE_MINIMUM_INDEX_METHOD_ID:
        _impl.setConsoleMinimumIndex(request.getInt32(48));
        _postResult.icall$1(request);
        break;
      case _SET_CONSOLE_MAXIMUM_INDEX_METHOD_ID:
        _impl.setConsoleMaximumIndex(request.getInt32(48));
        _postResult.icall$1(request);
        break;
      default:
        throw UnsupportedError();
    }
  }

  const int _TERMINATE_METHOD_ID = 0;
  const int _REFRESH_METHOD_ID = 1;
  const int _SET_CONSOLE_COUNT_METHOD_ID = 2;
  const int _SET_CONSOLE_MINIMUM_INDEX_METHOD_ID = 3;
  const int _SET_CONSOLE_MAXIMUM_INDEX_METHOD_ID = 4;
}

class ConsoleNodeData extends Reader {
  String get title => readString(new _uint16List(), 0);
  List<int> get titleData => readList(new _uint16List(), 0);
  String get status => readString(new _uint16List(), 8);
  List<int> get statusData => readList(new _uint16List(), 8);
  List<CommitNodeData> get commits => readList(new _CommitNodeDataList(), 16);
  int get commitsOffset => _segment.memory.getInt32(_offset + 24);
}

class ConsoleNodeDataBuilder extends Builder {
  void set title(String value) {

    NewString(new _uint16BuilderList(), 0, value);
  }
  List<int> initTitleData(int length) {

    return NewList(new _uint16BuilderList(), 0, length, 2);
  }
  void set status(String value) {

    NewString(new _uint16BuilderList(), 8, value);
  }
  List<int> initStatusData(int length) {

    return NewList(new _uint16BuilderList(), 8, length, 2);
  }
  List<CommitNodeDataBuilder> initCommits(int length) {
    return NewList(new _CommitNodeDataBuilderList(), 16, length, 24);
  }
  void set commitsOffset(int value) {
    _segment.memory.setInt32(_offset + 24, value);
  }
}

class CommitNodeData extends Reader {
  String get author => readString(new _uint16List(), 0);
  List<int> get authorData => readList(new _uint16List(), 0);
  String get message => readString(new _uint16List(), 8);
  List<int> get messageData => readList(new _uint16List(), 8);
  int get revision => _segment.memory.getInt32(_offset + 16);
}

class CommitNodeDataBuilder extends Builder {
  void set author(String value) {

    NewString(new _uint16BuilderList(), 0, value);
  }
  List<int> initAuthorData(int length) {

    return NewList(new _uint16BuilderList(), 0, length, 2);
  }
  void set message(String value) {

    NewString(new _uint16BuilderList(), 8, value);
  }
  List<int> initMessageData(int length) {

    return NewList(new _uint16BuilderList(), 8, length, 2);
  }
  void set revision(int value) {
    _segment.memory.setInt32(_offset + 16, value);
  }
}

class BuildBotPatchData extends Reader {
  bool get isNoPatch => 1 == this.tag;
  bool get isConsolePatch => 2 == this.tag;
  ConsolePatchData get consolePatch => new ConsolePatchData()
      .._segment = _segment
      .._offset = _offset + 0;
  int get tag => _segment.memory.getUint16(_offset + 30);
}

class BuildBotPatchDataBuilder extends Builder {
  void setNoPatch() {
    tag = 1;
  }
  ConsolePatchDataBuilder initConsolePatch() {
    tag = 2;
    return new ConsolePatchDataBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  void set tag(int value) {
    _segment.memory.setUint16(_offset + 30, value);
  }
}

class ConsolePatchData extends Reader {
  bool get isReplace => 1 == this.tag;
  ConsoleNodeData get replace => new ConsoleNodeData()
      .._segment = _segment
      .._offset = _offset + 0;
  bool get isUpdates => 2 == this.tag;
  List<ConsoleUpdatePatchData> get updates => readList(new _ConsoleUpdatePatchDataList(), 0);
  int get tag => _segment.memory.getUint16(_offset + 28);
}

class ConsolePatchDataBuilder extends Builder {
  ConsoleNodeDataBuilder initReplace() {
    tag = 1;
    return new ConsoleNodeDataBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  List<ConsoleUpdatePatchDataBuilder> initUpdates(int length) {
    tag = 2;
    return NewList(new _ConsoleUpdatePatchDataBuilderList(), 0, length, 16);
  }
  void set tag(int value) {
    _segment.memory.setUint16(_offset + 28, value);
  }
}

class ConsoleUpdatePatchData extends Reader {
  bool get isTitle => 1 == this.tag;
  String get title => readString(new _uint16List(), 0);
  List<int> get titleData => readList(new _uint16List(), 0);
  bool get isStatus => 2 == this.tag;
  String get status => readString(new _uint16List(), 0);
  List<int> get statusData => readList(new _uint16List(), 0);
  bool get isCommitsOffset => 3 == this.tag;
  int get commitsOffset => _segment.memory.getInt32(_offset + 0);
  bool get isCommits => 4 == this.tag;
  CommitListPatchData get commits => new CommitListPatchData()
      .._segment = _segment
      .._offset = _offset + 0;
  int get tag => _segment.memory.getUint16(_offset + 8);
}

class ConsoleUpdatePatchDataBuilder extends Builder {
  void set title(String value) {
    tag = 1;

    NewString(new _uint16BuilderList(), 0, value);
  }
  List<int> initTitleData(int length) {
    tag = 1;

    return NewList(new _uint16BuilderList(), 0, length, 2);
  }
  void set status(String value) {
    tag = 2;

    NewString(new _uint16BuilderList(), 0, value);
  }
  List<int> initStatusData(int length) {
    tag = 2;

    return NewList(new _uint16BuilderList(), 0, length, 2);
  }
  void set commitsOffset(int value) {
    tag = 3;
    _segment.memory.setInt32(_offset + 0, value);
  }
  CommitListPatchDataBuilder initCommits() {
    tag = 4;
    return new CommitListPatchDataBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  void set tag(int value) {
    _segment.memory.setUint16(_offset + 8, value);
  }
}

class CommitPatchData extends Reader {
  bool get isReplace => 1 == this.tag;
  CommitNodeData get replace => new CommitNodeData()
      .._segment = _segment
      .._offset = _offset + 0;
  bool get isUpdates => 2 == this.tag;
  List<CommitUpdatePatchData> get updates => readList(new _CommitUpdatePatchDataList(), 0);
  int get tag => _segment.memory.getUint16(_offset + 20);
}

class CommitPatchDataBuilder extends Builder {
  CommitNodeDataBuilder initReplace() {
    tag = 1;
    return new CommitNodeDataBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  List<CommitUpdatePatchDataBuilder> initUpdates(int length) {
    tag = 2;
    return NewList(new _CommitUpdatePatchDataBuilderList(), 0, length, 16);
  }
  void set tag(int value) {
    _segment.memory.setUint16(_offset + 20, value);
  }
}

class CommitUpdatePatchData extends Reader {
  bool get isRevision => 1 == this.tag;
  int get revision => _segment.memory.getInt32(_offset + 0);
  bool get isAuthor => 2 == this.tag;
  String get author => readString(new _uint16List(), 0);
  List<int> get authorData => readList(new _uint16List(), 0);
  bool get isMessage => 3 == this.tag;
  String get message => readString(new _uint16List(), 0);
  List<int> get messageData => readList(new _uint16List(), 0);
  int get tag => _segment.memory.getUint16(_offset + 8);
}

class CommitUpdatePatchDataBuilder extends Builder {
  void set revision(int value) {
    tag = 1;
    _segment.memory.setInt32(_offset + 0, value);
  }
  void set author(String value) {
    tag = 2;

    NewString(new _uint16BuilderList(), 0, value);
  }
  List<int> initAuthorData(int length) {
    tag = 2;

    return NewList(new _uint16BuilderList(), 0, length, 2);
  }
  void set message(String value) {
    tag = 3;

    NewString(new _uint16BuilderList(), 0, value);
  }
  List<int> initMessageData(int length) {
    tag = 3;

    return NewList(new _uint16BuilderList(), 0, length, 2);
  }
  void set tag(int value) {
    _segment.memory.setUint16(_offset + 8, value);
  }
}

class CommitListPatchData extends Reader {
  List<CommitListUpdatePatchData> get updates => readList(new _CommitListUpdatePatchDataList(), 0);
}

class CommitListPatchDataBuilder extends Builder {
  List<CommitListUpdatePatchDataBuilder> initUpdates(int length) {
    return NewList(new _CommitListUpdatePatchDataBuilderList(), 0, length, 16);
  }
}

class CommitListUpdatePatchData extends Reader {
  bool get isInsert => 1 == this.tag;
  List<CommitNodeData> get insert => readList(new _CommitNodeDataList(), 0);
  bool get isPatch => 2 == this.tag;
  List<CommitPatchData> get patch => readList(new _CommitPatchDataList(), 0);
  bool get isRemove => 3 == this.tag;
  int get remove => _segment.memory.getUint32(_offset + 0);
  int get index => _segment.memory.getUint32(_offset + 8);
  int get tag => _segment.memory.getUint16(_offset + 12);
}

class CommitListUpdatePatchDataBuilder extends Builder {
  List<CommitNodeDataBuilder> initInsert(int length) {
    tag = 1;
    return NewList(new _CommitNodeDataBuilderList(), 0, length, 24);
  }
  List<CommitPatchDataBuilder> initPatch(int length) {
    tag = 2;
    return NewList(new _CommitPatchDataBuilderList(), 0, length, 24);
  }
  void set remove(int value) {
    tag = 3;
    _segment.memory.setUint32(_offset + 0, value);
  }
  void set index(int value) {
    _segment.memory.setUint32(_offset + 8, value);
  }
  void set tag(int value) {
    _segment.memory.setUint16(_offset + 12, value);
  }
}

class _uint16List extends ListReader implements List<uint16> {
  int operator[](int index) => _segment.memory.getUint16(_offset + index * 2);
}

class _uint16BuilderList extends ListBuilder implements List<uint16> {
  int operator[](int index) => _segment.memory.getUint16(_offset + index * 2);
  void operator[]=(int index, int value) => _segment.memory.setUint16(_offset + index * 2, value);
}

class _CommitNodeDataList extends ListReader implements List<CommitNodeData> {
  CommitNodeData operator[](int index) => readListElement(new CommitNodeData(), index, 24);
}

class _CommitNodeDataBuilderList extends ListBuilder implements List<CommitNodeDataBuilder> {
  CommitNodeDataBuilder operator[](int index) => readListElement(new CommitNodeDataBuilder(), index, 24);
}

class _ConsoleUpdatePatchDataList extends ListReader implements List<ConsoleUpdatePatchData> {
  ConsoleUpdatePatchData operator[](int index) => readListElement(new ConsoleUpdatePatchData(), index, 16);
}

class _ConsoleUpdatePatchDataBuilderList extends ListBuilder implements List<ConsoleUpdatePatchDataBuilder> {
  ConsoleUpdatePatchDataBuilder operator[](int index) => readListElement(new ConsoleUpdatePatchDataBuilder(), index, 16);
}

class _CommitUpdatePatchDataList extends ListReader implements List<CommitUpdatePatchData> {
  CommitUpdatePatchData operator[](int index) => readListElement(new CommitUpdatePatchData(), index, 16);
}

class _CommitUpdatePatchDataBuilderList extends ListBuilder implements List<CommitUpdatePatchDataBuilder> {
  CommitUpdatePatchDataBuilder operator[](int index) => readListElement(new CommitUpdatePatchDataBuilder(), index, 16);
}

class _CommitListUpdatePatchDataList extends ListReader implements List<CommitListUpdatePatchData> {
  CommitListUpdatePatchData operator[](int index) => readListElement(new CommitListUpdatePatchData(), index, 16);
}

class _CommitListUpdatePatchDataBuilderList extends ListBuilder implements List<CommitListUpdatePatchDataBuilder> {
  CommitListUpdatePatchDataBuilder operator[](int index) => readListElement(new CommitListUpdatePatchDataBuilder(), index, 16);
}

class _CommitPatchDataList extends ListReader implements List<CommitPatchData> {
  CommitPatchData operator[](int index) => readListElement(new CommitPatchData(), index, 24);
}

class _CommitPatchDataBuilderList extends ListBuilder implements List<CommitPatchDataBuilder> {
  CommitPatchDataBuilder operator[](int index) => readListElement(new CommitPatchDataBuilder(), index, 24);
}
