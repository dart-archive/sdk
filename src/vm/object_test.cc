// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>
#include <stdlib.h>

#include "src/shared/assert.h"
#include "src/shared/flags.h"
#include "src/shared/test_case.h"

#include "src/vm/object.h"
#include "src/vm/program.h"

namespace fletch {

static void CheckValidSmi(word value) {
  EXPECT(Smi::IsValid(value));
  EXPECT_EQ(Smi::FromWord(value)->value(), value);
}

static void CheckInvalidSmi(word value) {
  EXPECT(!Smi::IsValid(value));
}

TEST_CASE(Smi) {
  CheckValidSmi(0);
  CheckValidSmi(-1);
  CheckValidSmi(1);
  CheckValidSmi(Smi::kMinValue);
  CheckValidSmi(Smi::kMaxValue);

  CheckInvalidSmi(Smi::kMinValue - 1);
  CheckInvalidSmi(Smi::kMaxValue + 1);
}

}  // namespace fletch
