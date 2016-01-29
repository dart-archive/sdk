// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_TICK_SAMPLER_H_
#define SRC_VM_TICK_SAMPLER_H_

#include "src/shared/atomic.h"
#include "src/shared/globals.h"
#include "src/shared/platform.h"

namespace fletch {

class Process;

// TickSampler periodically samples and collects the state of the VM.
class TickSampler {
 public:
  // Initializes the sampler, called once.
  static void Setup();
  // Teardown the sampler, reverses the SetUp call.
  static void Teardown();

  // Tells whether the profiler is active.
  static bool is_active() { return is_active_; }

 private:
  static Atomic<bool> is_active_;
};

}  // namespace fletch

#endif  // SRC_VM_TICK_SAMPLER_H_
