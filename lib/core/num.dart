// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

abstract class num implements Comparable<num> {
  int compareTo(num other) {
    if (this == other) {
      return 0;
    } else if (this < other) {
      return -1;
    } else {
      return 1;
    }
  }

  bool get isFinite;
  bool get isInfinite;
  bool get isNaN;
  bool get isNegative;

  double toDouble();
  int toInt();

  num abs();
  num remainder(num other);

  int ceil();
  double ceilToDouble();

  int floor();
  double floorToDouble();

  int round();
  double roundToDouble();

  int truncate();
  double truncateToDouble();

  String toStringAsFixed(int fractionDigits);
  String toStringAsExponential([int fractionDigits]);
  String toStringAsPrecision(int precision);
}
