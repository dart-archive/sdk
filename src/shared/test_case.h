// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_TEST_CASE_H_
#define SRC_SHARED_TEST_CASE_H_

#include "src/shared/globals.h"

#define TEST_CASE(name)                                                  \
  static void Test##name();                                              \
  static const fletch::TestCase kRegister##name(Test##name, #name);      \
  static void Test##name()

#define TEST_EXPORT(method)                                     \
  extern "C" { __attribute__((visibility("default"))) method }

namespace fletch {

class TestCase {
 public:
  typedef void (RunEntry)();

  TestCase(RunEntry* run, const char* name);
  virtual ~TestCase() { }

  const char* name() const { return name_; }

  virtual void Run();
  static void RunAll();

 private:
  static TestCase* first_;
  static TestCase* current_;

  TestCase* next_;
  RunEntry* const run_;
  const char* name_;

  DISALLOW_COPY_AND_ASSIGN(TestCase);
};

}  // namespace fletch

#endif  // SRC_SHARED_TEST_CASE_H_
