// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.system;

// TODO(ajohnsen): Rename to e.g. _IntImpl when old compiler is out.
abstract class int implements core.int {
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

  abs() {
    throw "abs() isn't implemented";
  }

  get sign {
    throw "get sign isn't implemented";
  }

  round() {
    throw "round() isn't implemented";
  }

  floor() {
    throw "floor() isn't implemented";
  }

  ceil() {
    throw "ceil() isn't implemented";
  }

  truncate() {
    throw "truncate() isn't implemented";
  }

  roundToDouble() {
    throw "roundToDouble() isn't implemented";
  }

  floorToDouble() {
    throw "floorToDouble() isn't implemented";
  }

  ceilToDouble() {
    throw "ceilToDouble() isn't implemented";
  }

  truncateToDouble() {
    throw "truncateToDouble() isn't implemented";
  }

  toRadixString(radix) {
    throw "toRadixString(radix) isn't implemented";
  }

  // From num.
  compareTo(other) {
    throw "compareTo(other) isn't implemented";
  }

  remainder(other) {
    throw "remainder(other) isn't implemented";
  }

  get isNaN {
    throw "get isNaN isn't implemented";
  }

  get isNegative {
    throw "get isNegative isn't implemented";
  }

  get isInfinite {
    throw "get isInfinite isn't implemented";
  }

  get isFinite {
    throw "get isFinite isn't implemented";
  }

  clamp(lowerLimit, upperLimit) {
    throw "clamp(lowerLimit, upperLimit) isn't implemented";
  }

  toInt() {
    throw "toInt() isn't implemented";
  }

  toDouble() {
    throw "toDouble() isn't implemented";
  }

  toStringAsFixed(fractionDigits) {
    throw "toStringAsFixed(fractionDigits) isn't implemented";
  }

  toStringAsExponential([fractionDigits]) {
    throw "toStringAsExponential([fractionDigits]) isn't implemented";
  }

  toStringAsPrecision(precision) {
    throw "toStringAsPrecision(precision) isn't implemented";
  }
}

class _Smi extends int {
  int get hashCode => this;

  @native external String toString();

  @native external num operator -();
  @native external num operator +(num other);
  @native external num operator -(num other);
  @native external num operator *(num other);
  @native external num operator /(num other);
  @native external int operator ~/(num other);
  @native external num operator %(num other);

  @native external int operator ~();
  @native external int operator &(int other);
  @native external int operator |(int other);
  @native external int operator ^(int other);
  @native external int operator >>(int other);
  @native external int operator <<(int other);

  @native external bool operator ==(other);
  @native external bool operator <(num other);
  @native external bool operator <=(num other);
  @native external bool operator >(num other);
  @native external bool operator >=(num other);
}

class _Mint extends int {
  int get hashCode => this;

  @native external String toString();

  @native external num operator -();
  @native external num operator +(num other);
  @native external num operator -(num other);
  @native external num operator *(num other);
  @native external num operator /(num other);
  @native external int operator ~/(num other);
  @native external num operator %(num other);

  @native external int operator ~();
  @native external int operator &(int other);
  @native external int operator |(int other);
  @native external int operator ^(int other);
  @native external int operator >>(int other);
  @native external int operator <<(int other);

  @native external bool operator ==(other);
  @native external bool operator <(num other);
  @native external bool operator <=(num other);
  @native external bool operator >(num other);
  @native external bool operator >=(num other);
}
