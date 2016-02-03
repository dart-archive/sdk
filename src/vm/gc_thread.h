// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_GC_THREAD_H_
#define SRC_VM_GC_THREAD_H_

#include "src/vm/thread.h"
#include "src/vm/program.h"

namespace dartino {

class GCThread {
 public:
  GCThread();
  ~GCThread();

  void StartThread();
  void TriggerSharedGC(Program* program);
  void TriggerGC(Program* program);
  void Pause();
  void Resume();
  void StopThread();

 private:
  static void* GCThreadEntryPoint(void* data);

  void MainLoop();

  ThreadIdentifier thread_;

  Monitor* gc_thread_monitor_;
  // TODO(kustermann): We should use a priority datastructure here.
  HashMap<Program*, int> program_gc_count_;
  HashMap<Program*, int> shared_gc_count_;
  bool shutting_down_;
  int pause_count_;

  Monitor* client_monitor_;
  bool did_pause_;
  bool did_shutdown_;
};

}  // namespace dartino

#endif  // SRC_VM_GC_THREAD_H_
