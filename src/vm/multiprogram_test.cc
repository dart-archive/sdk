// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/flags.h"
#include "src/shared/test_case.h"

#include "include/fletch_api.h"

namespace fletch {

static void Main(int argc, char** argv) {
  Flags::ExtractFromCommandLine(&argc, argv);

  FletchSetup();

  if (argc == 1) FATAL("Expected 1 or more snapshots as argument");

  // TODO(kustermann): Implement multiprogram support.
  UNREACHABLE();

  FletchTearDown();
}

}  // namespace fletch

int main(int argc, char** argv) {
  fletch::Main(argc, argv);
  return 0;
}
