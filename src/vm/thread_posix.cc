// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/thread.h"

#include <errno.h>
#include <stdio.h>

#include "src/shared/utils.h"
#include "src/vm/platform.h"

namespace fletch {

bool Thread::IsCurrent(const ThreadIdentifier* thread) {
  return thread->IsSelf();
}

void Thread::Run(RunSignature run, void* data) {
  pthread_t thread;
  int result = pthread_create(&thread, NULL, run, data);
  if (result != 0) {
    if (result == EAGAIN) {
      Print::Error("Insufficient resources\n");
    } else {
      Print::Error("Error %d", result);
    }
  }
}

}  // namespace fletch
