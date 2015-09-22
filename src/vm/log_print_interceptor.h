// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_LOG_PRINT_INTERCEPTOR_H_
#define SRC_VM_LOG_PRINT_INTERCEPTOR_H_

#include "src/shared/utils.h"

namespace fletch {

class LogPrintInterceptor : public PrintInterceptor {
 public:
  explicit LogPrintInterceptor(const char* logPath) : logPath_(logPath) {}
  virtual ~LogPrintInterceptor() {}
  virtual void Out(char* message);
  virtual void Error(char* message);
 private:
  const char* logPath_;
};

}  // namespace fletch

#endif  // SRC_VM_LOG_PRINT_INTERCEPTOR_H_
