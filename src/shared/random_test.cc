// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/shared/test_case.h"
#include "src/shared/random.h"

namespace fletch {

// Chi squared for getting m 0s out of n bits.
double ChiSquared(int m, int n) {
  double ys_minus_np1 = (m - n / 2.0);
  double chi_squared_1 = ys_minus_np1 * ys_minus_np1 * 2.0 / n;
  double ys_minus_np2 = ((n - m) - n / 2.0);
  double chi_squared_2 = ys_minus_np2 * ys_minus_np2 * 2.0 / n;
  return chi_squared_1 + chi_squared_2;
}

// Test for correlations between recent bits from the PRNG, or bits that are
// biased.
TEST_CASE(RandomBitCorrelations) {
  RandomXorShift rng(0);
#ifdef DEBUG
  const int kHistory = 2;
  const int kRepeats = 1000;
#else
  const int kHistory = 8;
  const int kRepeats = 10000;
#endif
  uint32 history[kHistory];
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
          history[i] = rng.NextUInt32();
        }

        // Find out how many of the bits are the same as the prediction bit.
        int m = 0;
        for (int i = 0; i < kRepeats; i++) {
          uint32 random = rng.NextUInt32();
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
          int percent = static_cast<int>(m * 100.0 / kRepeats);
          if (predictor_bit < 0) {
            printf("Bit %d is %d %d%% of the time\n", random_bit,
                   predictor_bit == -2 ? 0 : 1, percent);
          } else {
            printf("Bit %d is the same as bit %d %d ago %d%% of the time\n",
                   random_bit, predictor_bit, ago, percent);
          }
        }

        // For 1 degree of freedom this corresponds to 1 in a million.  We are
        // running ~8000 tests, so that would be surprising.
        EXPECT(chi_squared <= 24);

        // If the predictor bit is a fixed 0 or 1 then it makes no sense to
        // repeat the test with a different age.
        if (predictor_bit < 0) break;
      }
    }
  }
}

}  // namespace fletch
