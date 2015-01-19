// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/thread_pool.h"

#include "src/vm/thread.h"

namespace fletch {

ThreadPool::ThreadPool(int max_threads)
    : monitor_(Platform::CreateMonitor()),
      max_threads_(max_threads),
      threads_(0) {
}

ThreadPool::~ThreadPool() {
  delete monitor_;
}

struct ThreadInfo {
  ThreadPool* thread_pool;
  ThreadPool::Runable run;
  void* data;
};

bool ThreadPool::TryStartThread(Runable run, void* data, int threads_limit) {
  // Start with inexpensive check.
  int value = threads_;
  if (max_threads_ < threads_limit) threads_limit = max_threads_;
  if (value >= threads_limit) return true;
  if (!threads_.compare_exchange_weak(value, value + 1)) return false;

  ThreadInfo* info = new ThreadInfo();
  info->thread_pool = this;
  info->run = run;
  info->data = data;
  Thread::Run(RunThread, info);

  return true;
}

void ThreadPool::JoinAll() {
  monitor_->Lock();
  while (threads_ > 0) {
    monitor_->Wait();
  }
  monitor_->Unlock();
}

void* ThreadPool::RunThread(void* arg) {
  ThreadInfo* info = reinterpret_cast<ThreadInfo*>(arg);
  info->run(info->data);
  info->thread_pool->ThreadDone();
  delete info;
  return NULL;
}

void ThreadPool::ThreadDone() {
  // We don't expect a thread to be returned to the system often, so the simple
  // solution of always taking the lock should be fine here.
  monitor_->Lock();
  if (--threads_ == 0) {
    monitor_->NotifyAll();
  }
  monitor_->Unlock();
}

}  // namespace fletch
