// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

const _wrongArgumentType = "Wrong argument type.";
const _indexOutOfBounds = "Index out of bounds.";
const _illegalState = "Illegal state.";

class Error {
}

class ArgumentError extends Error {
  String toString() => "ArgumentError";
}

class IntegerDivisionByZeroException extends Error {
  String toString() => "IntegerDivisionByZeroException";
}

class UnsupportedError extends Error {
  String toString() => "UnsupportedError";
}

class NoSuchMethodError extends Error {
  final String _name;
  NoSuchMethodError._empty() : _name = '';
  NoSuchMethodError._withName(name) : _name = ": $name";
  String toString() => "NoSuchMethodError$_name";
}

class RangeError extends Error {
  String toString() => "RangeError";
}

class StateError extends Error {
  final String message;
  StateError(this.message);
  String toString() => "Bad state: $message";
}

class _CyclicInitializationMarker {
  const _CyclicInitializationMarker();
}

class CyclicInitializationError extends Error {
  String toString() => "CyclicInitializationError";
}
