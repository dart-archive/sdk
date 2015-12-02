// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/flags.h"
#include "src/shared/test_case.h"
#include "src/shared/platform.h"

#include "include/fletch_api.h"

namespace fletch {

static int Main(int argc, char** argv) {
  Flags::ExtractFromCommandLine(&argc, argv);

  FletchSetup();

  if (argc == 1) FATAL("Expected 1 or more snapshots as argument");

  int program_count = argc - 1;
  FletchProgram* programs = new FletchProgram[program_count];
  for (int i = 0; i < program_count; i++) {
    List<uint8> bytes = Platform::LoadFile(argv[1 + i]);
    if (bytes.is_empty()) FATAL("Invalid snapshot");
    programs[i] = FletchLoadSnapshot(bytes.data(), bytes.length());
    bytes.Delete();
  }

  int result = FletchRunMultipleMain(program_count, programs);

  for (int i = 0; i < program_count; i++) {
    FletchDeleteProgram(programs[i]);
  }

  delete[] programs;

  FletchTearDown();

  return result;
}

}  // namespace fletch

int main(int argc, char** argv) {
  return fletch::Main(argc, argv);
}
