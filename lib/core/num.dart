// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

// Matches dart:core on Jan 21, 2015.
abstract class num implements Comparable<num> {
  int compareTo(num other);

  num operator +(num other);

  num operator -(num other);

  num operator *(num other);

  num operator %(num other);

  double operator /(num other);

  int operator ~/(num other);

  num operator -();

  num remainder(num other);

  bool operator <(num other);

  bool operator <=(num other);

  bool operator >(num other);

  bool operator >=(num other);

  bool get isNaN;

  bool get isNegative;

  bool get isInfinite;

  bool get isFinite;

  num abs();

  num get sign;

  int round();

  int floor();

  int ceil();

  int truncate();

  double roundToDouble();

  double floorToDouble();

  double ceilToDouble();

  double truncateToDouble();

  num clamp(num lowerLimit, num upperLimit);

  int toInt();

  double toDouble();

  String toStringAsFixed(int fractionDigits);

  String toStringAsExponential([int fractionDigits]);

  String toStringAsPrecision(int precision);

  static num parse(String input, [num onError(String input)]) {
    throw new UnimplementedError("num.parse");
  }
}
