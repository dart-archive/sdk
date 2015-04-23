// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.system;

// TODO(ajohnsen): Rename to _DoubleImpl.
class double implements core.double {
  int get hashCode => truncate();

  @native external num operator -();

  int compareTo(num other) {
    if (this < other) return -1;
    if (this > other) return 1;
    if (this == other) {
      if (this == 0.0) {
        var negative = isNegative;
        if (negative == other.isNegative) return 0;
        return negative ? -1 : 1;
      }
      return 0;
    }
    if (isNaN) return other.isNaN ? 0 : 1;
    return -1;
  }

  @native num operator +(other) {
    // TODO(kasperl): Check error.
    return other._addFromDouble(this);
  }

  @native num operator -(other) {
    // TODO(kasperl): Check error.
    return other._subFromDouble(this);
  }

  @native num operator *(other) {
    // TODO(kasperl): Check error.
    return other._mulFromDouble(this);
  }

  @native num operator %(other) {
    // TODO(kasperl): Check error.
    return other._modFromDouble(this);
  }

  @native num operator /(other) {
    // TODO(kasperl): Check error.
    return other._divFromDouble(this);
  }

  @native num operator ~/(other) {
    switch (nativeError) {
      case wrongArgumentType:
        return other._truncDivFromDouble(this);
      case indexOutOfBounds:
        throw new UnsupportedError("double.~/ $this");
    }
  }

  @native bool operator ==(other) {
    if (other is! num) return false;
    // TODO(kasperl): Check error.
    return other._compareEqFromDouble(this);
  }

  @native bool operator <(other) {
    // TODO(kasperl): Check error.
    return other._compareLtFromDouble(this);
  }

  @native bool operator <=(other) {
    // TODO(kasperl): Check error.
    return other._compareLeFromDouble(this);
  }

  @native bool operator >(other) {
    // TODO(kasperl): Check error.
    return other._compareGtFromDouble(this);
  }

  @native bool operator >=(other) {
    // TODO(kasperl): Check error.
    return other._compareGeFromDouble(this);
  }

  double abs() {
    if (this == 0.0) return 0.0;  // -0.0 -> 0.0
    return (this < 0.0) ? -this : this;
  }

  @native double remainder(other) {
    return other._remainderFromDouble(this);
  }

  @native int round() {
    throw new UnsupportedError("double.round $this");
  }

  @native int floor() {
    throw new UnsupportedError("double.floor $this");
  }

  @native int ceil() {
    throw new UnsupportedError("double.ceil $this");
  }

  @native int truncate() {
    throw new UnsupportedError("double.truncate $this");
  }

  @native external double roundToDouble();
  @native external double floorToDouble();
  @native external double ceilToDouble();
  @native external double truncateToDouble();

  @native external bool get isNaN;
  @native external bool get isNegative;

  bool get isFinite {
    return this != core.double.INFINITY &&
      this != -core.double.INFINITY &&
      !isNaN;
  }

  bool get isInfinite {
    return (this == core.double.INFINITY ||
            this == -core.double.INFINITY) && !isNaN;
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

  int toInt() => truncate();

  @native external String toString();

  String toStringAsExponential([int digits]) {
    if (digits == null) {
      digits = -1;
    } else {
      if (digits is! int) throw new ArgumentError();
      if (digits < 0 || digits > 20) throw new RangeError.range(digits, 0, 20);
    }
    if (isNaN) return "NaN";
    if (this == core.double.INFINITY) return "Infinity";
    if (this == -core.double.INFINITY) return "-Infinity";

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
    if (this == core.double.INFINITY) return "Infinity";
    if (this == -core.double.INFINITY) return "-Infinity";
    return _toStringAsPrecision(digits);
  }

  @native external String _toStringAsExponential(int digits);
  @native external String _toStringAsFixed(int digits);
  @native external String _toStringAsPrecision(int digits);

  double _addFromInteger(int other) => other.toDouble() + this;

  double _subFromInteger(int other) => other.toDouble() - this;

  double _mulFromInteger(int other) => other.toDouble() * this;

  double _modFromInteger(int other) => other.toDouble() % this;

  double _divFromInteger(int other) => other.toDouble() / this;

  int _truncDivFromInteger(int other) => other.toDouble() ~/ this;

  bool _compareEqFromInteger(int other) => other.toDouble() == this;

  bool _compareLtFromInteger(int other) => other.toDouble() <  this;

  bool _compareLeFromInteger(int other) => other.toDouble() <= this;

  bool _compareGtFromInteger(int other) => other.toDouble() >  this;

  bool _compareGeFromInteger(int other) => other.toDouble() >= this;

  @native external static double sin(double x);

  @native external static double cos(double x);

  @native external static double tan(double x);

  @native external static double acos(double x);

  @native external static double asin(double x);

  @native external static double atan(double x);

  @native external static double sqrt(double x);

  @native external static double exp(double x);

  @native external static double log(double x);

  @native external static double atan2(double a, double b);

  @native external static double pow(double x, double exponent);
}
