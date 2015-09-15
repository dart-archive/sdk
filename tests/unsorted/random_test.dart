// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:math';
import 'package:expect/expect.dart';

// Chi squared for getting m 0s out of n bits.
double ChiSquared(int m, int n) {
  double ys_minus_np1 = (m - n/2.0);
  double chi_squared_1 = ys_minus_np1 * ys_minus_np1 * 2.0 / n;
  double ys_minus_np2 = ((n - m) - n/2.0);
  double chi_squared_2 = ys_minus_np2 * ys_minus_np2 * 2.0 / n;
  return chi_squared_1 + chi_squared_2;
}

// Chi squared for three different outcomes.
double TripleChiSquared(int m1, int m2, int m3, int n) {
  Expect.equals(m1 + m2 + m3, n);
  double ys_minus_np1 = (m1 - n/3.0);
  double chi_squared_1 = ys_minus_np1 * ys_minus_np1 * 3.0 / n;
  double ys_minus_np2 = (m2 - n/3.0);
  double chi_squared_2 = ys_minus_np2 * ys_minus_np2 * 3.0 / n;
  double ys_minus_np3 = (m3 - n/3.0);
  double chi_squared_3 = ys_minus_np3 * ys_minus_np3 * 3.0 / n;
  return chi_squared_1 + chi_squared_2 + chi_squared_3;
}

// Test that this implementation produces the same numbers as the
// the more straightforward C++ implementation.
void SeedOutput() {
  Random rng = new Random(0);
  Expect.equals(rng.nextInt(1 << 32), 211425861);
  Expect.equals(rng.nextInt(1 << 32), 2254041230);
  Expect.equals(rng.nextInt(1 << 32), 4289937472);
  Random rng2 = new Random(987654321);
  Expect.equals(rng2.nextInt(1 << 32), 970314183);
  Expect.equals(rng2.nextInt(1 << 32), 2232293669);
  Expect.equals(rng2.nextInt(1 << 32), 3617633398);
}


// Test for correlations between recent bits from the PRNG, or bits that are
// biased.
void BitCorrelations() {
  Random rng = new Random(0);
  const kHistory = 2;
  const kRepeats = 1000;
  List<int> history = new List<int>(kHistory);
  // The predictor bit is either constant 0 or 1, or one of the bits from the
  // history.
  for (int predictor_bit = -2; predictor_bit < 32; predictor_bit++) {
    // The predicted bit is one of the bits from the PRNG.
    for (int random_bit = 0; random_bit < 32; random_bit++) {
      // The predicted bit is taken from the previous output of the PRNG.
      for (int ago = 0; ago < kHistory; ago++) {
        // We don't want to check whether each bit predicts itself.
        if (ago == 0 && predictor_bit == random_bit) continue;

        // Enter the new random value into the history
        for (int i = ago; i >= 0; i--) {
          history[i] = rng.nextInt(0x100000000);
        }

        // Find out how many of the bits are the same as the prediction bit.
        int m = 0;
        for (int i = 0; i < kRepeats; i++) {
          int random = rng.nextInt(0x100000000);
          for (int j = ago - 1; j >= 0; j--) history[j + 1] = history[j];
          history[0] = random;

          int predicted;
          if (predictor_bit >= 0) {
            predicted = (history[ago] >> predictor_bit) & 1;
          } else {
            predicted = predictor_bit == -2 ? 0 : 1;
          }
          int bit = (random >> random_bit) & 1;
          if (bit == predicted) m++;
        }

        // Chi squared analysis for k = 2 (2, states: same/not-same) and one
        // degree of freedom (k - 1).
        double chi_squared = ChiSquared(m, kRepeats);
        if (chi_squared > 24) {
          int percent = (m * 100.0 / kRepeats).floor();
          if (predictor_bit < 0) {
            int expected = predictor_bit == -2 ? 0 : 1;
            print("Bit $random_bit is $expected $percent% of the time\n");
          } else {
            print("Bit $random_bit is the same as bit $predictor_bit "
                  "$ago ago $percent% of the time\n");
          }
        }

        // For 1 degree of freedom this corresponds to 1 in a million.  We are
        // running ~8000 tests, so that would be surprising.
        Expect.isTrue(chi_squared <= 24);

        // If the predictor bit is a fixed 0 or 1 then it makes no sense to
        // repeat the test with a different age.
        if (predictor_bit < 0) break;
      }
    }
  }
}

void GetBoolTest() {
  Random rng = new Random(0);
  while (true) {
    bool x = rng.nextBool();
    Expect.isTrue(x == true || x == false);
    if (x == true) break;
  }
  while (true) {
    bool x = rng.nextBool();
    Expect.isTrue(x == true || x == false);
    if (x == false) break;
  }
}

void GetDoubleTest() {
  Random rng = new Random(0);
  while (true) {
    num x = rng.nextDouble();
    Expect.isTrue(x is num);
    Expect.isTrue(x >= 0);
    Expect.isTrue(x < 1);
    if (x < 0.01) break;
  }
  while (true) {
    num x = rng.nextDouble();
    Expect.isTrue(x is num);
    Expect.isTrue(x >= 0);
    Expect.isTrue(x < 1);
    if (x > 0.99) break;
  }
}

void NonPowerOfTwoTest() {
  Random rng = new Random(0);
  const kRepeats = 1000;
  var counts = new List<int>.filled(3, 0);
  for (int i = 0; i < kRepeats; i++) {
    int r = rng.nextInt(3);
    Expect.isTrue(r is int);
    counts[r] = counts[r] + 1;
  }
  double chi_squared =
      TripleChiSquared(counts[0], counts[1], counts[2], kRepeats);
  // About 0.5% chance.
  Expect.isTrue(chi_squared < 10);
}

void main() {
  BitCorrelations();
  GetBoolTest();
  GetDoubleTest();
  NonPowerOfTwoTest();
  SeedOutput();
}

