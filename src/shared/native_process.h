// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_NATIVE_PROCESS_H_
#define SRC_SHARED_NATIVE_PROCESS_H_

#include "src/shared/globals.h"

namespace fletch {

class NativeProcess {
 public:
  NativeProcess(const char* executable, const char** argv);
  virtual ~NativeProcess();

  int Start();

  int Wait();

 private:
  struct ProcessData;
  ProcessData* data_;
  const char* executable_;
  const char** argv_;
};

}  // namespace fletch

#endif  // SRC_SHARED_NATIVE_PROCESS_H_
