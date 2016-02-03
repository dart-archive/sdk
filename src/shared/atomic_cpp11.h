// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_ATOMIC_CPP11_H_
#define SRC_SHARED_ATOMIC_CPP11_H_

#ifndef SRC_SHARED_ATOMIC_H_
#error Do not include atomic_cpp11.h directly; use atomic.h instead.
#endif

#include <atomic>

namespace dartino {

template <typename T>
using Atomic = std::atomic<T>;

static const std::memory_order kRelaxed = std::memory_order_relaxed;
static const std::memory_order kConsume = std::memory_order_consume;
static const std::memory_order kAcquire = std::memory_order_acquire;
static const std::memory_order kRelease = std::memory_order_release;
static const std::memory_order kAcqRel = std::memory_order_acq_rel;
static const std::memory_order kSeqCst = std::memory_order_seq_cst;

}  // namespace dartino

#endif  // SRC_SHARED_ATOMIC_CPP11_H_
