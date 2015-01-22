// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

// Matches dart:core on Jan 21, 2015.
abstract class Exception {
  factory Exception([var message]) => new _ExceptionImplementation(message);
}

class _ExceptionImplementation implements Exception {
  final message;
  _ExceptionImplementation([this.message]);

  String toString() {
    return (message == null) ? "Exception" : "Exception: $message";
  }
}

// Matches dart:core on Jan 21, 2015.
class FormatException implements Exception {
  final String message;
  final source;
  final int offset;

  const FormatException([this.message = "", this.source, this.offset]);

  String toString() {
    throw new UnimplementedError("FormatException.toString");
  }
}

// Matches dart:core on Jan 21, 2015.
class IntegerDivisionByZeroException implements Exception {
  const IntegerDivisionByZeroException();
  String toString() => "IntegerDivisionByZeroException";
}
