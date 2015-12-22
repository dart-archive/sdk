// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/flags.h"
#include "src/shared/test_case.h"
#include "src/shared/platform.h"

#include "include/fletch_api.h"

namespace fletch {

static void PrintAndDie(char **argv) {
  FATAL1("Usage: %0 "
        "<parallel|sequence> [[<snapshot> <expected-exitcode>] ...]",
        argv[0]);
}

static void RunInParallel(int count, FletchProgram* programs, int* exitcodes) {
  FletchRunMultipleMain(count, programs, exitcodes);

  for (int i = 0; i < count; i++) {
    FletchDeleteProgram(programs[i]);
  }
}

static void RunInSequence(int count, FletchProgram* programs, int* exitcodes) {
  for (int i = 0; i < count; i++) {
    exitcodes[i] = FletchRunMain(programs[i]);
    FletchDeleteProgram(programs[i]);
  }
}

static int Main(int argc, char** argv) {
  Flags::ExtractFromCommandLine(&argc, argv);

  FletchSetup();

  if (argc <= 1 || (argc % 2) != 0) PrintAndDie(argv);

  bool parallel = strcmp(argv[1], "parallel") == 0;
  bool sequence = strcmp(argv[1], "sequence") == 0;
  if (!parallel && !sequence) PrintAndDie(argv);

  int program_count = (argc - 2) / 2;
  FletchProgram* programs = new FletchProgram[program_count];
  int* expected_exit_codes = new int[program_count];
  for (int i = 0; i < program_count; i++) {
    List<uint8> bytes = Platform::LoadFile(argv[2 + 2 * i]);
    if (bytes.is_empty()) FATAL("Invalid snapshot");
    programs[i] = FletchLoadSnapshot(bytes.data(), bytes.length());
    expected_exit_codes[i] = atoi(argv[2 + 2 * i + 1]);
    bytes.Delete();
  }

  int* actual_exitcodes = new int[program_count];
  if (parallel) {
    RunInParallel(program_count, programs, actual_exitcodes);
  } else if (sequence) {
    RunInSequence(program_count, programs, actual_exitcodes);
  } else {
    UNREACHABLE();
  }

  int result = 0;
  for (int i = 0; i < program_count; i++) {
    if (expected_exit_codes[i] != actual_exitcodes[i]) {
      fprintf(stderr, "%s: Expected exitcode: %d, Actual exitcode: %d\n",
          argv[2 + 2 * i], expected_exit_codes[i], actual_exitcodes[i]);
      result++;
    }
  }

  delete[] actual_exitcodes;
  delete[] expected_exit_codes;
  delete[] programs;

  FletchTearDown();

  return result;
}

}  // namespace fletch

int main(int argc, char** argv) { return fletch::Main(argc, argv); }
