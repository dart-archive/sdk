// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_THREAD_WINDOWS_H_
#define SRC_VM_THREAD_WINDOWS_H_

#ifndef SRC_VM_THREAD_H_
#error "Don't include thread_windows.h directly, include thread.h."
#endif

#include <Windows.h>

#include "src/shared/assert.h"

namespace fletch {

// A ThreadIdentifier represents a thread identifier for a thread.
// The ThreadIdentifier does not own the underlying OS handle.
// Thread handles can be used for referring to threads and testing equality.
class ThreadIdentifier {
 public:
  ThreadIdentifier() : thread_(GetCurrentThread()) {}

  // Test for thread running.
  bool IsSelf() const { return GetCurrentThreadId() == GetThreadId(thread_); }

  // Try to join the thread identified by this [ThreadIdentifier].
  //
  // A thread can only be joined once.
  void Join() {
    DWORD result = WaitForSingleObject(thread_, INFINITE);

    // TODO(herhut): Maybe use GetLastError.
    if (result != WAIT_OBJECT_0) {
      FATAL1("Joining thread with WaitForSingleObject() failed with %d",
             result);
    }
  }

 private:
  friend class Thread;

  explicit ThreadIdentifier(HANDLE thread) : thread_(thread) {}

  HANDLE thread_;
};

}  // namespace fletch

#endif  // SRC_VM_THREAD_WINDOWS_H_
