// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/thread.h"

#include <errno.h>
#include <pthread.h>
#include <stdio.h>

#include "src/vm/platform.h"

namespace fletch {

// 0 is never a valid thread id on Linux since tids and pids share a
// name space and pid 0 is reserved (see man 2 kill).
static const pthread_t kNoThread = static_cast<pthread_t>(0);

class ThreadIdentifier::PlatformData {
 public:
  explicit PlatformData(ThreadIdentifier::Kind kind) {
    Initialize(kind);
  }

  void Initialize(ThreadIdentifier::Kind kind) {
    switch (kind) {
    case ThreadIdentifier::SELF: thread_ = pthread_self(); break;
    case ThreadIdentifier::INVALID: thread_ = kNoThread; break;
    }
  }

  pthread_t thread_;  // Thread handle for pthread.
};

ThreadIdentifier::ThreadIdentifier(Kind kind) {
  data_ = new PlatformData(kind);
}

void ThreadIdentifier::Initialize(ThreadIdentifier::Kind kind) {
  data_->Initialize(kind);
}

ThreadIdentifier::~ThreadIdentifier() {
  delete data_;
}

bool ThreadIdentifier::IsSelf() const {
  return pthread_equal(data_->thread_, pthread_self());
}

bool ThreadIdentifier::IsValid() const {
  return data_->thread_ != kNoThread;
}

bool Thread::IsCurrent(const ThreadIdentifier* thread) {
  return thread->IsSelf();
}

void Thread::Run(RunSignature run, void* data) {
  pthread_t thread;
  int result = pthread_create(&thread, NULL, run, data);
  if (result != 0) {
    if (result == EAGAIN) {
      fprintf(stderr, "Insufficient resources\n");
    } else {
      fprintf(stderr, "Error %d", result);
    }
  }
}

}  // namespace fletch
