// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_THREAD_H_
#define SRC_VM_THREAD_H_

#include "src/shared/globals.h"
#include "src/shared/platform.h"

#if defined(FLETCH_TARGET_OS_POSIX)
#include "src/vm/thread_posix.h"
#elif defined(FLETCH_TARGET_OS_LK)
#include "src/vm/thread_lk.h"
#elif defined(FLETCH_TARGET_OS_CMSIS)
#include "src/vm/thread_cmsis.h"
#elif defined(FLETCH_TARGET_OS_WIN)
#include "src/vm/thread_windows.h"
#else
#error "OS is lacking thread implementation."
#endif

namespace fletch {

// A ThreadIdentifier represents a thread identifier for a thread.
// The ThreadIdentifier does not own the underlying OS handle.
// Thread handles can be used for referring to threads and testing equality.
class ThreadIdentifier;

// Forward declaration.
class Process;

// Thread are started using the static Thread::Run method.
class Thread {
 public:
  // Returns true if 'thread' is the current thread.
  static bool IsCurrent(const ThreadIdentifier* thread);

  static void SetupOSSignals();
  static void TeardownOSSignals();

  // TLS accessors for process (used for extracting process at profiler tick).
  static void SetProcess(Process* process);
  static Process* GetProcess();

  typedef void* (*RunSignature)(void*);
  static ThreadIdentifier Run(RunSignature run, void* data = NULL);

 private:
  DISALLOW_ALLOCATION();
};

}  // namespace fletch

#endif  // SRC_VM_THREAD_H_
