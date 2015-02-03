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
  int GetAge(Person person);
  int Count(Person person);
  AgeStatsBuilder GetAgeStats(Person person);

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
        var result = _impl.GetAge(getRoot(new Person(), request));
        request.setInt32(32, result);
        _postResult.icall$1(request);
        break;
      case _GET_AGE_STATS_METHOD_ID:
        MessageBuilder mb = new MessageBuilder(16);
        AgeStatsBuilder builder =
            mb.NewRoot(new AgeStatsBuilder(), AgeStats._kSize);
        _impl.GetAgeStats(getRoot(new Person(), request), builder);
        request.setInt64(32, builder._segment._memory.value);
        _postResult.icall$1(request);
        break;
      case _COUNT_METHOD_ID:
        var result = _impl.Count(getRoot(new Person(), request));
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
  const int _GET_AGE_STATS_METHOD_ID = 3;
}

class Person extends Reader {
  const int _kAgeOffset = 0;
  const int _kChildrenOffset = 8;

  int get age => _segment.memory.getInt32(_offset + _kAgeOffset);
  List<Person> get children => readList(new _PersonList(), _kChildrenOffset);
}

class _PersonList extends ListReader implements List<Person> {
  Person operator[](int index) => readListElement(new Person(), index, 16);
}

class AgeStats extends Reader {
  const int _kAverageAgeOffset = 0;
  const int _kSumOffset = 8;
  const int _kSize = 16;

  int get averageAge => _segment.memory.getInt32(_offset + kAverageAgeOffset);
  int get sum => _segment.memory.getInt32(_offset + kSumOffset);
}

class AgeStatsBuilder extends Builder {
  void set averageAge(int avg) => setInt32(AgeStats._kAverageAgeOffset, avg);
  void set sum(int sum) => setInt32(AgeStats._kSumOffset, sum);
}
