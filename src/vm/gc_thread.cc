// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/bytecodes.h"
#include "src/vm/gc_thread.h"
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
      pause_count_(0),
      client_monitor_(Platform::CreateMonitor()),
      did_pause_(false),
      did_shutdown_(false) {
}

GCThread::~GCThread() {
  delete gc_thread_monitor_;
  delete client_monitor_;
}

void GCThread::StartThread() {
  thread_ = Thread::Run(&GCThread::GCThreadEntryPoint, this);
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

void GCThread::Pause() {
  // Tell thread it should pause.
  {
    ScopedMonitorLock lock(gc_thread_monitor_);
    pause_count_++;
    if (pause_count_ == 1) {
      gc_thread_monitor_->Notify();
    }
  }
  // And wait until it says it's paused.
  {
    ScopedMonitorLock lock(client_monitor_);
    while (!did_pause_) client_monitor_->Wait();
  }
}

void GCThread::Resume() {
  // Tell thread it should resume.
  {
    ScopedMonitorLock lock(gc_thread_monitor_);
    ASSERT(pause_count_ > 0);
    pause_count_--;
    if (pause_count_ == 0) {
      gc_thread_monitor_->Notify();
    }
  }
  // And wait until it says it's resumed.
  {
    ScopedMonitorLock lock(client_monitor_);
    while (did_pause_) client_monitor_->Wait();
  }
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
    ScopedMonitorLock lock(client_monitor_);
    while (!did_shutdown_) client_monitor_->Wait();
  }

  // And join it to make sure it's actually dead.
  thread_.Join();
}

void GCThread::MainLoop() {
  // Handle gc and shutdown messages.
  while (true) {
    bool do_gc = false;
    bool do_immutable_gc = false;
    bool do_pause = false;
    bool do_shutdown = false;
    {
      {
        ScopedMonitorLock lock(gc_thread_monitor_);
        while (!requesting_gc_ &&
               !requesting_immutable_gc_ &&
               pause_count_ == 0 &&
               !shutting_down_) {
          gc_thread_monitor_->Wait();
        }

        do_gc = requesting_gc_;
        do_immutable_gc = requesting_immutable_gc_;
        do_shutdown = shutting_down_;
        do_pause = pause_count_ > 0;
      }

      if (do_pause) {
        {
          ScopedMonitorLock locker(client_monitor_);
          did_pause_ = true;
          client_monitor_->NotifyAll();
        }
        {
          ScopedMonitorLock locker(gc_thread_monitor_);
          while (pause_count_ > 0) {
            gc_thread_monitor_->Wait();
          }
        }
        {
          ScopedMonitorLock locker(client_monitor_);
          did_pause_ = false;
          client_monitor_->NotifyAll();
        }
      }

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
    ScopedMonitorLock lock(client_monitor_);
    did_shutdown_ = true;
    client_monitor_->NotifyAll();
  }
}

}  // namespace fletch
