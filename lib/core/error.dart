// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

const _wrongArgumentType = "Wrong argument type.";
const _indexOutOfBounds = "Index out of bounds.";
const _illegalState = "Illegal state.";

class AbstractClassInstantiationError extends Error {
}

class ArgumentError extends Error {
  String toString() => "ArgumentError";
}

class AssertionError extends Error {
}

class CastError extends Error {
}

class ConcurrentModificationError extends Error {
}

class CyclicInitializationError extends Error {
  String toString() => "CyclicInitializationError";
}

class Error {
  StackTrace get stackTrace
      => throw new UnimplementedError("Error.stackTrace");
}

class Exception {
  final String message;
  Exception([this.message]);

  String toString() => (message == null)
      ? "Exception"
      : "Exception: $message";
}

class FallThroughError extends Error {
}

class FormatException extends Exception {
}

class IndexError extends ArgumentError implements RangeError {
  final int invalidValue;
  final indexable;

  IndexError(this.invalidValue, this.indexable,
             [String name, String message, int length]);
}

class IntegerDivisionByZeroException extends Exception {
  String toString() => "IntegerDivisionByZeroException";
}

class NoSuchMethodError extends Error {
  final String _name;
  NoSuchMethodError._empty() : _name = '';
  NoSuchMethodError._withName(name) : _name = ": $name";
  String toString() => "NoSuchMethodError$_name";
}

class NullThrownError extends Error {
}

class OutOfMemoryError implements Error {
  const OutOfMemoryError();

  StackTrace get stackTrace
      => throw new UnimplementedError("OutOfMemoryError.stackTrace");
}

class RangeError extends ArgumentError {
  final invalidValue;
  final num start;
  final num end;

  final String message;
  RangeError(this.message) : invalidValue = null, start =  null, end = null;

  factory RangeError.index(int index, indexable, [String name, String message, int length])
      => throw new UnimplementedError("RangeError.index");
  RangeError.range(num this.invalidValue, this.start, this.end, [String name, this.message]);
  factory RangeError.value(num value, [String name, String message])
      => throw new UnimplementedError("RangeError.value");

  String toString() => "RangeError";
}

class StackOverflowError implements Error {
  const StackOverflowError();
  StackTrace get stackTrace
      => throw new UnimplementedError("StackOverflowError.stackTrace");
}

class StateError extends Error {
  final String message;
  StateError(this.message);
  String toString() => "Bad state: $message";
}

class TypeError extends Error {
}

class UnimplementedError extends Error {
  final String message;
  UnimplementedError([this.message]);

  String toString() => (message == null)
      ? "UnimplementedError"
      : "UnimplementedError: $message";
}

class UnsupportedError extends Error {
  final String message;
  UnsupportedError(this.message);
  String toString() => "Unsupported operation: $message";
}
