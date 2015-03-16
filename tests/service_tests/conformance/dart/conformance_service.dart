// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

library conformance_service;

import "dart:ffi";
import "dart:service" as service;
import "struct.dart";

final Channel _channel = new Channel();
final Port _port = new Port(_channel);
final Foreign _postResult = Foreign.lookup("PostResultToService");

bool _terminated = false;
ConformanceService _impl;

abstract class ConformanceService {
  int getAge(Person person);
  int getBoxedAge(PersonBox box);
  void getAgeStats(Person person, AgeStatsBuilder result);
  void createAgeStats(int averageAge, int sum, AgeStatsBuilder result);
  void createPerson(int children, PersonBuilder result);
  void createNode(int depth, NodeBuilder result);
  int count(Person person);
  int depth(Node node);
  void foo();
  int bar(Empty empty);
  int ping();

  static void initialize(ConformanceService impl) {
    if (_impl != null) {
      throw new UnsupportedError();
    }
    _impl = impl;
    _terminated = false;
    service.register("ConformanceService", _port);
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
      case _GET_AGE_METHOD_ID:
        var result = _impl.getAge(getRoot(new Person(), request));
        request.setInt32(48, result);
        _postResult.icall$1(request);
        break;
      case _GET_BOXED_AGE_METHOD_ID:
        var result = _impl.getBoxedAge(getRoot(new PersonBox(), request));
        request.setInt32(48, result);
        _postResult.icall$1(request);
        break;
      case _GET_AGE_STATS_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(16);
        AgeStatsBuilder builder = mb.initRoot(new AgeStatsBuilder(), 8);
        _impl.getAgeStats(getRoot(new Person(), request), builder);
        var result = getResultMessage(builder);
        request.setInt64(48, result);
        _postResult.icall$1(request);
        break;
      case _CREATE_AGE_STATS_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(16);
        AgeStatsBuilder builder = mb.initRoot(new AgeStatsBuilder(), 8);
        _impl.createAgeStats(request.getInt32(48), request.getInt32(52), builder);
        var result = getResultMessage(builder);
        request.setInt64(48, result);
        _postResult.icall$1(request);
        break;
      case _CREATE_PERSON_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(32);
        PersonBuilder builder = mb.initRoot(new PersonBuilder(), 24);
        _impl.createPerson(request.getInt32(48), builder);
        var result = getResultMessage(builder);
        request.setInt64(48, result);
        _postResult.icall$1(request);
        break;
      case _CREATE_NODE_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(32);
        NodeBuilder builder = mb.initRoot(new NodeBuilder(), 24);
        _impl.createNode(request.getInt32(48), builder);
        var result = getResultMessage(builder);
        request.setInt64(48, result);
        _postResult.icall$1(request);
        break;
      case _COUNT_METHOD_ID:
        var result = _impl.count(getRoot(new Person(), request));
        request.setInt32(48, result);
        _postResult.icall$1(request);
        break;
      case _DEPTH_METHOD_ID:
        var result = _impl.depth(getRoot(new Node(), request));
        request.setInt32(48, result);
        _postResult.icall$1(request);
        break;
      case _FOO_METHOD_ID:
        _impl.foo();
        _postResult.icall$1(request);
        break;
      case _BAR_METHOD_ID:
        var result = _impl.bar(getRoot(new Empty(), request));
        request.setInt32(48, result);
        _postResult.icall$1(request);
        break;
      case _PING_METHOD_ID:
        var result = _impl.ping();
        request.setInt32(48, result);
        _postResult.icall$1(request);
        break;
      default:
        throw UnsupportedError();
    }
  }

  const int _TERMINATE_METHOD_ID = 0;
  const int _GET_AGE_METHOD_ID = 1;
  const int _GET_BOXED_AGE_METHOD_ID = 2;
  const int _GET_AGE_STATS_METHOD_ID = 3;
  const int _CREATE_AGE_STATS_METHOD_ID = 4;
  const int _CREATE_PERSON_METHOD_ID = 5;
  const int _CREATE_NODE_METHOD_ID = 6;
  const int _COUNT_METHOD_ID = 7;
  const int _DEPTH_METHOD_ID = 8;
  const int _FOO_METHOD_ID = 9;
  const int _BAR_METHOD_ID = 10;
  const int _PING_METHOD_ID = 11;
}

class Empty extends Reader {
}

class EmptyBuilder extends Builder {
}

class AgeStats extends Reader {
  int get averageAge => _segment.memory.getInt32(_offset + 0);
  int get sum => _segment.memory.getInt32(_offset + 4);
}

class AgeStatsBuilder extends Builder {
  void set averageAge(int value) {
    _segment.memory.setInt32(_offset + 0, value);
  }
  void set sum(int value) {
    _segment.memory.setInt32(_offset + 4, value);
  }
}

class Person extends Reader {
  String get name => readString(new _uint8List(), 0);
  List<int> get nameData => readList(new _uint8List(), 0);
  List<Person> get children => readList(new _PersonList(), 8);
  int get age => _segment.memory.getInt32(_offset + 16);
}

class PersonBuilder extends Builder {
  void set name(String value) {
    NewString(new _uint8BuilderList(), 0, value);
  }
  List<int> initNameData(int length) {
    return NewList(new _uint8BuilderList(), 0, length, 1);
  }
  List<PersonBuilder> initChildren(int length) {
    return NewList(new _PersonBuilderList(), 8, length, 24);
  }
  void set age(int value) {
    _segment.memory.setInt32(_offset + 16, value);
  }
}

class Large extends Reader {
  Small get s => new Small()
      .._segment = _segment
      .._offset = _offset + 0;
  int get y => _segment.memory.getInt32(_offset + 4);
}

class LargeBuilder extends Builder {
  SmallBuilder initS() {
    return new SmallBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  void set y(int value) {
    _segment.memory.setInt32(_offset + 4, value);
  }
}

class Small extends Reader {
  int get x => _segment.memory.getInt32(_offset + 0);
}

class SmallBuilder extends Builder {
  void set x(int value) {
    _segment.memory.setInt32(_offset + 0, value);
  }
}

class PersonBox extends Reader {
  Person get person => readStruct(new Person(), 0);
}

class PersonBoxBuilder extends Builder {
  PersonBuilder initPerson() {
    return NewStruct(new PersonBuilder(), 0, 24);
  }
}

class Node extends Reader {
  bool get isNum => 1 == this.tag;
  int get num => _segment.memory.getInt32(_offset + 0);
  bool get isCond => 2 == this.tag;
  bool get cond => _segment.memory.getUint8(_offset + 0) != 0;
  bool get isCons => 3 == this.tag;
  Cons get cons => new Cons()
      .._segment = _segment
      .._offset = _offset + 0;
  bool get isNil => 4 == this.tag;
  int get tag => _segment.memory.getUint16(_offset + 16);
}

class NodeBuilder extends Builder {
  void set num(int value) {
    tag = 1;
    _segment.memory.setInt32(_offset + 0, value);
  }
  void set cond(bool value) {
    tag = 2;
    _segment.memory.setUint8(_offset + 0, value ? 1 : 0);
  }
  ConsBuilder initCons() {
    tag = 3;
    return new ConsBuilder()
        .._segment = _segment
        .._offset = _offset + 0;
  }
  void setNil() {
    tag = 4;
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

class _uint8List extends ListReader implements List<uint8> {
  int operator[](int index) => _segment.memory.getUint8(_offset + index * 1);
}

class _uint8BuilderList extends ListBuilder implements List<uint8> {
  int operator[](int index) => _segment.memory.getUint8(_offset + index * 1);
  void operator[]=(int index, int value) => _segment.memory.setUint8(_offset + index * 1, value);
}

class _PersonList extends ListReader implements List<Person> {
  Person operator[](int index) => readListElement(new Person(), index, 24);
}

class _PersonBuilderList extends ListBuilder implements List<PersonBuilder> {
  PersonBuilder operator[](int index) => readListElement(new PersonBuilder(), index, 24);
}
