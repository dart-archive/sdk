// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/android_print_interceptor.h"

#include <android/log.h>

namespace fletch {

void AndroidPrintInterceptor::Out(char* message) {
  __android_log_print(ANDROID_LOG_INFO, "Fletch", "%s", message);
}

void AndroidPrintInterceptor::Error(char* message) {
  __android_log_print(ANDROID_LOG_ERROR, "Fletch", "%s", message);
}

}  // namespace fletch
