// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_THREAD_POOL_H_
#define SRC_VM_THREAD_POOL_H_

#include <atomic>

#include "src/vm/platform.h"

namespace fletch {

class ThreadPool {
 public:
  typedef void (*Runable)(void *data);

  explicit ThreadPool(int max_threads = Platform::GetNumberOfHardwareThreads());
  ~ThreadPool();

  // Try to start a new thread. The ThreadPool will only start a new thread
  // if less than the ThreadPools max_threads and threads_limit threads are
  // running. Returns false if the check failed and the method should be
  // retried.
  bool TryStartThread(Runable run, void* data, int threads_limit);

  void JoinAll();

  int max_threads() const { return max_threads_; }

 private:
  Monitor* monitor_;
  const int max_threads_;
  std::atomic<int> threads_;

  static void* RunThread(void* arg);
  void ThreadDone();
};

}  // namespace fletch


#endif  // SRC_VM_THREAD_POOL_H_
