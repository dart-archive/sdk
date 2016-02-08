// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/bytecodes.h"
#include "src/vm/gc_thread.h"
#include "src/vm/program.h"
#include "src/vm/process.h"
#include "src/vm/scheduler.h"

namespace dartino {

void* GCThread::GCThreadEntryPoint(void* data) {
  GCThread* thread = reinterpret_cast<GCThread*>(data);
  thread->MainLoop();
  return NULL;
}

GCThread::GCThread()
    : gc_thread_monitor_(Platform::CreateMonitor()),
      shutting_down_(false),
      pause_count_(0),
      client_monitor_(Platform::CreateMonitor()),
      did_pause_(false),
      did_shutdown_(false) {}

GCThread::~GCThread() {
  delete gc_thread_monitor_;
  delete client_monitor_;
}

void GCThread::StartThread() {
  thread_ = Thread::Run(&GCThread::GCThreadEntryPoint, this);
}

void GCThread::TriggerSharedGC(Program* program) {
  ScopedMonitorLock lock(gc_thread_monitor_);

  auto it = shared_gc_count_.Find(program);
  if (it == shared_gc_count_.End()) {
    shared_gc_count_[program] = 1;
  } else {
    it->second++;
  }

  gc_thread_monitor_->Notify();
}

void GCThread::TriggerGC(Program* program) {
  ScopedMonitorLock lock(gc_thread_monitor_);
  auto it = program_gc_count_.Find(program);
  if (it == program_gc_count_.End()) {
    program_gc_count_[program] = 1;
  } else {
    it->second++;
  }

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
    Program* program_to_gc = NULL;
    Program* shared_heap_to_gc = NULL;
    bool do_pause = false;
    bool do_shutdown = false;
    {
      {
        ScopedMonitorLock lock(gc_thread_monitor_);
        while (program_gc_count_.size() == 0 &&
               shared_gc_count_.size() == 0 &&
               pause_count_ == 0 &&
               !shutting_down_) {
          gc_thread_monitor_->Wait();
        }

        if (shared_gc_count_.size() > 0) {
          shared_heap_to_gc = shared_gc_count_.Begin()->first;
        }

        if (program_gc_count_.size() > 0) {
          program_to_gc = program_gc_count_.Begin()->first;
        }

        do_shutdown = shutting_down_;
        do_pause = pause_count_ > 0;

        shutting_down_ = false;
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
    }

    if (shared_heap_to_gc != NULL) {
      Scheduler* scheduler = shared_heap_to_gc->scheduler();
      if (scheduler != NULL) scheduler->StopProgram(shared_heap_to_gc);
      shared_heap_to_gc->CollectSharedGarbage();
      if (scheduler != NULL) scheduler->ResumeProgram(shared_heap_to_gc);

      int count = 0;
      {
        ScopedMonitorLock lock(gc_thread_monitor_);
        auto it = shared_gc_count_.Find(shared_heap_to_gc);
        count = it->second;
        shared_gc_count_.Erase(it);
      }
      shared_heap_to_gc->scheduler()->FinishedGC(shared_heap_to_gc, count);
    }

    if (program_to_gc != NULL) {
      Scheduler* scheduler = program_to_gc->scheduler();
      if (scheduler != NULL) scheduler->StopProgram(program_to_gc);
      program_to_gc->CollectGarbage();
      if (scheduler != NULL) scheduler->ResumeProgram(program_to_gc);

      int count = 0;
      {
        ScopedMonitorLock lock(gc_thread_monitor_);
        auto it = program_gc_count_.Find(program_to_gc);
        count = it->second;
        program_gc_count_.Erase(it);
      }
      program_to_gc->scheduler()->FinishedGC(program_to_gc, count);
    }

    if (do_shutdown) {
      break;
    }
  }

  // Tell scheduler that we're done with all programs.
  for (auto& pair : shared_gc_count_) {
    Program* program = pair.first;
    program->scheduler()->FinishedGC(program, pair.second);
  }
  shared_gc_count_.Clear();

  for (auto& pair : program_gc_count_) {
    Program* program = pair.first;
    program->scheduler()->FinishedGC(program, pair.second);
  }
  program_gc_count_.Clear();

  // Tell caller of GCThread.Shutdown() we're done.
  {
    ScopedMonitorLock lock(client_monitor_);
    did_shutdown_ = true;
    client_monitor_->NotifyAll();
  }
}

}  // namespace dartino
