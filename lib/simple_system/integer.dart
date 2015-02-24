// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.system;

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
    if (error == _wrongArgumentType && other is _Mint) {
      // TODO(ajohnsen): Add bigint support.
      throw new UnimplementedError("Overflow to big integer");
    }
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
