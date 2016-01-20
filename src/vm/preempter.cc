// Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/preempter.h"

#include "src/shared/flags.h"

namespace fletch {

// Global instance of preempter & preempter thread.
Preempter* Preempter::preempter_ = NULL;
ThreadIdentifier Preempter::preempter_thread_;

static void *RunPreempterEntry(void *data) {
  Preempter* preempter = reinterpret_cast<Preempter*>(data);
  preempter->Run();
  return NULL;
}

void Preempter::Setup() {
  ASSERT(preempter_ == NULL);
  preempter_ = new Preempter(Scheduler::GlobalInstance());
  preempter_thread_ = Thread::Run(RunPreempterEntry, preempter_);
  preempter_->WaitUntilReady();
}

void Preempter::TearDown() {
  ASSERT(preempter_ != NULL);
  preempter_->WaitUntilFinished();
  preempter_thread_.Join();
  delete preempter_;
  preempter_ = NULL;
}

Preempter::Preempter(Scheduler* scheduler)
    : preempt_monitor_(Platform::CreateMonitor()),
      state_(Preempter::kAllocated),
      scheduler_(scheduler) {
}

Preempter::~Preempter() {
  delete preempt_monitor_;
}

void Preempter::WaitUntilReady() {
  ScopedMonitorLock scoped_lock(preempt_monitor_);

  // Wait until the preempter thread signals it's ready.
  while (state_ != Preempter::kInitialized) {
    preempt_monitor_->Wait();
  }
}

void Preempter::WaitUntilFinished() {
  ScopedMonitorLock scoped_lock(preempt_monitor_);
  ASSERT(state_ == Preempter::kInitialized);

  // Signal the preempter thread to shut down
  state_ = Preempter::kFinishing;
  preempt_monitor_->NotifyAll();

  // Wait until it did shut down.
  while (state_ != Preempter::kFinished) {
    preempt_monitor_->Wait();
  }
}

void Preempter::Run() {
  ScopedMonitorLock locker(preempt_monitor_);

  static const bool kProfile = Flags::profile;
  static const uint64 kProfileIntervalUs = Flags::profile_interval;

  uint64 next_preempt = GetNextPreemptTime();
  // If profile is disabled, next_preempt will always be less than next_profile.
  uint64 next_profile =
      kProfile ? Platform::GetMicroseconds() + kProfileIntervalUs : UINT64_MAX;
  uint64 next_timeout = Utils::Minimum(next_preempt, next_profile);

  // As long as we're not told to finish, we stay alive.
  state_ = Preempter::kInitialized;
  preempt_monitor_->NotifyAll();
  while (state_ != Preempter::kFinishing) {
    // If we didn't time out, we were interrupted. In that case, continue.
    if (!preempt_monitor_->WaitUntil(next_timeout)) continue;

    bool is_preempt = next_preempt <= next_profile;
    bool is_profile = next_profile <= next_preempt;

    if (is_preempt) {
      scheduler_->PreemptionTick();
      next_preempt = GetNextPreemptTime();
    }
    if (is_profile) {
      scheduler_->ProfileTick();
      next_profile += kProfileIntervalUs;
    }

    next_timeout = Utils::Minimum(next_preempt, next_profile);
  }

  state_ = Preempter::kFinished;
  preempt_monitor_->NotifyAll();
}

uint64 Preempter::GetNextPreemptTime() {
  // Wait 100 ms.
  uint64 now = Platform::GetMicroseconds();
  return now + 100 * 1000L;
}


}  // namespace fletch
