// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/thread.h"
#include "src/vm/thread_pool.h"

namespace dartino {

ThreadPool::ThreadPool(int max_threads)
    : monitor_(Platform::CreateMonitor()),
      max_threads_(max_threads),
      threads_(0),
      thread_info_(NULL),
      started_(false) {}

ThreadPool::~ThreadPool() { delete monitor_; }

struct ThreadInfo {
  ThreadPool* thread_pool;
  ThreadPool::Runable run;
  void* data;

  ThreadIdentifier thread;
  ThreadInfo* next;
};

bool ThreadPool::TryStartThread(Runable run, void* data) {
  // Start with inexpensive check.
  int value = threads_;
  if (value >= max_threads_) return true;
  if (!threads_.compare_exchange_weak(value, value + 1)) return false;

  // NOTE: This will create a new [ThreadInfo] object. All of the objects will
  // be in a linked list. The objects will only be freed when doing a
  // `JoinAll()`.
  // If we ever end up using many short-lived threads we should prune the list
  // (e.g. at thread creation time).

  ThreadInfo* info = new ThreadInfo();
  info->thread_pool = this;
  info->run = run;
  info->data = data;

  ScopedMonitorLock locker(monitor_);
  info->next = thread_info_;
  thread_info_ = info;
  if (started_) info->thread = Thread::Run(RunThread, info);

  return true;
}

void ThreadPool::Start() {
  ScopedMonitorLock locker(monitor_);
  ThreadInfo* info = thread_info_;
  while (info != NULL) {
    info->thread = Thread::Run(RunThread, info);
    info = info->next;
  }
  started_ = true;
}

void ThreadPool::JoinAll() {
  ScopedMonitorLock locker(monitor_);
  while (threads_ > 0) {
    monitor_->Wait();
  }
  while (thread_info_ != NULL) {
    ThreadInfo* info = thread_info_;
    info->thread.Join();
    thread_info_ = info->next;
    delete info;
  }
}

void* ThreadPool::RunThread(void* arg) {
  ThreadInfo* info = reinterpret_cast<ThreadInfo*>(arg);
  info->run(info->data);
  info->thread_pool->ThreadDone();
  return NULL;
}

void ThreadPool::ThreadDone() {
  // We don't expect a thread to be returned to the system often, so the simple
  // solution of always taking the lock should be fine here.
  ScopedMonitorLock locker(monitor_);
  if (--threads_ == 0) {
    monitor_->NotifyAll();
  }
}

}  // namespace dartino
