// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PREEMPTER_H_
#define SRC_VM_PREEMPTER_H_

#include "src/shared/atomic.h"

#include "src/vm/thread.h"
#include "src/vm/scheduler.h"

namespace fletch {

class Preempter {
 public:
  enum State {
    kAllocated,
    kInitialized,
    kFinishing,
    kFinished,
  };

  static void Setup();
  static void TearDown();

  explicit Preempter(Scheduler* scheduler);
  ~Preempter();

  void WaitUntilReady();
  void WaitUntilFinished();

  void Run();

 private:
  // Global instance of preempter
  static Preempter* preempter_;
  static ThreadIdentifier preempter_thread_;

  Monitor* preempt_monitor_;
  Atomic<State> state_;
  Scheduler* scheduler_;

  uint64 GetNextPreemptTime();
};


}  // namespace fletch

#endif  // SRC_VM_PREEMPTER_H_
