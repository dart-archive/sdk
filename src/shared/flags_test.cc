// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>
#include "src/shared/assert.h"
#include "src/shared/flags.h"
#include "src/shared/test_case.h"

static const int argc = 8;
static const char* argv[argc] = {
    "fletch",
    "-Xon",
    "-Xtrue=true",
    "-Xfalse=false",
    "-Xint=123456",
    "-Xaddress=0x120120",
    "nothing",
    "-Xstring=\"value\""
};

namespace fletch {

TEST_CASE(Arguments) {
  // Make a copy of the arguments. This is necessary
  // because Flags::ExtractFromCommandLine modifies the arguments.
  char** values = reinterpret_cast<char**>(calloc(sizeof(char*), argc));
  for (int i = 0; i < argc; i++) {
    values[i] = reinterpret_cast<char*>(malloc(strlen(argv[i]) + 1));
    strcpy(values[i], argv[i]);  // NOLINT
  }

  // Parse the fake arguments
  int count = argc;
  Flags::ExtractFromCommandLine(&count, values);
  EXPECT_EQ(2, count);
  EXPECT_STREQ("fletch", values[0]);
  EXPECT_STREQ("nothing", values[1]);

#ifdef DEBUG
  EXPECT(Flags::IsOn("on"));
  EXPECT(Flags::IsOn("true"));

  bool b;
  EXPECT(Flags::IsBool("true", &b));
  EXPECT_EQ(true, b);

  EXPECT(Flags::IsBool("false", &b));
  EXPECT_EQ(false, b);

  int i;
  EXPECT(Flags::IsInt("int", &i));
  EXPECT_EQ(123456, i);

  uword a;
  EXPECT(Flags::IsAddress("address", &a));
  EXPECT_EQ(a, static_cast<uword>(0x120120));

  char* s;
  EXPECT(Flags::IsString("string", &s));
  EXPECT(strcmp(s, "\"value\"") == 0);
#endif
}

}  // namespace fletch
