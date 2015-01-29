// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "person_shared.h"
#include "cc/person_counter.h"

#include <cstdio>

static void InteractWithService() {
  PersonCounter::Setup();
  printf("Counting: %d\n", PersonCounter::Count(new Person()));
  PersonCounter::TearDown();
}

int main(int argc, char** argv) {
  if (argc < 2) {
    printf("Usage: %s <snapshot>\n", argv[0]);
    return 1;
  }
  SetupPersonTest(argc, argv);
  InteractWithService();
  TearDownPersonTest();
  return 0;
}
