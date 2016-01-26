// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch._system' as fletch;
import 'dart:fletch._system' show patch;

@patch class Random {
  @patch factory Random([int seed]) {
    return new _Random(seed);
  }
}


// Implements the same XorShift+ algorithm as random.h.  Splits 64 bit values
// into three 23 bit parts, in order to keep everything in smis.
class _Random implements Random {
  // The lower parts are exactly 23 bits, and the top part is 18 bits, making
  // 64 bits in all.
  static const kBitsPerPart = 23;
  static const kLowMask = (1 << kBitsPerPart) - 1;
  static const kMediumMask = (1 << (kBitsPerPart * 2)) - 1;
  static final _seeder = new _Random(15485863);

  _Random([int seed]) {
    if (seed == null) seed = _seeder.nextInt(10000000);
    seed ^= 314159265;
    _s0_0 = seed & kLowMask;
    _s0_1 = (seed >> kBitsPerPart) & kLowMask;
    _s0_2 = (seed >> (kBitsPerPart * 2)) & kLowMask;
    _s1_0 = 271828182 & kLowMask;
    _s1_1 = 271828182 >> kBitsPerPart;
    _s1_2 = 0;
    _y0 = 0;
    _y1 = 0;
    _y2 = 0;
  }

  bool nextBool() {
    _nextInt64();
    // Use the lowest bit of x + y.
    return ((_s1_0 + _y0) & 1) != 0;
  }

  // TODO(erikcorry): A native helper could just put the bits in the mantissa
  // and avoid the floating point divisions.
  // Returns uniformly distributed doubles in [0..1[.
  double nextDouble() {
    _nextInt64();
    // Use x + y as the mantissa.
    const kMantissaBits = 52;  // Enough for double.
    int mantissa = (_s1_0 + _y0) & kLowMask;
    mantissa += ((_s1_1 + _y1) & kLowMask) << kBitsPerPart;
    int mantissa_top =
        (_s1_2 + _y2) & ((1 << (kMantissaBits - 2 * kBitsPerPart)) - 1);
    mantissa += mantissa_top << (2 * kBitsPerPart);
    return mantissa / (1 << kMantissaBits);
  }

  // There are some 64 bit assumptions here.  Probably won't work for larger
  // numbers when we support them.
  int nextInt(int max) {
    int mask = max - 1;
    bool is_power_of_2 = (mask & max) == 0;
    if (!is_power_of_2) {
      // Bit smearing.
      mask |= mask >> 32;
      mask |= mask >> 16;
      mask |= mask >> 8;
      mask |= mask >> 4;
      mask |= mask >> 2;
      mask |= mask >> 1;
    }
    // Implementation with no modulus operation.  For max values that are not
    // powers of 2, this may run more than one iteration, but < 2 on average.
    while (true) {
      _nextInt64();
      int answer = (_s1_0 + _y0) & mask;
      if (mask > kLowMask) {
        answer += ((_s1_1 + _y1) & (mask >> kBitsPerPart)) << kBitsPerPart;
        if (mask > kMediumMask) {
          int shift = 2 * kBitsPerPart;
          answer += ((_s1_2 + _y2) & (mask >> shift)) << shift;
        }
      }
      if (answer < max) return answer;
    }
  }

  void _nextInt64() {
    // uint64 x = s0.
    int x0 = _s0_0;
    int x1 = _s0_1;
    int x2 = _s0_2;
    // uint64 y = s1.
    _y0 = _s1_0;
    _y1 = _s1_1;
    _y2 = _s1_2;
    // s0 = y.
    _s0_0 = _y0;
    _s0_1 = _y1;
    _s0_2 = _y2;
    // Here and a few more places we assume that each part is 23 bits.
    // x ^= x << 23.
    x2 = (x2 ^ x1) & 0x3ffff;
    x1 ^= x0;
    // x ^= x >> 17.
    x0 ^= x0 >> 17;
    x0 ^= (x1 & 0x1ffff) << 6;
    x1 ^= x1 >> 17;
    x1 ^= (x2 & 0x1ffff) << 6;
    x2 ^= x2 >> 17;
    // x ^= y.
    x0 ^= _y0;
    x1 ^= _y1;
    x2 ^= _y2;
    // x ^= y >> 26.
    x0 ^= _y1 >> 3;
    x0 ^= (_y2 & 7) << 20;
    x1 ^= _y2 >> 3;
    // s1 = x.
    _s1_0 = x0;
    _s1_1 = x1;
    _s1_2 = x2;
  }

  // Y from most recent call.
  int _y0;
  int _y1;
  int _y2;
  // Actual PRNG state, in smis.
  int _s0_0;  // Low bits.
  int _s0_1;  // Medium bits.
  int _s0_2;  // High bits.
  // S1 is also the most recent x.
  int _s1_0;  // Low bits.
  int _s1_1;  // Medium bits.
  int _s1_2;  // High bits.
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

@patch num pow(num x, num exponent) {
  if ((x is int) && (exponent is int) && (exponent >= 0)) {
    return _intPow(x, exponent);
  }
  return _doublePow(x.toDouble(), exponent.toDouble());
}

double _doublePow(double base, double exponent) {
  if (exponent == 0.0) {
    return 1.0;  // ECMA-262 15.8.2.13
  }
  // Speed up simple cases.
  if (exponent == 1.0) return base;
  if (exponent == 2.0) return base * base;
  if (exponent == 3.0) return base * base * base;

  if (base == 1.0) return 1.0;

  if (base.isNaN || exponent.isNaN) {
    return double.NAN;
  }
  if ((base != -double.INFINITY) && (exponent == 0.5)) {
    if (base == 0.0) {
      return 0.0;
    }
    return sqrt(base);
  }
  return _pow(base, exponent);
}

int _intPow(int base, int exponent) {
  // Exponentiation by squaring.
  int result = 1;
  while (exponent != 0) {
    if ((exponent & 1) == 1) {
      result *= base;
    }
    exponent >>= 1;
    // Skip unnecessary operation (can overflow to Mint or Bigint).
    if (exponent != 0) {
      base *= base;
    }
  }
  return result;
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
