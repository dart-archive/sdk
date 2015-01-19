// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dart.core;

import 'dart:ffi';

part 'coroutine.dart';
part 'double.dart';
part 'error.dart';
part 'integer.dart';
part 'list.dart';
part 'map.dart';
part 'messaging.dart';
part 'num.dart';
part 'print.dart';
part 'process.dart';
part 'string.dart';
part 'thread.dart';

external bool identical(a, b);

class Object {
  // TODO(ajohnsen): Handle this in const_interpreter.cc?
  const Object();

  bool operator ==(other) => identical(this, other);
  String toString() => "an object";

  noSuchMethod(invocation) {
    throw new NoSuchMethodError._empty();
  }

  // The noSuchMethod helper is automatically called from the
  // trampoline and it is passed the selector. The arguments
  // to the original call are still present on the stack, so
  // it is possible to dig them out if need be.
  _noSuchMethod(selector) => noSuchMethod(null);

  // The noSuchMethod trampoline is automatically generated
  // by the compiler. It calls the noSuchMethod helper and
  // takes care off removing an arbitrary number of arguments
  // from the caller stack before it returns.
  external _noSuchMethodTrampoline();

  bool _compareEqFromInteger(int other) => false;
  bool _compareEqFromDouble(double other) => false;
}

class Comparable<T> {
  int compareTo(T other);
}

class Pattern {
}

class Null {
  String toString() => "null";
}

class bool {
  String toString() => this ? "true" : "false";
}

class Symbol {
  final String _name;

  const Symbol(String name) : _name = name;

  bool operator ==(Symbol other) {
    return _name == other._name;
  }

  String toString() => _name;
}

class Stopwatch {
  int _start;
  int _stop;

  int get frequency => _cachedFrequency;
  bool get isRunning => _start != null && _stop == null;

  int get elapsedTicks {
    if (_start == null) return 0;
    return (_stop == null) ? (_now() - _start) : (_stop - _start);
  }

  int get elapsedMilliseconds => (elapsedTicks * 1000) ~/ frequency;
  int get elapsedMicroseconds => (elapsedTicks * 1000000) ~/ frequency;

  void start() {
    if (isRunning) return;
    if (_start == null) {
      // This stopwatch has never been started.
      _start = _now();
    } else {
      // Restart this stopwatch. Prepend the elapsed time to the current
      // start time.
      _start = _now() - (_stop - _start);
      _stop = null;
    }
  }

  void stop() {
    if (!isRunning) return;
    _stop = _now();
  }

  static final int _cachedFrequency = _frequency();
  static int _frequency() native;
  static int _now() native;
}

class Type {
  Type._internal();
}

class _Type implements Type {
  final String _name;
  const _Type(this._name);
  String toString() => _name;
}
