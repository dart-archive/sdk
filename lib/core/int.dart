// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core_patch;

abstract class _IntBase implements int {
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

  int _toBigint();

  static const _digitString = "0123456789abcdefghijklmnopqrstuvwxyz";

  String toRadixString(int radix) {
    if (radix < 2 || radix > 36) {
      throw new ArgumentError(radix);
    }
    if (radix & (radix - 1) == 0) {
      return _toPow2String(radix);
    }
    if (radix == 10) return this.toString();
    final bool isNegative = this < 0;
    int value = isNegative ? -this : this;
    List temp = new List();
    do {
      int digit = value % radix;
      value ~/= radix;
      temp.add(_digitString.codeUnitAt(digit));
    } while (value > 0);
    if (isNegative) temp.add(0x2d);  // '-'.

    _OneByteString string = new _OneByteString(temp.length);
    for (int i = 0, j = temp.length; j > 0; i++) {
      string._setCodeUnitAt(i, temp[--j]);
    }
    return string;
  }

  String _toPow2String(int radix) {
    int value = this;
    if (value == 0) return "0";
    assert(radix & (radix - 1) == 0);
    var negative = value < 0;
    var bitsPerDigit = radix.bitLength - 1;
    var length = 0;
    if (negative) {
      value = -value;
      length = 1;
    }
    // Integer division, rounding up, to find number of digits.
    length += (value.bitLength + bitsPerDigit - 1) ~/ bitsPerDigit;

    _OneByteString string = new _OneByteString(length);
    string._setCodeUnitAt(0, 0x2d);  // '-'. Is overwritten if not negative.
    var mask = radix - 1;
    do {
      string._setCodeUnitAt(--length, _digitString.codeUnitAt(value & mask));
      value >>= bitsPerDigit;
    } while (value > 0);
    return string;
  }

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
  int modPow(int exponent, int modulus) {
    if (exponent is! int) {
      throw new ArgumentError.value(exponent, "exponent", "not an integer");
    }
    if (modulus is! int) {
      throw new ArgumentError.value(modulus, "modulus", "not an integer");
    }
    if (exponent < 0) throw new RangeError.range(exponent, 0, null, "exponent");
    if (modulus <= 0) throw new RangeError.range(modulus, 1, null, "modulus");
    if (exponent == 0) return 1;
    if (fletch.enableBigint) {
      return this._toBigint().modPow(exponent, modulus);
    } else {
      throw new UnimplementedError();
    }
  }

  int modInverse(int modulus) {
    if (modulus is! int) {
      throw new ArgumentError.value(modulus, "modulus", "not an integer");
    }
    if (modulus <= 0) throw new RangeError.range(modulus, 1, null, "modulus");
    if (modulus == 1) return 0;
    if (fletch.enableBigint) {
      return this._toBigint().modInverse(modulus);
    } else {
      throw new UnimplementedError();
    }
  }

  int gcd(int other) {
    if (other is! int) {
      throw new ArgumentError.value(other, "other", "not an integer");
    }
    int x = this.abs();
    int y = other.abs();
    if (x == 0) return y;
    if (y == 0) return x;
    if ((x == 1) || (y == 1)) return 1;
    if (fletch.enableBigint) {
      return this._toBigint().gcd(other);
    } else {
      throw new UnimplementedError();
    }
  }

  bool get isEven => (this & 1) == 0;

  bool get isOdd => (this & 1) == 1;

  int get bitLength {
    int value = this < 0 ? ~this : this;
    int length = 0;
    // Shift by 8.
    while (true) {
      int rem = value >> 8;
      if (rem == 0) break;
      value = rem;
      length += 8;
    }
    // Shift remaining by 1.
    while (value != 0) {
      value >>= 1;
      length++;
    }
    return length;
  }

  toUnsigned(width) => this & ((1 << width) - 1);

  toSigned(width) {
    int signMask = 1 << (width - 1);
    return (this & (signMask - 1)) - (this & signMask);
  }

  // From num.
  clamp(lowerLimit, upperLimit) {
    if (lowerLimit is! num) {
      throw new ArgumentError.value(lowerLimit, "lowerLimit");
    }
    if (upperLimit is! num) {
      throw new ArgumentError.value(upperLimit, "upperLimit");
    }

    // Special case for integers.
    if (lowerLimit is int && upperLimit is int &&
        lowerLimit <= upperLimit) {
      if (this < lowerLimit) return lowerLimit;
      if (this > upperLimit) return upperLimit;
      return this;
    }
    // Generic case involving doubles, and invalid integer ranges.
    if (lowerLimit.compareTo(upperLimit) > 0) {
      throw new RangeError.range(upperLimit, lowerLimit, null, "upperLimit");
    }
    if (lowerLimit.isNaN) return lowerLimit;
    // Note that we don't need to care for -0.0 for the lower limit.
    if (this < lowerLimit) return lowerLimit;
    if (this.compareTo(upperLimit) > 0) return upperLimit;
    return this;
  }

  double _addFromDouble(double other) => other + toDouble();

  double _subFromDouble(double other) => other - toDouble();

  double _mulFromDouble(double other) => other * toDouble();

  double _modFromDouble(double other) => other % toDouble();

  double _divFromDouble(double other) => other / toDouble();

  int _truncDivFromDouble(double other) => other ~/ toDouble();

  bool _compareEqFromDouble(double other) => other == toDouble();

  bool _compareLtFromDouble(double other) => other <  toDouble();

  bool _compareLeFromDouble(double other) => other <= toDouble();

  bool _compareGtFromDouble(double other) => other >  toDouble();

  bool _compareGeFromDouble(double other) => other >= toDouble();

  double _remainderFromDouble(double other) => other.remainder(toDouble());
}

class _Smi extends _IntBase {
  int get hashCode => identityHashCode(this);

  @fletch.native external String toString();

  @fletch.native external double toDouble();

  @fletch.native external int _toMint();

  int _toBigint() {
    if (fletch.enableBigint) {
      return new _Bigint._fromInt(this);
    } else {
      throw new UnimplementedError();
    }
  }

  int _toBigintOrDouble() {
    if (fletch.enableBigint) {
      return new _Bigint._fromInt(this);
    } else {
      throw new UnimplementedError();
    }
  }

  @fletch.native num operator -() {
    return -_toMint();
  }

  @fletch.native num operator +(other) {
    // TODO(kasperl): Check error.
    return other._addFromInteger(this);
  }

  @fletch.native num operator -(other) {
    // TODO(kasperl): Check error.
    return other._subFromInteger(this);
  }

  @fletch.native num operator *(other) {
    // TODO(kasperl): Check error.
    return other._mulFromInteger(this);
  }

  @fletch.native num operator %(other) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        return other._modFromInteger(this);
      case fletch.indexOutOfBounds:
        throw new IntegerDivisionByZeroException();
    }
  }

  @fletch.native num operator /(other) {
    // TODO(kasperl): Check error.
    return other._divFromInteger(this);
  }

  @fletch.native int operator ~/(other) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        return other._truncDivFromInteger(this);
      case fletch.indexOutOfBounds:
        throw new IntegerDivisionByZeroException();
    }
  }

  @fletch.native external int operator ~();

  @fletch.native int operator &(other) {
    // TODO(kasperl): Check error.
    return other._bitAndFromInteger(this);
  }

  @fletch.native int operator |(other) {
    // TODO(kasperl): Check error.
    return other._bitOrFromInteger(this);
  }

  @fletch.native int operator ^(other) {
    // TODO(kasperl): Check error.
    return other._bitXorFromInteger(this);
  }

  @fletch.native int operator >>(other) {
    // TODO(kasperl): Check error.
    return other._bitShrFromInteger(this);
  }

  @fletch.native int operator <<(other) {
    // TODO(kasperl): Check error.
    return other._bitShlFromInteger(this);
  }

  @fletch.native bool operator ==(other) {
    if (other is! num) return false;
    // TODO(kasperl): Check error.
    return other._compareEqFromInteger(this);
  }

  @fletch.native bool operator <(other) {
    // TODO(kasperl): Check error.
    return other._compareLtFromInteger(this);
  }

  @fletch.native bool operator <=(other) {
    // TODO(kasperl): Check error.
    return other._compareLeFromInteger(this);
  }

  @fletch.native bool operator >(other) {
    // TODO(kasperl): Check error.
    return other._compareGtFromInteger(this);
  }

  @fletch.native bool operator >=(other) {
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

class _Mint extends _IntBase {
  int get hashCode => identityHashCode(this);

  @fletch.native external String toString();

  @fletch.native external double toDouble();

  int _toMint() => this;

  int _toBigint() {
    if (fletch.enableBigint) {
      return new _Bigint._fromInt(this);
    } else {
      throw new UnimplementedError();
    }
  }

  int _toBigintOrDouble() {
    if (fletch.enableBigint) {
      return new _Bigint._fromInt(this);
    } else {
      throw new UnimplementedError();
    }
  }

  @fletch.native num operator -() {
    if (fletch.enableBigint) {
      return -_toBigint();
    } else {
      throw new UnimplementedError('Overflow to big integer');
    }
  }

  @fletch.native num operator +(other) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        return other._addFromInteger(this);
      case fletch.indexOutOfBounds:
        if (fletch.enableBigint) {
          return other._toBigint()._addFromInteger(this);
        } else {
          throw new UnimplementedError('Overflow to big integer');
        }
    }
  }

  @fletch.native num operator -(other) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        return other._subFromInteger(this);
      case fletch.indexOutOfBounds:
        if (fletch.enableBigint) {
          return other._toBigint()._subFromInteger(this);
        } else {
          throw new UnimplementedError('Overflow to big integer');
        }
    }
  }

  @fletch.native num operator *(other) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        return other._mulFromInteger(this);
      case fletch.indexOutOfBounds:
        if (fletch.enableBigint) {
          return other._toBigint()._mulFromInteger(this);
        } else {
          throw new UnimplementedError('Overflow to big integer');
        }
    }
  }

  @fletch.native num operator %(other) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        return other._modFromInteger(this);
      case fletch.indexOutOfBounds:
        if (fletch.enableBigint) {
          return other._toBigint()._modFromInteger(this);
        } else {
          throw new UnimplementedError('Overflow to big integer');
        }
      case fletch.illegalState:
        throw new IntegerDivisionByZeroException();
    }
  }

  @fletch.native num operator /(other) {
    // TODO(kasperl): Check error.
    return other._divFromInteger(this);
  }

  @fletch.native int operator ~/(other) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        return other._truncDivFromInteger(this);
      case fletch.indexOutOfBounds:
        if (fletch.enableBigint) {
          return other._toBigint()._truncDivFromInteger(this);
        } else {
          throw new UnimplementedError('Overflow to big integer');
        }
      case fletch.illegalState:
        throw new IntegerDivisionByZeroException();
    }
  }

  @fletch.native external int operator ~();

  @fletch.native int operator &(other) {
    // TODO(kasperl): Check error.
    return other._bitAndFromInteger(this);
  }

  @fletch.native int operator |(other) {
    // TODO(kasperl): Check error.
    return other._bitOrFromInteger(this);
  }

  @fletch.native int operator ^(other) {
    // TODO(kasperl): Check error.
    return other._bitXorFromInteger(this);
  }

  @fletch.native int operator >>(other) {
    // TODO(kasperl): Check error.
    return other._bitShrFromInteger(this);
  }

  @fletch.native int operator <<(other) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        return other._bitShlFromInteger(this);
      case fletch.indexOutOfBounds:
        if (fletch.enableBigint) {
          return other._toBigint()._bitShlFromInteger(this);
        } else {
          throw new UnimplementedError('Overflow to big integer');
        }
    }
  }

  @fletch.native bool operator ==(other) {
    if (other is! num) return false;
    // TODO(kasperl): Check error.
    return other._compareEqFromInteger(this);
  }

  @fletch.native bool operator <(other) {
    // TODO(kasperl): Check error.
    return other._compareLtFromInteger(this);
  }

  @fletch.native bool operator <=(other) {
    // TODO(kasperl): Check error.
    return other._compareLeFromInteger(this);
  }

  @fletch.native bool operator >(other) {
    // TODO(kasperl): Check error.
    return other._compareGtFromInteger(this);
  }

  @fletch.native bool operator >=(other) {
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
