// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

// Matches dart:core on Jan 21, 2015.
abstract class int extends num {
  // TODO(kasperl): We cannot express this.
  // const factory int.fromEnvironment(String name, {int defaultValue});

  num remainder(num other) {
    return this - (this ~/ other) * other;
  }

  bool get isNaN => false;

  bool get isNegative => this < 0;

  bool get isInfinite => false;

  bool get isFinite => true;

  int abs() => isNegative ? -this : this;

  int get sign {
    if (this > 0) return 1;
    if (this < 0) return -1;
    return 0;
  }

  int round() => this;

  int floor() => this;

  int ceil() => this;

  int truncate() => this;

  double roundToDouble() => this.toDouble();

  double floorToDouble() => this.toDouble();

  double ceilToDouble() => this.toDouble();

  double truncateToDouble() => this.toDouble();

  num clamp(num lowerLimit, num upperLimit) {
    throw new UnimplementedError("int.clamp");
  }

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

  static int parse(String source, {int radix, int onError(String source)}) {
    throw new UnimplementedError("int.parse");
  }

  int operator &(int other);

  int operator |(int other);

  int operator ^(int other);

  int operator ~();

  int operator <<(int shiftAmount);

  int operator >>(int shiftAmount);

  bool get isOdd => (this & 1) == 1;

  bool get isEven => (this & 1) == 0;

  int get bitLength {
    throw new UnimplementedError("int.bitLength");
  }

  int toUnsigned(int width) {
    throw new UnimplementedError("int.toUnsigned");
  }

  int toSigned(int width) {
    throw new UnimplementedError("int.toSigned");
  }

  int operator -();

  String toRadixString(int radix) {
    throw new UnimplementedError("int.toRadixString");
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
  double toDouble() native;
  String toString() native;

  int _toMint() native;

  num operator -() native;

  num operator +(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._addFromInteger(this);
  }

  num operator -(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._subFromInteger(this);
  }

  num operator *(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._mulFromInteger(this);
  }

  num operator %(num other) native catch (error) {
    switch (error) {
      case _wrongArgumentType:
        return other._modFromInteger(this);
      case _indexOutOfBounds:
        throw new IntegerDivisionByZeroException();
    }
  }

  num operator /(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._divFromInteger(this);
  }

  int operator ~/(num other) native catch (error) {
    switch (error) {
      case _wrongArgumentType:
        return other._truncDivFromInteger(this);
      case _indexOutOfBounds:
        throw new IntegerDivisionByZeroException();
    }
  }

  int operator ~() native;

  int operator &(int other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._bitAndFromInteger(this);
  }

  int operator |(int other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._bitOrFromInteger(this);
  }

  int operator ^(int other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._bitXorFromInteger(this);
  }

  int operator >>(int other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._bitShrFromInteger(this);
  }

  int operator <<(int other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._bitShlFromInteger(this);
  }

  bool operator ==(other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._compareEqFromInteger(this);
  }

  bool operator <(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._compareLtFromInteger(this);
  }

  bool operator <=(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._compareLeFromInteger(this);
  }

  bool operator >(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._compareGtFromInteger(this);
  }

  bool operator >=(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._compareGeFromInteger(this);
  }

  // In the following double-dispatch helpers, [other] might
  // be a small integer in case of overflows. Calling toMint()
  // on [other] isn't strictly necessary but it makes the
  // overflow case a litte bit faster.
  int _addFromInteger(int other) => other._toMint() + _toMint();
  int _subFromInteger(int other) => other._toMint() - _toMint();
  int _mulFromInteger(int other) => other._toMint() * _toMint();
  int _modFromInteger(int other) => other._toMint() % _toMint();
  num _divFromInteger(int other) => other._toMint() / _toMint();
  int _truncDivFromInteger(int other) => other._toMint() ~/ _toMint();

  int _bitAndFromInteger(int other) => other._toMint() &  _toMint();
  int _bitOrFromInteger(int other)  => other._toMint() |  _toMint();
  int _bitXorFromInteger(int other) => other._toMint() ^  _toMint();
  int _bitShrFromInteger(int other) => other._toMint() >> _toMint();
  int _bitShlFromInteger(int other) => other._toMint() << _toMint();

  bool _compareEqFromInteger(int other) => other._toMint() == _toMint();
  bool _compareLtFromInteger(int other) => other._toMint() <  _toMint();
  bool _compareLeFromInteger(int other) => other._toMint() <= _toMint();
  bool _compareGtFromInteger(int other) => other._toMint() >  _toMint();
  bool _compareGeFromInteger(int other) => other._toMint() >= _toMint();
}

class _Mint extends int {
  double toDouble() native;
  String toString() native;

  int _toMint() => this;

  num operator -() native;

  num operator +(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._addFromInteger(this);
  }

  num operator -(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._subFromInteger(this);
  }

  num operator *(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._mulFromInteger(this);
  }

  num operator %(num other) native catch (error) {
    switch (error) {
      case _wrongArgumentType:
        return other._modFromInteger(this);
      case _indexOutOfBounds:
        throw new IntegerDivisionByZeroException();
    }
  }

  num operator /(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._divFromInteger(this);
  }

  num operator ~/(num other) native catch (error) {
    switch (error) {
      case _wrongArgumentType:
        return other._truncDivFromInteger(this);
      case _indexOutOfBounds:
        throw new IntegerDivisionByZeroException();
    }
  }

  int operator ~() native;

  int operator &(int other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._bitAndFromInteger(this);
  }

  int operator |(int other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._bitOrFromInteger(this);
  }

  int operator ^(int other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._bitXorFromInteger(this);
  }

  int operator >>(int other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._bitShrFromInteger(this);
  }

  int operator <<(int other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._bitShlFromInteger(this);
  }

  bool operator ==(other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._compareEqFromInteger(this);
  }

  bool operator <(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._compareLtFromInteger(this);
  }

  bool operator <=(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._compareLeFromInteger(this);
  }

  bool operator >(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._compareGtFromInteger(this);
  }

  bool operator >=(num other) native catch (error) {
    // TODO(kasperl): Check error.
    return other._compareGeFromInteger(this);
  }

  int _addFromInteger(int other) => other._toMint() + this;
  int _subFromInteger(int other) => other._toMint() - this;
  int _mulFromInteger(int other) => other._toMint() * this;
  int _modFromInteger(int other) => other._toMint() % this;
  num _divFromInteger(int other) => other._toMint() / this;
  int _truncDivFromInteger(int other) => other._toMint() ~/ this;

  int _bitAndFromInteger(int other) => other._toMint() &  this;
  int _bitOrFromInteger(int other)  => other._toMint() |  this;
  int _bitXorFromInteger(int other) => other._toMint() ^  this;
  int _bitShrFromInteger(int other) => other._toMint() >> this;
  int _bitShlFromInteger(int other) => other._toMint() << this;

  bool _compareEqFromInteger(int other) => other._toMint() == this;
  bool _compareLtFromInteger(int other) => other._toMint() <  this;
  bool _compareLeFromInteger(int other) => other._toMint() <= this;
  bool _compareGtFromInteger(int other) => other._toMint() >  this;
  bool _compareGeFromInteger(int other) => other._toMint() >= this;
}
