// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/platform.h"
#include "src/vm/log_print_interceptor.h"

namespace fletch {

void LogPrintInterceptor::Out(char* message) {
  char buf[1024];
  snprintf(buf, sizeof(buf), "Fletch VM INFO: %s", message);
  Platform::WriteText(logPath_, buf, true);
}

void LogPrintInterceptor::Error(char* message) {
  char buf[1024];
  snprintf(buf, sizeof(buf), "Fletch VM ERROR: %s", message);
  Platform::WriteText(logPath_, buf, true);
}

}  // namespace fletch
