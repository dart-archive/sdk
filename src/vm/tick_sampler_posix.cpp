// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_POSIX)

#include "src/vm/tick_sampler.h"

#include <errno.h>
#include <stdio.h>
#include <sys/time.h>
#include <sys/signal.h>

#include "src/shared/flags.h"
#include "src/shared/platform.h"
#include "src/shared/utils.h"

#include "src/vm/process.h"
#include "src/vm/tick_queue.h"
#include "src/vm/thread.h"


namespace fletch {

class TickProcessor;

Atomic<bool> TickSampler::is_active_(false);
static struct sigaction old_signal_handler;
static struct itimerval old_timer;
static stack_t signal_stack;
static stack_t old_signal_stack;
static TickQueue* queue;
static TickProcessor* processor;

static void SignalHandler(int signal, siginfo_t* info, void* context) {
  USE(info);
  if (signal != SIGPROF) return;
  TickSample* sample = queue->StartAdd();
  if (sample == NULL) return;
  ucontext_t* ucontext = reinterpret_cast<ucontext_t*>(context);
  mcontext_t& mcontext = ucontext->uc_mcontext;
  word ip;
#if defined(FLETCH_TARGET_OS_LINUX)
#if defined(FLETCH_TARGET_IA32)
  sample->pc = bit_cast<word>(mcontext.gregs[REG_EIP]);
  sample->sp = bit_cast<word>(mcontext.gregs[REG_ESP]);
  sample->fp = bit_cast<word>(mcontext.gregs[REG_EBP]);
  ip = bit_cast<word>(mcontext.gregs[REG_ESI]);
#elif defined(FLETCH_TARGET_X64)
  sample->pc = bit_cast<word>(mcontext.gregs[REG_RIP]);
  sample->sp = bit_cast<word>(mcontext.gregs[REG_RSP]);
  sample->fp = bit_cast<word>(mcontext.gregs[REG_RBP]);
  ip = bit_cast<word>(mcontext.gregs[REG_RSI]);
#elif defined(FLETCH_TARGET_ARM)
  sample->pc = bit_cast<word>(mcontext.arm_pc);
  sample->sp = bit_cast<word>(mcontext.arm_sp);
  sample->fp = bit_cast<word>(mcontext.arm_fp);
  ip = bit_cast<word>(mcontext.arm_r5);
#else
  FATAL("HandleSignal not support on this platform");
#endif
#endif
#if defined(FLETCH_TARGET_OS_MACOS)
#if defined(FLETCH_TARGET_IA32)
  sample->pc = bit_cast<word>(mcontext->__ss.__eip);
  sample->sp = bit_cast<word>(mcontext->__ss.__esp);
  sample->fp = bit_cast<word>(mcontext->__ss.__ebp);
  ip = bit_cast<word>(mcontext->__ss.__esi);
#elif defined(FLETCH_TARGET_X64)
  sample->pc = bit_cast<word>(mcontext->__ss.__rip);
  sample->sp = bit_cast<word>(mcontext->__ss.__rsp);
  sample->fp = bit_cast<word>(mcontext->__ss.__rbp);
  ip = bit_cast<word>(mcontext->__ss.__rsi);
#else
  FATAL("HandleSignal not support on this platform");
#endif
#endif
  Process* process = Thread::GetProcess();
  if (process == NULL) {
    // Make sample unrelated to Dart.
    sample->hashtag = 0;
    sample->bcp = 0;
  } else {
    Program* program = process->program();
    sample->hashtag = program->hashtag();
    sample->bcp = program->ComputeBcpOffset(ip);
  }
  queue->CompleteAdd();
}

class TickProcessor {
 public:
  explicit TickProcessor(TickQueue* queue, int tick_per_second)
      : queue_(queue) {
    // Length of pause is computed to be the time
    // the mutator takes to fill half the queue.
    pause_in_us_ = ((uint64) 1000000) * (TickQueue::kCapacity / 2)
        / tick_per_second;
    monitor_ = Platform::CreateMonitor();
    thread_id_ = Thread::Run(&Entry, this);
  }
  ~TickProcessor() {}

  static void* Entry(void* data) {
    reinterpret_cast<TickProcessor*>(data)->Main();
    return NULL;
  }

  void Main() {
    FILE* file = fopen(Flags::tick_file, "w");
    if (file == NULL) {
      FATAL("Tick file could not be opened for writing");
    }
    fprintf(file, "# Tick samples from the Fletch VM.\n");
    const char* model;
    if (kPointerSize == 8 && sizeof(fletch_double) == 8) {
      model = "b64double";
    } else if (kPointerSize == 8 && sizeof(fletch_double) == 4) {
      model = "b64float";
    } else if (kPointerSize == 4 && sizeof(fletch_double) == 8) {
      model = "b32double";
    } else {
      ASSERT(kPointerSize == 4 && sizeof(fletch_double) == 4);
      model = "b32float";
    }
    fprintf(file, "model=%s\n", model);
    bool timed_out;
    do {
      timed_out = monitor_->Wait(pause_in_us_);
      TickSample* sample = queue_->StartRemove();
      while(sample != NULL) {
        if (sample->hashtag != 0) {
          fprintf(file, "0x%x,0x%x,0x%x\n",
                  sample->pc, sample->bcp, sample->hashtag);
        } else {
          fprintf(file, "0x%x\n", sample->pc);
        }
        queue_->CompleteRemove();
        sample = queue_->StartRemove();
      }
    } while (timed_out);
    fprintf(file, "discarded=%d\n", queue_->DiscardedTicks());
    fclose(file);
  }

  void Join() {
    monitor_->Notify();
    thread_id_.Join();
  }

 private:
  TickQueue* queue_;
  ThreadIdentifier thread_id_;
  Monitor* monitor_;
  uint64  pause_in_us_;
};


void TickSampler::Setup() {
  if (!Flags::tick_sampler) return;
  // 0. Mark the tick sampler as active.
  bool expected = false;
  if (!is_active_.compare_exchange_strong(expected, true)) {
    FATAL("Tick profiler has already been installed once");
  }
  // 1. Allocate and install alternate signal stack.
  signal_stack.ss_sp = malloc(SIGSTKSZ);
  if (signal_stack.ss_sp == NULL) {
    FATAL("Failed to allocate alternate signal stack structure");
  }
  signal_stack.ss_size = SIGSTKSZ;
  signal_stack.ss_flags = 0;
  if (sigaltstack(&signal_stack, &old_signal_stack) != 0) {
    FATAL("Failed to allocate alternate signal stack");
  }
  // 2. Install profiler signal handler
  struct sigaction sa;
  sa.sa_sigaction = &SignalHandler;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = SA_RESTART | /* make system calls restartable. */ \
      SA_SIGINFO | /* three argument signal handler. */ \
      SA_ONSTACK; /* use the alternate signal stack. */
  if (sigaction(SIGPROF, &sa, &old_signal_handler) != 0) {
    FATAL("Failed to install signal handler");
  }
  // 3. Install timer to receive periodic SIGPROF interrupts.
  const int ticks_per_second = 100;
  static struct itimerval timer;
  timer.it_interval.tv_sec = 0;
  timer.it_interval.tv_usec = 1000000 / ticks_per_second;
  timer.it_value = timer.it_interval;
  if (setitimer(ITIMER_PROF, &timer, &old_timer) != 0) {
    FATAL("Timer could not be initialized");
  }
  queue = new TickQueue();
  processor = new TickProcessor(queue, ticks_per_second);
}

void TickSampler::Teardown() {
  if (!Flags::tick_sampler) return;
  ASSERT(is_active());
  // 3. Restore old PROF timer.
  if (setitimer(ITIMER_PROF, &old_timer, NULL) != 0) {
    FATAL("Timer could not be restored");
  }
  // 2. Restore old PROF signal handler.
  if(sigaction(SIGPROF, &old_signal_handler, NULL) != 0) {
    FATAL("Signal handler could be restored");
  }
  // 1. Restore and free storage for alternate signal stack.
  if (sigaltstack(&old_signal_stack, NULL) != 0) {
    FATAL("Alternate signal stack could not be resotred");
  }
  free(signal_stack.ss_sp);
  // 0. Mark the tick sampler as inactive.
  bool expected = true;
  if (!is_active_.compare_exchange_strong(expected, false)) {
    FATAL("Tick profiler has not been installed");
  }

  processor->Join();
  delete queue;
}

}  // namespace fletch

#endif  // FLETCH_TARGET_OS_POSIX
