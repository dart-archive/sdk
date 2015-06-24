// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>

#include "src/shared/asan_helper.h"
#include "src/shared/assert.h"
#include "src/shared/flags.h"
#include "src/shared/test_case.h"

static const int argc = 3;
static const char* argv[argc] = {
    "fletch",
    "-Xverbose",
    "nothing",
};

namespace fletch {

TEST_CASE(Arguments) {
#ifdef USING_ADDRESS_SANITIZER
__lsan_disable();
#endif
  // Make a copy of the arguments. This is necessary
  // because Flags::ExtractFromCommandLine modifies the arguments.
  char** values = reinterpret_cast<char**>(calloc(sizeof(char*), argc));
  for (int i = 0; i < argc; i++) {
    values[i] = reinterpret_cast<char*>(malloc(strlen(argv[i]) + 1));
    strcpy(values[i], argv[i]);  // NOLINT
  }
#ifdef USING_ADDRESS_SANITIZER
__lsan_enable();
#endif

  // Parse the fake arguments
  int count = argc;
  Flags::ExtractFromCommandLine(&count, values);
  EXPECT_EQ(2, count);
  EXPECT_STREQ("fletch", values[0]);
  EXPECT_STREQ("nothing", values[1]);
  EXPECT(Flags::verbose);
}

}  // namespace fletch
