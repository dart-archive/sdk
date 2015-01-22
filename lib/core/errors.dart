// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

const _wrongArgumentType = "Wrong argument type.";
const _indexOutOfBounds = "Index out of bounds.";
const _illegalState = "Illegal state.";

// Matches dart:core on Jan 21, 2015.
class Error {
  Error();

  static String safeToString(Object object) {
    throw new UnimplementedError("Error.safeToString");
  }

  StackTrace get stackTrace {
    throw new UnimplementedError("Error.stackTrace");
  }
}

// Matches dart:core on Jan 21, 2015.
class AssertionError extends Error {
}

// Matches dart:core on Jan 21, 2015.
class TypeError extends AssertionError {
}

// Matches dart:core on Jan 21, 2015.
class CastError extends Error {
}

// Matches dart:core on Jan 21, 2015.
class NullThrownError extends Error {
  String toString() => "Throw of null.";
}

// Matches dart:core on Jan 21, 2015.
class ArgumentError extends Error {
  final bool _hasValue;
  final invalidValue;
  final String name;
  final message;

  ArgumentError([this.message])
     : invalidValue = null,
       _hasValue = false,
       name = null;

  ArgumentError.value(value,
                      [String this.name,
                       String this.message = "Invalid argument"])
      : invalidValue = value,
        _hasValue = true;

  ArgumentError.notNull([String name])
      : this.value(null, name, "Must not be null");

  String toString() {
    if (!_hasValue) {
      var result = "Invalid arguments(s)";
      if (message != null) {
        result = "$result: $message";
      }
      return result;
    }
    String nameString = "";
    if (name != null) {
      nameString = " ($name)";
    }
    return "$message$nameString: ${Error.safeToString(invalidValue)}";
  }
}

// Matches dart:core on Jan 21, 2015.
class RangeError extends ArgumentError {
  final num start;
  final num end;

  RangeError(var message)
      : start = null, end = null, super(message);

  RangeError.value(num value, [String name, String message])
      : start = null, end = null,
        super.value(value, name,
                    (message != null) ? message : "Value not in range");

  RangeError.range(num invalidValue, int minValue, int maxValue,
                   [String name, String message])
      : start = minValue,
        end = maxValue,
        super.value(invalidValue, name,
                    (message != null) ? message : "Invalid value");

  factory RangeError.index(int index, indexable,
                           [String name,
                            String message,
                            int length]) {
    return new IndexError(index, indexable, name, message, length);
  }

  static void checkValueInInterval(int value, int minValue, int maxValue,
                                   [String name, String message]) {
    if (value < minValue || value > maxValue) {
      throw new RangeError.range(value, minValue, maxValue, name, message);
    }
  }

  static void checkValidIndex(int index, var indexable,
                              [String name, int length, String message]) {
    if (length == null) length = indexable.length;
    if (index < 0 || index >= length) {
      if (name == null) name = "index";
      throw new RangeError.index(index, indexable, name, message, length);
    }
  }

  static void checkValidRange(int start, int end, int length,
                              [String startName, String endName,
                               String message]) {
    if (start < 0 || start > length) {
      if (startName == null) startName = "start";
      throw new RangeError.range(start, 0, length, startName, message);
    }
    if (end != null && (end < start || end > length)) {
      if (endName == null) endName = "end";
      throw new RangeError.range(end, start, length, endName, message);
    }
  }

  static void checkNotNegative(int value, [String name, String message]) {
    if (value < 0) throw new RangeError.range(value, 0, null, name, message);
  }

  String toString() {
    if (!_hasValue) return "RangeError: $message";
    String value = Error.safeToString(invalidValue);
    String explanation = "";
    if (start == null) {
      if (end != null) {
        explanation = ": Not less than or equal to $end";
      }
      // If both are null, we don't add a description of the limits.
    } else if (end == null) {
      explanation = ": Not greater than or equal to $start";
    } else if (end > start) {
      explanation = ": Not in range $start..$end, inclusive.";
    } else if (end < start) {
      explanation = ": Valid value range is empty";
    } else {
      // end == start.
      explanation = ": Only valid value is $start";
    }
    return "RangeError: $message ($value)$explanation";
  }
}

// Matches dart:core on Jan 21, 2015.
class IndexError extends ArgumentError implements RangeError {
  final indexable;
  final int length;

  IndexError(int invalidValue, indexable,
             [String name, String message, int length])
      : this.indexable = indexable,
        this.length = (length != null) ? length : indexable.length,
        super.value(invalidValue, name,
                    (message != null) ? message : "Index out of range");

  int get start => 0;
  int get end => length - 1;

  String toString() {
    String target = Error.safeToString(indexable);
    var explanation = "index should be less than $length";
    if (invalidValue < 0) {
      explanation = "index must not be negative";
    }
    return "RangeError: $message ($target[$invalidValue]): $explanation";
  }
}

// Matches dart:core on Jan 21, 2015.
class FallThroughError extends Error {
  FallThroughError();
}

// Matches dart:core on Jan 21, 2015.
class AbstractClassInstantiationError extends Error {
  final String _className;
  AbstractClassInstantiationError(String this._className);
  String toString() => "Cannot instantiate abstract class: '$_className'";
}

// Matches dart:core on Jan 21, 2015.
class NoSuchMethodError extends Error {
  final String _memberName;

  NoSuchMethodError(Object receiver,
                    Symbol memberName,
                    List positionalArguments,
                    Map<Symbol ,dynamic> namedArguments,
                    [List existingArgumentNames = null]) {
    throw UnimplementedError("NoSuchMethodError");
  }

  NoSuchMethodError._empty() : _memberName = null;
  NoSuchMethodError._withName(this._memberName);

  String toString() => (_memberName == null)
      ? "NoSuchMethodError"
      : "NoSuchMethodError: ${_memberName}";
}

// Matches dart:core on Jan 21, 2015.
class UnsupportedError extends Error {
  final String message;
  UnsupportedError(this.message);
  String toString() => "Unsupported operation: $message";
}

// Matches dart:core on Jan 21, 2015.
class UnimplementedError extends Error implements UnsupportedError {
  final String message;
  UnimplementedError([String this.message]);
  String toString() => (message != null)
      ? "UnimplementedError: $message"
      : "UnimplementedError";
}

// Matches dart:core on Jan 21, 2015.
class StateError extends Error {
  final String message;
  StateError(this.message);
  String toString() => "Bad state: $message";
}

// Matches dart:core on Jan 21, 2015.
class ConcurrentModificationError extends Error {
  final Object modifiedObject;

  ConcurrentModificationError([this.modifiedObject]);

  String toString() => (modifiedObject == null)
        ? "Concurrent modification during iteration."
        : "Concurrent modification during iteration: "
          "${Error.safeToString(modifiedObject)}.";
}

// Matches dart:core on Jan 21, 2015.
class OutOfMemoryError implements Error {
  const OutOfMemoryError();
  String toString() => "Out of Memory";

  StackTrace get stackTrace => null;
}

// Matches dart:core on Jan 21, 2015.
class StackOverflowError implements Error {
  const StackOverflowError();
  String toString() => "Stack Overflow";

  StackTrace get stackTrace => null;
}

// Matches dart:core on Jan 21, 2015.
class CyclicInitializationError extends Error {
  final String variableName;
  CyclicInitializationError([this.variableName]);
  String toString() => variableName == null
      ? "Reading static variable during its initialization"
      : "Reading static variable '$variableName' during its initialization";
}
