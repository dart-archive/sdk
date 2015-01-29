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
        var result = _impl.GetAge(new Person._(request, 32));
        request.setInt32(32, result);
        _postResult.icall$1(request);
        break;
      case _COUNT_METHOD_ID:
        var result = _impl.Count(new Person._(request, 32));
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

class Person {
  const int _kAgeOffset = 0;
  const int _kChildrenOffset = 8;
  const int _kSize = 16;

  Foreign _memory;
  int _offset;
  Person._(this._memory, this._offset);

  int get age => _memory.getInt32(_offset + _kAgeOffset);

  List<Person> get children {
    Foreign memory = _memory;
    int offset = _offset + _kChildrenOffset;
    int lo = memory.getInt32(offset + 0);
    int hi = memory.getInt32(offset + 4);
    return new _PersonList(memory, lo, hi);
  }
}

class _PersonList implements List<Person> {
  Foreign _memory;
  int _offset;
  int _length;
  _PersonList(this._memory, this._offset, this._length);

  int get length => _length;
  Person operator[](int index) =>
      new Person._(_memory, _offset + index * Person._kSize);
}
