// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:_fletch_system' as fletch;

const patch = "patch";

@patch bool identical(Object a, Object b) {
  return false;
}

@patch class Object {
  @patch String toString() => '[object Object]';

  // TODO(ajohnsen): Not very good..
  @patch int get hashCode => 42;

  @patch noSuchMethod(Invocation invocation) {
    // TODO(kasperl): Extract information from the invocation
    // so we can construct the right NoSuchMethodError.
    fletch.unresolved("<unknown>");
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
}

// TODO(ajohnsen): Merge 'fletch.String' into this String.
@patch class String {
  @patch factory String.fromCharCodes(
      Iterable<int> charCode,
      [int start = 0,
       int end]) {
    return fletch.String.fromCharCodes(charCode, start, end);
  }

  @patch factory String.fromCharCode(int charCode) {
    return fletch.String.fromCharCode(charCode);
  }
}

@patch class StringBuffer {
  String _buffer;

  @patch StringBuffer([this._buffer = ""]);

  @patch void write(Object obj) {
    _buffer = _buffer + "$obj";
  }

  @patch void writeCharCode(int charCode) {
    _buffer = _buffer + new String.fromCharCode(charCode);
  }

  @patch void clear() {
    _buffer = "";
  }

  @patch int get length => _buffer.length;

  @patch String toString() => _buffer;
}

@patch class Error {
  @patch static String _stringToSafeString(String string) {
    throw "_stringToSafeString is unimplemented";
  }

  @patch static String _objectToString(Object object) {
    throw "_stringToSafeString is unimplemented";
  }

  @patch StackTrace get stackTrace {
    throw "getter stackTrace is unimplemented";
  }
}

@patch class Stopwatch {
  @patch @fletch.native external static int _now();

  @patch static int _initTicker() {
    _frequency = _fletchNative_frequency();
  }

  @fletch.native external static int _fletchNative_frequency();
}

@patch class List {
  @patch factory List([int length]) {
    return fletch.newList(length);
  }
}

@patch class NoSuchMethodError {
  @patch String toString() {
    return "NoSuchMethodError: '$_memberName'";
  }
}

@patch class Null {
  // This function is overridden, so we can bypass the 'this == null' check.
  bool operator ==(other) => other == null;
}

@patch class int {
  @patch static int parse(
      String source,
      {int radix: 0,
       int onError(String source)}) {
    return _parse(source, radix);
  }

  @fletch.native static _parse(String source, int radix) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        throw new ArgumentError(source);
      case fletch.indexOutOfBounds:
        throw new FormatException("Invalud number", source);
    }
  }
}
