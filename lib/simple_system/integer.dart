// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.system;

// TODO(ajohnsen): Rename to e.g. _IntImpl when old compiler is out.
abstract class int implements core.int {
  bool get isNaN => false;

  bool get isNegative => this < 0;

  bool get isInfinite => false;

  bool get isFinite => true;

  int abs() => isNegative ? -this : this;

  int round() => this;

  int floor() => this;

  int ceil() => this;

  int truncate() => this;

  double roundToDouble() => this.toDouble();

  double floorToDouble() => this.toDouble();

  double ceilToDouble() => this.toDouble();

  double truncateToDouble() => this.toDouble();

  int toInt() => this;

  String toStringAsFixed(int fractionDigits) {
    return toDouble().toStringAsFixed(fractionDigits);
  }

  String toStringAsExponential([int fractionDigits]) {
    return toDouble().toStringAsExponential(fractionDigits);
  }

  String toStringAsPrecision(int precision) {
    return toDouble().toStringAsPrecision(fractionDigits);
  }

  int get sign {
    if (this > 0) return 1;
    if (this < 0) return -1;
    return 0;
  }

  int compareTo(num other) {
    if (this == other) {
      if (this == 0 && other is double) return other.isNegative ? 1 : 0;
      return 0;
    } else if (this < other) {
      return -1;
    } else if (other.isNaN) {
      return -1;
    } else {
      return 1;
    }
  }

  num remainder(num other) {
    return this - (this ~/ other) * other;
  }

  // From int.
  modPow(exponent, modulus) {
    throw "modPow(exponent, modulus) isn't implemented";
  }

  get isEven {
    throw "get isEven isn't implemented";
  }

  get isOdd {
    throw "get isOdd isn't implemented";
  }

  get bitLength {
    throw "get bitLength isn't implemented";
  }

  toUnsigned(width) {
    throw "toUnsigned(width) isn't implemented";
  }

  toSigned(width) {
    throw "toSigned(width) isn't implemented";
  }

  toRadixString(radix) {
    throw "toRadixString(radix) isn't implemented";
  }

  // From num.
  clamp(lowerLimit, upperLimit) {
    throw "clamp(lowerLimit, upperLimit) isn't implemented";
  }

  double _addFromDouble(double other) => other + toDouble();

  double _subFromDouble(double other) => other - toDouble();

  double _mulFromDouble(double other) => other * toDouble();

  double _modFromDouble(double other) => other % toDouble();

  double _divFromDouble(double other) => other / toDouble();

  double _truncDivFromDouble(double other) => other ~/ toDouble();

  bool _compareEqFromDouble(double other) => other == toDouble();

  bool _compareLtFromDouble(double other) => other <  toDouble();

  bool _compareLeFromDouble(double other) => other <= toDouble();

  bool _compareGtFromDouble(double other) => other >  toDouble();

  bool _compareGeFromDouble(double other) => other >= toDouble();

  double _remainderFromDouble(double other) => other.remainder(toDouble());
}

class _Smi extends int {
  int get hashCode => this;

  @native external String toString();

  @native external double toDouble();

  @native external int _toMint();

  @native external num operator -();

  @native num operator +(other) {
    // TODO(kasperl): Check error.
    return other._addFromInteger(this);
  }

  @native num operator -(other) {
    // TODO(kasperl): Check error.
    return other._subFromInteger(this);
  }

  @native num operator *(other) {
    // TODO(kasperl): Check error.
    return other._mulFromInteger(this);
  }

  @native num operator %(other) {
    switch (nativeError) {
      case wrongArgumentType:
        return other._modFromInteger(this);
      case indexOutOfBounds:
        throw new IntegerDivisionByZeroException();
    }
  }

  @native num operator /(other) {
    // TODO(kasperl): Check error.
    return other._divFromInteger(this);
  }

  @native int operator ~/(other) {
    switch (nativeError) {
      case wrongArgumentType:
        return other._truncDivFromInteger(this);
      case indexOutOfBounds:
        throw new IntegerDivisionByZeroException();
    }
  }

  @native external int operator ~();

  @native int operator &(other) {
    // TODO(kasperl): Check error.
    return other._bitAndFromInteger(this);
  }

  @native int operator |(other) {
    // TODO(kasperl): Check error.
    return other._bitOrFromInteger(this);
  }

  @native int operator ^(other) {
    // TODO(kasperl): Check error.
    return other._bitXorFromInteger(this);
  }

  @native int operator >>(other) {
    // TODO(kasperl): Check error.
    return other._bitShrFromInteger(this);
  }

  @native int operator <<(other) {
    // TODO(kasperl): Check error.
    return other._bitShlFromInteger(this);
  }

  @native bool operator ==(other) {
    if (other is! num) return false;
    // TODO(kasperl): Check error.
    return other._compareEqFromInteger(this);
  }

  @native bool operator <(other) {
    // TODO(kasperl): Check error.
    return other._compareLtFromInteger(this);
  }

  @native bool operator <=(other) {
    // TODO(kasperl): Check error.
    return other._compareLeFromInteger(this);
  }

  @native bool operator >(other) {
    // TODO(kasperl): Check error.
    return other._compareGtFromInteger(this);
  }

  @native bool operator >=(other) {
    // TODO(kasperl): Check error.
    return other._compareGeFromInteger(this);
  }

  // In the following double-dispatch helpers, [other] might
  // be a small integer in case of overflows. Calling toMint()
  // on [other] isn't strictly necessary but it makes the
  // overflow case a litte bit faster.
  int _addFromInteger(other) => other._toMint() + _toMint();

  int _subFromInteger(other) => other._toMint() - _toMint();

  int _mulFromInteger(other) => other._toMint() * _toMint();

  int _modFromInteger(other) => other._toMint() % _toMint();

  num _divFromInteger(other) => other._toMint() / _toMint();

  int _truncDivFromInteger(other) => other._toMint() ~/ _toMint();

  int _bitAndFromInteger(other) => other._toMint() &  _toMint();

  int _bitOrFromInteger(other)  => other._toMint() |  _toMint();

  int _bitXorFromInteger(other) => other._toMint() ^  _toMint();

  int _bitShrFromInteger(other) => other._toMint() >> _toMint();

  int _bitShlFromInteger(other) => other._toMint() << _toMint();

  bool _compareEqFromInteger(other) => other._toMint() == _toMint();

  bool _compareLtFromInteger(other) => other._toMint() <  _toMint();

  bool _compareLeFromInteger(other) => other._toMint() <= _toMint();

  bool _compareGtFromInteger(other) => other._toMint() >  _toMint();

  bool _compareGeFromInteger(other) => other._toMint() >= _toMint();
}

class _Mint extends int {
  int get hashCode => this;

  @native external String toString();

  @native external double toDouble();

  int _toMint() => this;

  @native external num operator -();

  @native num operator +(other) {
    // TODO(kasperl): Check error.
    return other._addFromInteger(this);
  }

  @native num operator -(other) {
    // TODO(kasperl): Check error.
    return other._subFromInteger(this);
  }

  @native num operator *(other) {
    // TODO(kasperl): Check error.
    return other._mulFromInteger(this);
  }

  @native num operator %(other) {
    switch (nativeError) {
      case wrongArgumentType:
        return other._modFromInteger(this);
      case indexOutOfBounds:
        throw new IntegerDivisionByZeroException();
    }
  }

  @native num operator /(other) {
    // TODO(kasperl): Check error.
    return other._divFromInteger(this);
  }

  @native int operator ~/(other) {
    switch (nativeError) {
      case wrongArgumentType:
        return other._truncDivFromInteger(this);
      case indexOutOfBounds:
        throw new IntegerDivisionByZeroException();
    }
  }

  @native external int operator ~();

  @native int operator &(other) {
    // TODO(kasperl): Check error.
    return other._bitAndFromInteger(this);
  }

  @native int operator |(other) {
    // TODO(kasperl): Check error.
    return other._bitOrFromInteger(this);
  }

  @native int operator ^(other) {
    // TODO(kasperl): Check error.
    return other._bitXorFromInteger(this);
  }

  @native int operator >>(other) {
    // TODO(kasperl): Check error.
    return other._bitShrFromInteger(this);
  }

  @native int operator <<(other) {
    if (nativeError == wrongArgumentType && other is _Mint) {
      // TODO(ajohnsen): Add bigint support.
      throw new UnimplementedError("Overflow to big integer");
    }
    // TODO(kasperl): Check error.
    return other._bitShlFromInteger(this);
  }

  @native bool operator ==(other) {
    if (other is! num) return false;
    // TODO(kasperl): Check error.
    return other._compareEqFromInteger(this);
  }

  @native bool operator <(other) {
    // TODO(kasperl): Check error.
    return other._compareLtFromInteger(this);
  }

  @native bool operator <=(other) {
    // TODO(kasperl): Check error.
    return other._compareLeFromInteger(this);
  }

  @native bool operator >(other) {
    // TODO(kasperl): Check error.
    return other._compareGtFromInteger(this);
  }

  @native bool operator >=(other) {
    // TODO(kasperl): Check error.
    return other._compareGeFromInteger(this);
  }

  int _addFromInteger(other) => other._toMint() + this;

  int _subFromInteger(other) => other._toMint() - this;

  int _mulFromInteger(other) => other._toMint() * this;

  int _modFromInteger(other) => other._toMint() % this;

  num _divFromInteger(other) => other._toMint() / this;

  int _truncDivFromInteger(other) => other._toMint() ~/ this;

  int _bitAndFromInteger(other) => other._toMint() &  this;

  int _bitOrFromInteger(other)  => other._toMint() |  this;

  int _bitXorFromInteger(other) => other._toMint() ^  this;

  int _bitShrFromInteger(other) => other._toMint() >> this;

  int _bitShlFromInteger(other) => other._toMint() << this;

  bool _compareEqFromInteger(other) => other._toMint() == this;

  bool _compareLtFromInteger(other) => other._toMint() <  this;

  bool _compareLeFromInteger(other) => other._toMint() <= this;

  bool _compareGtFromInteger(other) => other._toMint() >  this;

  bool _compareGeFromInteger(other) => other._toMint() >= this;
}
