// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/test_case.h"

#include <stdio.h>
#include <string.h>

#include "src/shared/flags.h"
#include "src/shared/fletch.h"

namespace fletch {

TestCase* TestCase::first_ = NULL;
TestCase* TestCase::current_ = NULL;

TestCase::TestCase(RunEntry* run, const char* name)
    : next_(NULL),
      run_(run),
      name_(name) {
  if (first_ == NULL) {
    first_ = this;
  } else {
    current_->next_ = this;
  }
  current_ = this;
}

void TestCase::Run() {
  (*run_)();
}

void TestCase::RunAll() {
  TestCase* test_case = first_;
  while (test_case != NULL) {
    bool run = true;
    const char* filter = Flags::filter;
    if (filter != NULL) {
      run = (strcmp(filter, test_case->name()) == 0);
      if (run) printf("Running %s\n", test_case->name());
    }
    if (run) test_case->Run();
    test_case = test_case->next_;
  }
}

}  // namespace fletch
