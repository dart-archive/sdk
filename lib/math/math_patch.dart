// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:_fletch_system' as fletch;

const patch = "patch";

@patch class Random {
  @patch factory Random([int seed]) {
    return new _Random(seed);
  }
}

/// This class implements a LCG (Linear Congruential Generator) pseudo random
/// number generator.
class _Random implements Random {
  static const int _A = 1103515245;
  static const int _C = 12345;
  int _state;

  _Random([int seed]) {
    if (seed == null) seed = new Object().hashCode;
    _state = seed;
  }

  bool nextBool() {
    return nextInt() & 1 == 0;
  }

  double nextDouble() {
    const int INT_MAX = 2147483647;
    return nextInt(INT_MAX) / INT_MAX;
  }

  int nextInt([int max]) {
    _state = (_state * _A + _C) & 0x3FFFFFFF;
    if (max != null) return _state % max;
    return _state;
  }
}

@patch double sin(num x) => _sin(x.toDouble());

@patch double cos(num x) => _cos(x.toDouble());

@patch double tan(num x) => _tan(x.toDouble());

@patch double acos(num x) => _acos(x.toDouble());

@patch double asin(num x) => _asin(x.toDouble());

@patch double atan(num x) => _atan(x.toDouble());

@patch double sqrt(num x) => _sqrt(x.toDouble());

@patch double exp(num x) => _exp(x.toDouble());

@patch double log(num x) => _log(x.toDouble());

@patch double atan2(num a, num b) => _atan2(a.toDouble(), b.toDouble());

@patch double pow(num x, num exponent) {
  // TODO(ajohnsen): Implement integer pow logic.
  return _pow(x.toDouble(), exponent.toDouble());
}

@fletch.native external double _sin(double x);

@fletch.native external double _cos(double x);

@fletch.native external double _tan(double x);

@fletch.native external double _acos(double x);

@fletch.native external double _asin(double x);

@fletch.native external double _atan(double x);

@fletch.native external double _sqrt(double x);

@fletch.native external double _exp(double x);

@fletch.native external double _log(double x);

@fletch.native external double _atan2(double a, double b);

@fletch.native external double _pow(double x, double exponent);
