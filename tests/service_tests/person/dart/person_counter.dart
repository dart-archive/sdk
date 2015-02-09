// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

library person_counter;

import "dart:ffi";
import "dart:service" as service;
import "struct.dart";

final Channel _channel = new Channel();
final Port _port = new Port(_channel);
final Foreign _postResult = Foreign.lookup("PostResultToService");

bool _terminated = false;
PersonCounter _impl;

abstract class PersonCounter {
  int getAge(Person person);
  int getBoxedAge(PersonBox box);
  void getAgeStats(Person person, AgeStatsBuilder result);
  void createAgeStats(int averageAge, int sum, AgeStatsBuilder result);
  void createPerson(int children, PersonBuilder result);
  void createNode(int depth, NodeBuilder result);
  int count(Person person);
  int depth(Node node);

  static void initialize(PersonCounter impl) {
    if (_impl != null) {
      throw new UnsupportedError();
    }
    _impl = impl;
    _terminated = false;
    service.register("PersonCounter", _port);
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
        request.setInt32(32, result);
        _postResult.icall$1(request);
        break;
      case _GET_BOXED_AGE_METHOD_ID:
        var result = _impl.getBoxedAge(getRoot(new PersonBox(), request));
        request.setInt32(32, result);
        _postResult.icall$1(request);
        break;
      case _GET_AGE_STATS_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(16);
        AgeStatsBuilder builder = mb.initRoot(new AgeStatsBuilder(), 8);
        _impl.getAgeStats(getRoot(new Person(), request), builder);
        var result = getResultMessage(builder);
        request.setInt64(32, result);
        _postResult.icall$1(request);
        break;
      case _CREATE_AGE_STATS_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(16);
        AgeStatsBuilder builder = mb.initRoot(new AgeStatsBuilder(), 8);
        _impl.createAgeStats(request.getInt32(32), request.getInt32(36), builder);
        var result = getResultMessage(builder);
        request.setInt64(32, result);
        _postResult.icall$1(request);
        break;
      case _CREATE_PERSON_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(24);
        PersonBuilder builder = mb.initRoot(new PersonBuilder(), 16);
        _impl.createPerson(request.getInt32(32), builder);
        var result = getResultMessage(builder);
        request.setInt64(32, result);
        _postResult.icall$1(request);
        break;
      case _CREATE_NODE_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(24);
        NodeBuilder builder = mb.initRoot(new NodeBuilder(), 16);
        _impl.createNode(request.getInt32(32), builder);
        var result = getResultMessage(builder);
        request.setInt64(32, result);
        _postResult.icall$1(request);
        break;
      case _COUNT_METHOD_ID:
        var result = _impl.count(getRoot(new Person(), request));
        request.setInt32(32, result);
        _postResult.icall$1(request);
        break;
      case _DEPTH_METHOD_ID:
        var result = _impl.depth(getRoot(new Node(), request));
        request.setInt32(32, result);
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
  int get age => _segment.memory.getInt32(_offset + 0);
  List<Person> get children => readList(new _PersonList(), 8);
}

class PersonBuilder extends Builder {
  void set age(int value) {
    _segment.memory.setInt32(_offset + 0, value);
  }
  List<PersonBuilder> initChildren(int length) {
    return NewList(new _PersonBuilderList(), 8, length, 16);
  }
}

class PersonBox extends Reader {
  Person get person => readStruct(new Person(), 0);
}

class PersonBoxBuilder extends Builder {
  PersonBuilder initPerson() {
    return NewStruct(new PersonBuilder(), 0, 16);
  }
}

class Node extends Reader {
  int get tag => _segment.memory.getUint16(_offset + 0);
  bool get isNum => 1 == this.tag;
  int get num => _segment.memory.getInt32(_offset + 8);
  bool get isCons => 2 == this.tag;
  Cons get cons => readStruct(new Cons(), 8);
}

class NodeBuilder extends Builder {
  void set tag(int value) {
    _segment.memory.setUint16(_offset + 0, value);
  }
  void set num(int value) {
    tag = 1;
    _segment.memory.setInt32(_offset + 8, value);
  }
  ConsBuilder initCons() {
    tag = 2;
    return NewStruct(new ConsBuilder(), 8, 16);
  }
}

class Cons extends Reader {
  Node get fst => readStruct(new Node(), 0);
  Node get snd => readStruct(new Node(), 8);
}

class ConsBuilder extends Builder {
  NodeBuilder initFst() {
    return NewStruct(new NodeBuilder(), 0, 16);
  }
  NodeBuilder initSnd() {
    return NewStruct(new NodeBuilder(), 8, 16);
  }
}

class _PersonList extends ListReader implements List<Person> {
  Person operator[](int index) => readListElement(new Person(), index, 16);
}

class _PersonBuilderList extends ListBuilder implements List<PersonBuilder> {
  PersonBuilder operator[](int index) => readListElement(new PersonBuilder(), index, 16);
}
