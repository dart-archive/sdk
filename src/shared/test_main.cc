// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/flags.h"
#include "src/shared/dartino.h"
#include "src/shared/test_case.h"

namespace dartino {

static void Main(int argc, char** argv) {
  Flags::ExtractFromCommandLine(&argc, argv);
  Dartino::Setup();
  TestCase::RunAll();
  Dartino::TearDown();
}

}  // namespace dartino

int main(int argc, char** argv) {
  dartino::Main(argc, argv);
  return 0;
}
