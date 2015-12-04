// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SPINLOCK_H_
#define SRC_VM_SPINLOCK_H_

#include "src/shared/atomic.h"

namespace fletch {

// Please limit the use of spinlocks (e.g. reduce critical region to absolute
// minimum, only if a normal mutex is a bottleneck).
class Spinlock {
 public:
  Spinlock() : is_locked_(false) {}

  bool IsLocked() const { return is_locked_; }

  void Lock() {
    while (is_locked_.exchange(true, kAcquire)) {
    }
  }

  void Unlock() { is_locked_.store(false, kRelease); }

 private:
  Atomic<bool> is_locked_;
};

class ScopedSpinlock {
 public:
  explicit ScopedSpinlock(Spinlock* lock) : lock_(lock) { lock_->Lock(); }
  ~ScopedSpinlock() { lock_->Unlock(); }

 private:
  Spinlock* lock_;
};

}  // namespace fletch

#endif  // SRC_VM_SPINLOCK_H_
