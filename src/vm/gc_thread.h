// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_GC_THREAD_H_
#define SRC_VM_GC_THREAD_H_

#include "src/shared/atomic.h"

#include "src/vm/thread.h"
#include "src/vm/program.h"

namespace fletch {

class GCThread {
 public:
  GCThread();
  ~GCThread();

  void StartThread();
  void TriggerGC(Program* program);
  void StopThread();

 private:
  static void* GCThreadEntryPoint(void *data);

  void MainLoop();

  Monitor* gc_thread_monitor_;
  Program* program_;
  Atomic<bool> shutting_down_;
  Atomic<bool> requesting_gc_;

  Monitor* shutdown_monitor_;
  Atomic<bool> did_shutdown_;
};

}  // namespace fletch


#endif  // SRC_VM_GC_THREAD_H_
