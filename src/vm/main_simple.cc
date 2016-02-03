// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef DARTINO_ENABLE_LIVE_CODING

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

#include "include/dartino_api.h"

#include "src/shared/flags.h"
#include "src/shared/list.h"
#include "src/shared/utils.h"
#include "src/shared/platform.h"

namespace dartino {

static bool IsSnapshot(List<uint8> snapshot) {
  return snapshot.length() > 2 && snapshot[0] == 0xbe && snapshot[1] == 0xef;
}

static int Main(int argc, char** argv) {
  Flags::ExtractFromCommandLine(&argc, argv);
  DartinoSetup();

  int program_count = argc - 1;

  DartinoProgram* programs = new DartinoProgram[program_count];

  for (int i = 0; i < program_count; i++) {
    // Handle the arguments.
    const char* input = argv[i + 1];
    List<uint8> bytes = Platform::LoadFile(input);
    if (!IsSnapshot(bytes)) {
      FATAL("The input file is not a dartino snapshot.");
    }

    DartinoProgram program = DartinoLoadSnapshot(bytes.data(), bytes.length());
    programs[i] = program;
  }

  int result = DartinoRunMultipleMain(program_count, programs);

  for (int i = 0; i < program_count; i++) {
    DartinoDeleteProgram(programs[i]);
  }

  delete[] programs;

  DartinoTearDown();
  return result;
}

}  // namespace dartino

// Forward main calls to dartino::Main.
int main(int argc, char** argv) { return dartino::Main(argc, argv); }

#endif  // !DARTINO_ENABLE_LIVE_CODING
