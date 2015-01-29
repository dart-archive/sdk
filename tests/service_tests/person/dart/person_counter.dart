// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

library person_counter;

import "dart:ffi";
import "dart:service" as service;

final Channel _channel = new Channel();
final Port _port = new Port(_channel);
final Foreign _postResult = Foreign.lookup("PostResultToService");

bool _terminated = false;
PersonCounter _impl;

abstract class PersonCounter {
  int GetAge(Person person);
  int Count(Person person);

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
        var result = _impl.GetAge(getRoot(request));
        request.setInt32(32, result);
        _postResult.icall$1(request);
        break;
      case _COUNT_METHOD_ID:
        var result = _impl.Count(getRoot(request));
        request.setInt32(32, result);
        _postResult.icall$1(request);
        break;
      default:
        throw UnsupportedError();
    }
  }

  const int _TERMINATE_METHOD_ID = 0;
  const int _GET_AGE_METHOD_ID = 1;
  const int _COUNT_METHOD_ID = 2;
}

Person getRoot(Foreign request) {
  if (request.getInt32(32) == 1) {
    return getSegmentedRoot(request);
  } else {
    MessageReader reader = new MessageReader();
    Segment segment = new Segment(reader, request);
    reader.segments.add(segment);
    return new Person._(segment, 40);
  }
}

Person getSegmentedRoot(Foreign request) {
  MessageReader reader = new MessageReader();
  int segments = request.getInt32(40);
  int offset = 40 + 8;
  for (int i = 0; i < segments; i++) {
    int address = (Foreign.bitsPerMachineWord == 32)
        ? request.getUint32(offset)
        : request.getUint64(offset);
    int size = request.getInt32(offset + 8);
    Foreign memory = new Foreign.fromAddress(address, size);
    Segment segment = new Segment(reader, memory);
    reader.segments.add(segment);
    offset += 16;
  }
  // Read segments.
  return new Person._(reader.segments.first, 40);
}

class MessageReader {
  final List<Segment> segments = [];
  MessageReader();

  Segment getSegment(int id) => segments[id];
}

class Segment {
  final MessageReader reader;
  final Foreign memory;
  Segment(this.reader, this.memory);
}

class Person {
  const int _kAgeOffset = 0;
  const int _kChildrenOffset = 8;
  const int _kSize = 16;

  final Segment _segment;
  final int _offset;
  Person._(this._segment, this._offset);

  int get age => _segment.memory.getInt32(_offset + _kAgeOffset);

  List<Person> get children {
    Segment segment = _segment;
    int offset = _offset + _kChildrenOffset;
    while (true) {
      Foreign memory = segment.memory;
      int lo = memory.getInt32(offset + 0);
      int hi = memory.getInt32(offset + 4);
      if ((lo & 1) == 0) {
        return new _PersonList(segment, lo >> 1, hi);
      } else {
        segment = segment.reader.getSegment(hi);
        offset = lo >> 1;
      }
    }
  }
}

class _PersonList implements List<Person> {
  Segment _segment;
  int _offset;
  int _length;
  _PersonList(this._segment, this._offset, this._length);

  int get length => _length;
  Person operator[](int index) =>
      new Person._(_segment, _offset + index * Person._kSize);
}
