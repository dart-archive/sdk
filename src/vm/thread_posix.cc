// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_POSIX)

#include "src/vm/thread.h"  // NOLINT we don't include thread_posix.h.

#include <errno.h>
#include <stdio.h>
#include <sys/time.h>

#include "src/shared/platform.h"
#include "src/shared/utils.h"

#include "src/vm/tick_sampler.h"

namespace fletch {

bool Thread::IsCurrent(const ThreadIdentifier* thread) {
  return thread->IsSelf();
}

static pthread_key_t thr_id_key;

void Thread::SetProcess(Process* process) {
  pthread_setspecific(thr_id_key, static_cast<void*>(process));
}

Process* Thread::GetProcess() {
  return static_cast<Process*>(pthread_getspecific(thr_id_key));
}

void Thread::Setup() {
  if (pthread_key_create(&thr_id_key, NULL) != 0) {
    FATAL("Failed to create thread local key");
  }
}

void Thread::TearDown() {
  if (pthread_key_delete(thr_id_key) != 0) {
    FATAL("Failed to delete thread local key");
  }
}

void Thread::SetupOSSignals() {
  // Block all signals except SIGPROF.
  sigset_t set;
  sigfillset(&set);
  sigdelset(&set, SIGPROF);
  if (pthread_sigmask(SIG_BLOCK, &set, NULL) != 0) {
    FATAL("Failed to block signal on thread");
  }
  // Start the tick based profiler.
  TickSampler::Setup();
}

void Thread::TeardownOSSignals() {
  // Stop the tick based profiler.
  TickSampler::Teardown();
  // Restore the sigal mask.
  sigset_t set;
  sigfillset(&set);
  if (pthread_sigmask(SIG_UNBLOCK, &set, NULL) != 0) {
    FATAL("Failed to unblock signal on thread");
  }
}

ThreadIdentifier Thread::Run(RunSignature run, void* data) {
  pthread_t thread;
  int result = pthread_create(&thread, NULL, run, data);
  if (result != 0) {
    if (result == EAGAIN) {
      Print::Error("Insufficient resources\n");
    } else {
      Print::Error("Error %d", result);
    }
    FATAL1("pthread_create failed with error %d\n", result);
  }
  return ThreadIdentifier(thread);
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_POSIX)
