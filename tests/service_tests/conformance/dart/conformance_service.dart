// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

library conformance_service;

import "dart:fletch";
import "dart:ffi";
import "dart:service" as service;
import "package:service/struct.dart";

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
  void flipTable(TableFlip flip, TableFlipBuilder result);

  static void initialize(ConformanceService impl) {
    if (_impl != null) {
      throw new UnsupportedError("Cannot re-initialize");
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
        _postResult.vcall$1(request);
        break;
      case _GET_AGE_METHOD_ID:
        var result = _impl.getAge(getRoot(new Person(), request));
        request.setInt32(56, result);
        _postResult.vcall$1(request);
        break;
      case _GET_BOXED_AGE_METHOD_ID:
        var result = _impl.getBoxedAge(getRoot(new PersonBox(), request));
        request.setInt32(56, result);
        _postResult.vcall$1(request);
        break;
      case _GET_AGE_STATS_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(16);
        AgeStatsBuilder builder = mb.initRoot(new AgeStatsBuilder(), 8);
        _impl.getAgeStats(getRoot(new Person(), request), builder);
        var result = getResultMessage(builder);
        request.setInt64(56, result);
        _postResult.vcall$1(request);
        break;
      case _CREATE_AGE_STATS_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(16);
        AgeStatsBuilder builder = mb.initRoot(new AgeStatsBuilder(), 8);
        _impl.createAgeStats(request.getInt32(56), request.getInt32(60), builder);
        var result = getResultMessage(builder);
        request.setInt64(56, result);
        _postResult.vcall$1(request);
        break;
      case _CREATE_PERSON_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(32);
        PersonBuilder builder = mb.initRoot(new PersonBuilder(), 24);
        _impl.createPerson(request.getInt32(56), builder);
        var result = getResultMessage(builder);
        request.setInt64(56, result);
        _postResult.vcall$1(request);
        break;
      case _CREATE_NODE_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(32);
        NodeBuilder builder = mb.initRoot(new NodeBuilder(), 24);
        _impl.createNode(request.getInt32(56), builder);
        var result = getResultMessage(builder);
        request.setInt64(56, result);
        _postResult.vcall$1(request);
        break;
      case _COUNT_METHOD_ID:
        var result = _impl.count(getRoot(new Person(), request));
        request.setInt32(56, result);
        _postResult.vcall$1(request);
        break;
      case _DEPTH_METHOD_ID:
        var result = _impl.depth(getRoot(new Node(), request));
        request.setInt32(56, result);
        _postResult.vcall$1(request);
        break;
      case _FOO_METHOD_ID:
        _impl.foo();
        _postResult.vcall$1(request);
        break;
      case _BAR_METHOD_ID:
        var result = _impl.bar(getRoot(new Empty(), request));
        request.setInt32(56, result);
        _postResult.vcall$1(request);
        break;
      case _PING_METHOD_ID:
        var result = _impl.ping();
        request.setInt32(56, result);
        _postResult.vcall$1(request);
        break;
      case _FLIP_TABLE_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(16);
        TableFlipBuilder builder = mb.initRoot(new TableFlipBuilder(), 8);
        _impl.flipTable(getRoot(new TableFlip(), request), builder);
        var result = getResultMessage(builder);
        request.setInt64(56, result);
        _postResult.vcall$1(request);
        break;
      default:
        throw new UnsupportedError("Unknown method");
    }
  }

  static const int _TERMINATE_METHOD_ID = 0;
  static const int _GET_AGE_METHOD_ID = 1;
  static const int _GET_BOXED_AGE_METHOD_ID = 2;
  static const int _GET_AGE_STATS_METHOD_ID = 3;
  static const int _CREATE_AGE_STATS_METHOD_ID = 4;
  static const int _CREATE_PERSON_METHOD_ID = 5;
  static const int _CREATE_NODE_METHOD_ID = 6;
  static const int _COUNT_METHOD_ID = 7;
  static const int _DEPTH_METHOD_ID = 8;
  static const int _FOO_METHOD_ID = 9;
  static const int _BAR_METHOD_ID = 10;
  static const int _PING_METHOD_ID = 11;
  static const int _FLIP_TABLE_METHOD_ID = 12;
}

class Empty extends Reader {
}

class EmptyBuilder extends Builder {
}

class AgeStats extends Reader {
  int get averageAge => segment.memory.getInt32(offset + 0);
  int get sum => segment.memory.getInt32(offset + 4);
}

class AgeStatsBuilder extends Builder {
  void set averageAge(int value) {
    segment.memory.setInt32(offset + 0, value);
  }
  void set sum(int value) {
    segment.memory.setInt32(offset + 4, value);
  }
}

class Person extends Reader {
  String get name => readString(new _uint16List(), 0);
  List<int> get nameData => readList(new _uint16List(), 0);
  List<Person> get children => readList(new _PersonList(), 8);
  int get age => segment.memory.getInt32(offset + 16);
}

class PersonBuilder extends Builder {
  void set name(String value) {
    NewString(new _uint16BuilderList(), 0, value);
  }
  List<int> initNameData(int length) {
    _uint16BuilderList result = NewList(new _uint16BuilderList(), 0, length, 2);
    return result;
  }
  List<PersonBuilder> initChildren(int length) {
    _PersonBuilderList result = NewList(new _PersonBuilderList(), 8, length, 24);
    return result;
  }
  void set age(int value) {
    segment.memory.setInt32(offset + 16, value);
  }
}

class Large extends Reader {
  Small get s => new Small()
      ..segment = segment
      ..offset = offset + 0;
  int get y => segment.memory.getInt32(offset + 4);
}

class LargeBuilder extends Builder {
  SmallBuilder initS() {
    return new SmallBuilder()
        ..segment = segment
        ..offset = offset + 0;
  }
  void set y(int value) {
    segment.memory.setInt32(offset + 4, value);
  }
}

class Small extends Reader {
  int get x => segment.memory.getInt32(offset + 0);
}

class SmallBuilder extends Builder {
  void set x(int value) {
    segment.memory.setInt32(offset + 0, value);
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
  int get num => segment.memory.getInt32(offset + 0);
  bool get isCond => 2 == this.tag;
  bool get cond => segment.memory.getUint8(offset + 0) != 0;
  bool get isCons => 3 == this.tag;
  Cons get cons => new Cons()
      ..segment = segment
      ..offset = offset + 0;
  bool get isNil => 4 == this.tag;
  int get tag => segment.memory.getUint16(offset + 16);
}

class NodeBuilder extends Builder {
  void set num(int value) {
    tag = 1;
    segment.memory.setInt32(offset + 0, value);
  }
  void set cond(bool value) {
    tag = 2;
    segment.memory.setUint8(offset + 0, value ? 1 : 0);
  }
  ConsBuilder initCons() {
    tag = 3;
    return new ConsBuilder()
        ..segment = segment
        ..offset = offset + 0;
  }
  void setNil() {
    tag = 4;
  }
  void set tag(int value) {
    segment.memory.setUint16(offset + 16, value);
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

class TableFlip extends Reader {
  String get flip => readString(new _uint16List(), 0);
  List<int> get flipData => readList(new _uint16List(), 0);
}

class TableFlipBuilder extends Builder {
  void set flip(String value) {
    NewString(new _uint16BuilderList(), 0, value);
  }
  List<int> initFlipData(int length) {
    _uint16BuilderList result = NewList(new _uint16BuilderList(), 0, length, 2);
    return result;
  }
}

class _uint16List extends ListReader implements List<int> {
  int operator[](int index) => segment.memory.getUint16(offset + index * 2);
}

class _uint16BuilderList extends ListBuilder implements List<int> {
  int operator[](int index) => segment.memory.getUint16(offset + index * 2);
  void operator[]=(int index, int value) { segment.memory.setUint16(offset + index * 2, value); }
}

class _PersonList extends ListReader implements List<Person> {
  Person operator[](int index) => readListElement(new Person(), index, 24);
}

class _PersonBuilderList extends ListBuilder implements List<PersonBuilder> {
  PersonBuilder operator[](int index) => readListElement(new PersonBuilder(), index, 24);
}
