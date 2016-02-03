// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_ATOMIC_GCC_INTRINSICS_H_
#define SRC_SHARED_ATOMIC_GCC_INTRINSICS_H_

#ifndef SRC_SHARED_ATOMIC_H_
#error Do not include atomic_gcc_intrinsics.h directly; use atomic.h instead.
#endif

namespace dartino {

enum MemoryOrder {
  kRelaxed = __ATOMIC_RELAXED,
  kConsume = __ATOMIC_CONSUME,
  kAcquire = __ATOMIC_ACQUIRE,
  kRelease = __ATOMIC_RELEASE,
  kAcqRel = __ATOMIC_ACQ_REL,
  kSeqCst = __ATOMIC_SEQ_CST,
};

// TODO(ajohnsen): Put compiler-specific builtins in a seperate header file to
// allow easy port to other compilers.
// Wrapper for working with atomic values. This implementation follows the
// names of the C++11 std::atomic interface, to ease portability.
template <typename T>
class Atomic {
 public:
  Atomic() : value_(T()) {}

  Atomic(T value) : value_(value) {}  // NOLINT

  T operator=(T other) {
    store(other);
    return other;
  }

  operator T() const { return load(); }

  T operator++() { return add_fetch(1); }

  T operator--() { return sub_fetch(1); }

  T operator++(int) { return fetch_add(1); }

  T operator--(int) { return fetch_sub(1); }

  T operator+=(T other) { return add_fetch(other); }

  T operator-=(T other) { return sub_fetch(other); }

  void store(T other, MemoryOrder order = kSeqCst) {
    __atomic_store(&value_, &other, order);
  }

  T load(MemoryOrder order = kSeqCst) const {
    T result;
    __atomic_load(&value_, &result, order);
    return result;
  }

  T exchange(T other, MemoryOrder order = kSeqCst) {
    T result;
    __atomic_exchange(&value_, &other, &result, order);
    return result;
  }

  bool compare_exchange_weak(T& expected,  // NOLINT
                             T other, MemoryOrder order = kSeqCst) {
    return __atomic_compare_exchange(&value_, &expected, &other, true, order,
                                     order);
  }

  bool compare_exchange_weak(T& expected,  // NOLINT
                             T other, MemoryOrder success,
                             MemoryOrder failure) {
    return __atomic_compare_exchange(&value_, &expected, &other, true, success,
                                     failure);
  }

  bool compare_exchange_strong(T& expected,  // NOLINT
                               T other, MemoryOrder order = kSeqCst) {
    return __atomic_compare_exchange(&value_, &expected, &other, false, order,
                                     order);
  }

  bool compare_exchange_strong(T& expected,  // NOLINT
                               T other, MemoryOrder success,
                               MemoryOrder failure) {
    return __atomic_compare_exchange(&value_, &expected, &other, false, success,
                                     failure);
  }

  T add_fetch(T other, MemoryOrder order = kSeqCst) {
    return __atomic_add_fetch(&value_, other, order);
  }

  T sub_fetch(T other, MemoryOrder order = kSeqCst) {
    return __atomic_sub_fetch(&value_, other, order);
  }

  T fetch_add(T other, MemoryOrder order = kSeqCst) {
    return __atomic_fetch_add(&value_, other, order);
  }

  T fetch_sub(T other, MemoryOrder order = kSeqCst) {
    return __atomic_fetch_sub(&value_, other, order);
  }

 private:
  T value_;
};

}  // namespace dartino

#endif  // SRC_SHARED_ATOMIC_GCC_INTRINSICS_H_
