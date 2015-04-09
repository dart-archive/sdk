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

// TODO(ajohnsen): Implement.
class _Random implements Random {
  _Random([int seed]);

  bool nextBool() {
    return false;
  }

  double nextDouble() {
    return 0.0;
  }

  int nextInt([int max]) {
    return 0;
  }
}

@patch double sin(num x) => fletch.double.sin(x.toDouble());

@patch double cos(num x) => fletch.double.cos(x.toDouble());

@patch double tan(num x) => fletch.double.tan(x.toDouble());

@patch double acos(num x) => fletch.double.acos(x.toDouble());

@patch double asin(num x) => fletch.double.asin(x.toDouble());

@patch double atan(num x) => fletch.double.atan(x.toDouble());

@patch double sqrt(num x) => fletch.double.sqrt(x.toDouble());

@patch double exp(num x) => fletch.double.exp(x.toDouble());

@patch double log(num x) => fletch.double.log(x.toDouble());

@patch double atan2(num a, num b) {
  return fletch.double.atan2(a.toDouble(), b.toDouble());
}

@patch double pow(num x, num exponent) {
  // TODO(ajohnsen): Implement integer pow logic.
  return fletch.double.pow(x.toDouble(), exponent.toDouble());
}
