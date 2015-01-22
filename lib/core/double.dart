// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

// Matches dart:core on Jan 21, 2015.
class double extends num {
  static const double NAN = 0.0 / 0.0;
  static const double INFINITY = 1.0 / 0.0;
  static const double NEGATIVE_INFINITY = -INFINITY;

  // TODO(kasperl): The scanner cannot deal with these yet.
  // static const double MIN_POSITIVE = 5e-324;
  // static const double MAX_FINITE = 1.7976931348623157e+308;

  num operator -() native;

  num operator +(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._addFromDouble(this);
  }

  num operator -(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._subFromDouble(this);
  }

  num operator *(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._mulFromDouble(this);
  }

  num operator %(num other) native catch (error) {
    return other._modFromDouble(this);
  }

  num operator /(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._divFromDouble(this);
  }

  num operator ~/(num other) native catch (error) {
    switch (error) {
      case _wrongArgumentType:
        return other._truncDivFromDouble(this);
      case _indexOutOfBounds:
        throw new UnsupportedError();
    }
  }

  bool operator ==(other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._compareEqFromDouble(this);
  }

  bool operator <(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._compareLtFromDouble(this);
  }

  bool operator <=(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._compareLeFromDouble(this);
  }

  bool operator >(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._compareGtFromDouble(this);
  }

  bool operator >=(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._compareGeFromDouble(this);
  }

  double abs() {
    if (this == 0.0) return 0.0;  // -0.0 -> 0.0
    return (this < 0.0) ? -this : this;
  }

  double remainder(num other) native catch (error) {
    return other._remainderFromDouble(this);
  }

  int round() native;
  double roundToDouble() native;

  int floor() native;
  double floorToDouble() native;

  int ceil() native;
  double ceilToDouble() native;

  int truncate() native;
  double truncateToDouble() native;

  bool get isNaN native;
  bool get isNegative native;

  bool get isFinite {
    return this != double.INFINITY && this != -double.INFINITY && !isNaN;
  }

  bool get isInfinite {
    return (this == double.INFINITY || this == -double.INFINITY) && !isNaN;
  }

  double get sign {
    if (this > 0.0) return 1.0;
    if (this < 0.0) return -1.0;
    return this;
  }

  num clamp(num lowerLimit, num upperLimit) {
    throw new UnimplementedError("double.clamp");
  }

  double toDouble() => this;

  int toInt() native catch (error) {
    throw new UnsupportedError();
  }

  String toString() native;

  String toStringAsExponential([int digits]) {
    if (digits == null) {
      digits = -1;
    } else {
      if (digits is! int) throw new ArgumentError();
      if (digits < 0 || digits > 20) throw new RangeError.range(digits, 0, 20);
    }
    if (isNaN) return "NaN";
    if (this == double.INFINITY) return "Infinity";
    if (this == -double.INFINITY) return "-Infinity";

    return _toStringAsExponential(digits);
  }

  String toStringAsFixed(int digits) {
    if (digits is! int) throw new ArgumentError();
    if (digits < 0 || digits > 20) throw new RangeError.range(digits, 0, 20);
    if (isNaN) return "NaN";
    if (this >= 1e21 || this <= -1e21) return toString();
    return _toStringAsFixed(digits);
  }

  String toStringAsPrecision(int digits) {
    if (digits is! int) throw new ArgumentError();
    if (digits < 1 || digits > 21) throw new RangeError.range(digits, 1, 21);
    if (isNaN) return "NaN";
    if (this == double.INFINITY) return "Infinity";
    if (this == -double.INFINITY) return "-Infinity";
    return _toStringAsPrecision(digits);
  }

  static double parse(String source, [double onError(String source)]) {
    throw new UnimplementedError("double.parse");
  }

  String _toStringAsExponential(int digits) native;
  String _toStringAsFixed(int digits) native;
  String _toStringAsPrecision(int digits) native;

  double _addFromInteger(int other) => other.toDouble() + this;
  double _subFromInteger(int other) => other.toDouble() - this;
  double _mulFromInteger(int other) => other.toDouble() * this;
  double _modFromInteger(int other) => other.toDouble() % this;
  double _divFromInteger(int other) => other.toDouble() / this;
  double _truncDivFromInteger(int other) => other.toDouble() ~/ this;

  bool _compareEqFromInteger(int other) => other.toDouble() == this;
  bool _compareLtFromInteger(int other) => other.toDouble() <  this;
  bool _compareLeFromInteger(int other) => other.toDouble() <= this;
  bool _compareGtFromInteger(int other) => other.toDouble() >  this;
  bool _compareGeFromInteger(int other) => other.toDouble() >= this;
}
