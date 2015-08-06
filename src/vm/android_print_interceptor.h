// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_ANDROID_PRINT_INTERCEPTOR_H_
#define SRC_VM_ANDROID_PRINT_INTERCEPTOR_H_

#if defined(__ANDROID__)

#include "src/shared/utils.h"

namespace fletch {

class AndroidPrintInterceptor : public PrintInterceptor {
 public:
  AndroidPrintInterceptor() {}
  virtual ~AndroidPrintInterceptor() {}
  virtual void Out(char* message);
  virtual void Error(char* message);
};

}  // namespace fletch

#endif  // defined(__ANDROID__)

#endif // SRC_VM_ANDROID_PRINT_INTERCEPTOR_H_
