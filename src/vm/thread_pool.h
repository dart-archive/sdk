// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_THREAD_POOL_H_
#define SRC_VM_THREAD_POOL_H_

#include "src/shared/atomic.h"
#include "src/shared/platform.h"

namespace fletch {

struct ThreadInfo;

class ThreadPool {
 public:
  typedef void (*Runable)(void* data);

  explicit ThreadPool(int max_threads = Platform::GetNumberOfHardwareThreads());
  ~ThreadPool();

  // Try to start a new thread. The ThreadPool will only start a new thread
  // if less than the ThreadPools max_threads.
  // Returns false if the check failed and the method should be retried.
  // Returns true if either the maximum number of threads has been reached or a
  // new one has been started.
  // If called before [Start], the threads will be delayed until then.
  bool TryStartThread(Runable run, void* data);

  void Start();

  void JoinAll();

  int max_threads() const { return max_threads_; }

 private:
  Monitor* monitor_;
  const int max_threads_;
  Atomic<int> threads_;
  ThreadInfo* thread_info_;
  bool started_;

  static void* RunThread(void* arg);
  void ThreadDone();
};

}  // namespace fletch

#endif  // SRC_VM_THREAD_POOL_H_
