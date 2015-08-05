// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/bytecodes.h"
#include "src/vm/gc_thread.h"
#include "src/vm/scheduler.h"
#include "src/vm/program.h"
#include "src/vm/process.h"

namespace fletch {

void* GCThread::GCThreadEntryPoint(void *data) {
  GCThread* thread = reinterpret_cast<GCThread*>(data);
  thread->MainLoop();
  return NULL;
}

GCThread::GCThread()
    : gc_thread_monitor_(Platform::CreateMonitor()),
      program_(NULL),
      shutting_down_(false),
      requesting_immutable_gc_(false),
      requesting_gc_(false),
      shutdown_monitor_(Platform::CreateMonitor()),
      did_shutdown_(false) {
}

GCThread::~GCThread() {
  delete gc_thread_monitor_;
  delete shutdown_monitor_;
}

void GCThread::StartThread() {
  Thread::Run(&GCThread::GCThreadEntryPoint, this);
}

void GCThread::TriggerImmutableGC(Program* program) {
  ScopedMonitorLock lock(gc_thread_monitor_);
  // NOTE: We don't support multiple programs ATM.
  ASSERT(program_ == NULL || program_ == program);
  program_ = program;
  requesting_immutable_gc_ = true;
  gc_thread_monitor_->Notify();
}

void GCThread::TriggerGC(Program* program) {
  ScopedMonitorLock lock(gc_thread_monitor_);
  // NOTE: We don't support multiple programs ATM.
  ASSERT(program_ == NULL || program_ == program);
  program_ = program;
  requesting_gc_ = true;
  gc_thread_monitor_->Notify();
}

void GCThread::StopThread() {
  // Tell thread he should stop.
  {
    ScopedMonitorLock lock(gc_thread_monitor_);
    shutting_down_ = true;
    gc_thread_monitor_->Notify();
  }

  // And wait until it says it's done.
  {
    ScopedMonitorLock lock(shutdown_monitor_);
    while (!did_shutdown_) shutdown_monitor_->Wait();
  }
}

void GCThread::MainLoop() {
  // Handle gc and shutdown messages.
  while (true) {
    bool do_gc = false;
    bool do_immutable_gc = false;
    bool do_shutdown = false;
    {
      ScopedMonitorLock lock(gc_thread_monitor_);
      while (!requesting_gc_ &&
             !requesting_immutable_gc_ &&
             !shutting_down_) {
        gc_thread_monitor_->Wait();
      }
      do_gc = requesting_gc_;
      do_immutable_gc = requesting_immutable_gc_;
      do_shutdown = shutting_down_;

      requesting_immutable_gc_ = false;
      requesting_gc_ = false;
      shutting_down_ = false;
    }

    if (do_immutable_gc) {
      program_->CollectImmutableGarbage();
    }

    if (do_gc) {
      program_->CollectGarbage();
    }

    if (do_shutdown) {
      break;
    }
  }

  // Tell caller of GCThread.Shutdown() we're done.
  {
    ScopedMonitorLock lock(shutdown_monitor_);
    did_shutdown_ = true;
    shutdown_monitor_->Notify();
  }
}

}  // namespace fletch
