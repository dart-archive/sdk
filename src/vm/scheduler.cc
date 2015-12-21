// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/scheduler.h"

#include "src/shared/flags.h"

#include "src/vm/frame.h"
#include "src/vm/gc_thread.h"
#include "src/vm/interpreter.h"
#include "src/vm/links.h"
#include "src/vm/port.h"
#include "src/vm/process.h"
#include "src/vm/process_queue.h"
#include "src/vm/session.h"
#include "src/vm/thread.h"

#define HANDLE_BY_SESSION_OR_SELF(session_expression, self_expression) \
  do {                                                                 \
    Session* session = process->program()->session();                  \
    if (session == NULL || !session->is_debugging() ||                 \
        !(session_expression)) {                                       \
      self_expression;                                                 \
    }                                                                  \
  } while (false);

namespace fletch {

ThreadState* const kEmptyThreadState = reinterpret_cast<ThreadState*>(1);
ThreadState* const kLockedThreadState = reinterpret_cast<ThreadState*>(2);
Process* const kPreemptMarker = reinterpret_cast<Process*>(1);

Scheduler::Scheduler()
#if !defined(FLETCH_ENABLE_MULTIPLE_PROCESS_HEAPS)
    : max_threads_(1),
#else
    : max_threads_(Platform::GetNumberOfHardwareThreads()),
#endif
      thread_pool_(max_threads_),
      preempt_monitor_(Platform::CreateMonitor()),
      processes_(0),
      sleeping_threads_(0),
      thread_count_(0),
      idle_threads_(kEmptyThreadState),
      threads_(new Atomic<ThreadState*>[max_threads_]),
      thread_states_to_delete_(NULL),
      startup_queue_(new ProcessQueue()),
      pause_monitor_(Platform::CreateMonitor()),
      last_process_exit_(Signal::kTerminated),
      pause_(false),
      current_processes_(new Atomic<Process*>[max_threads_]),
      gc_thread_(new GCThread()) {
  for (int i = 0; i < max_threads_; i++) {
    threads_[i] = NULL;
    current_processes_[i] = NULL;
  }
}

Scheduler::~Scheduler() {
  delete preempt_monitor_;
  delete pause_monitor_;
  delete[] current_processes_;
  delete[] threads_;
  delete startup_queue_;
  delete gc_thread_;

  ThreadState* current = thread_states_to_delete_;
  while (current != NULL) {
    ThreadState* next = current->next_idle_thread();
    delete current;
    current = next;
  }
}

void Scheduler::ScheduleProgram(Program* program, Process* main_process) {
  program->set_scheduler(this);

  ScopedMonitorLock locker(pause_monitor_);

  // NOTE: Even though this method might be run on any thread, we don't need to
  // guard against the program being stopped, since we insert it the very first
  // time.
  ++processes_;
  if (!main_process->ChangeState(Process::kSleeping, Process::kReady)) {
    UNREACHABLE();
  }
  EnqueueProcessAndNotifyThreads(NULL, main_process);
}

void Scheduler::UnscheduleProgram(Program* program) {
  ScopedMonitorLock locker(pause_monitor_);

  ASSERT(program->scheduler() == this);
  program->set_scheduler(NULL);
}

void Scheduler::StopProgram(Program* program) {
  ASSERT(program->scheduler() == this);

  {
    ScopedMonitorLock pause_locker(pause_monitor_);

    ProgramState* program_state = program->program_state();
    while (program_state->is_paused()) {
      pause_monitor_->Wait();
    }
    program_state->set_is_paused(true);

    pause_ = true;

    NotifyAllThreads();

    while (true) {
      int count = 0;
      // Preempt running processes, only if it was possibly to 'take' the
      // current process. This makes sure we don't preempt while deleting.
      // Loop to ensure we continue to preempt until all threads are sleeping.
      for (int i = 0; i < max_threads_; i++) {
        if (threads_[i].load() != NULL) count++;
        PreemptThreadProcess(i);
      }
      if (count == sleeping_threads_) break;
      pause_monitor_->Wait();
    }

    Process* to_enqueue = NULL;

    while (true) {
      Process* process = NULL;
      // All processes dequeued are marked as Running.
      if (!TryDequeueFromAnyThread(&process)) continue;  // Retry.
      if (process == NULL) break;

      if (process->program() == program) {
        process->ChangeState(Process::kRunning, Process::kReady);
        program_state->AddPausedProcess(process);
      } else {
        process->set_next(to_enqueue);
        to_enqueue = process;
      }
    }

    while (to_enqueue != NULL) {
      to_enqueue->ChangeState(Process::kRunning, Process::kReady);
      EnqueueOnAnyThread(to_enqueue);
      Process* next = to_enqueue->next();
      to_enqueue->set_next(NULL);
      to_enqueue = next;
    }

    pause_ = false;
  }

  NotifyAllThreads();
}

void Scheduler::ResumeProgram(Program* program) {
  ASSERT(program->scheduler() == this);

  {
    ScopedMonitorLock locker(pause_monitor_);

    ProgramState* program_state = program->program_state();
    ASSERT(program_state->is_paused());

    Process* process = program_state->paused_processes_head();
    while (process != NULL) {
      Process* next = process->next();
      process->set_next(NULL);
      EnqueueOnAnyThread(process);
      process = next;
    }
    program_state->set_paused_processes_head(NULL);
    program_state->set_is_paused(false);
    pause_monitor_->NotifyAll();
  }
  NotifyAllThreads();
}

void Scheduler::PauseGcThread() {
  ASSERT(gc_thread_ != NULL);
  gc_thread_->Pause();
}

void Scheduler::ResumeGcThread() {
  ASSERT(gc_thread_ != NULL);
  gc_thread_->Resume();
}

void Scheduler::EnqueueProcessOnSchedulerWorkerThread(
    Process* interpreting_process, Process* process) {
  ++processes_;
  if (!process->ChangeState(Process::kSleeping, Process::kReady)) UNREACHABLE();

  ThreadState* thread_state = interpreting_process->thread_state();
  EnqueueProcessAndNotifyThreads(thread_state, process);
}

void Scheduler::ResumeProcess(Process* process) {
  if (!process->ChangeState(Process::kSleeping, Process::kReady)) return;
  EnqueueOnAnyThreadSafe(process);
}

void Scheduler::SignalProcess(Process* process) {
  while (true) {
    switch (process->state()) {
      case Process::kSleeping:
        if (process->ChangeState(Process::kSleeping, Process::kReady)) {
          // TODO(kustermann): If it is guaranteed that [SignalProcess] is only
          // called from a scheduler worker thread, we could use the non *Safe*
          // method here (which doesn't guard against stopped programs).
          EnqueueOnAnyThreadSafe(process);
          return;
        }
        // If the state changed, we'll try again.
        break;
      case Process::kReady:
      case Process::kBreakPoint:
      case Process::kCompileTimeError:
      case Process::kUncaughtException:
        // Either the scheduler/debugger will signal the process, or it will be
        // enqueued and the interpreter entry will handle the signal.
        return;
      case Process::kRunning:
        // The process will be signaled when entering/leaving the interpreter.
        process->Preempt();
        return;
      case Process::kYielding:
        // This is a temporary state and will go either to kReady/kSleeping.
        // NOTE: Bad that we're busy looping here (liklihood of wasted cycles is
        // roughly the same as for spinlocks)!
        break;
      case Process::kTerminated:
      case Process::kWaitingForChildren:
        // Nothing to do here.
        return;
    }
  }
}

void Scheduler::ContinueProcess(Process* process) {
  bool success =
      process->ChangeState(Process::kBreakPoint, Process::kReady) ||
      process->ChangeState(Process::kCompileTimeError, Process::kReady) ||
      process->ChangeState(Process::kUncaughtException, Process::kReady);
  ASSERT(success);
  EnqueueOnAnyThreadSafe(process);
}

bool Scheduler::EnqueueProcess(Process* process, Port* port) {
  ASSERT(port->IsLocked());

  if (!process->ChangeState(Process::kSleeping, Process::kReady)) {
    port->Unlock();
    return false;
  }
  port->Unlock();
  EnqueueOnAnyThreadSafe(process);

  return true;
}

int Scheduler::Run() {
  preempt_monitor_->Lock();

  thread_pool_.Start();
  gc_thread_->StartThread();

  static const bool kProfile = Flags::profile;
  static const uint64 kProfileIntervalUs = Flags::profile_interval;

  int thread_index = 0;
  uint64 next_preempt = GetNextPreemptTime();
  // If profile is disabled, next_preempt will always be less than next_profile.
  uint64 next_profile =
      kProfile ? Platform::GetMicroseconds() + kProfileIntervalUs : UINT64_MAX;
  uint64 next_timeout = Utils::Minimum(next_preempt, next_profile);
  while (processes_ > 0) {
    // If we didn't time out, we were interrupted. In that case, continue.
    if (!preempt_monitor_->WaitUntil(next_timeout)) continue;

    bool is_preempt = next_preempt <= next_profile;
    bool is_profile = next_profile <= next_preempt;

    if (is_preempt) {
      // Clamp the thread_index to the number of current threads.
      if (thread_index >= thread_count_) thread_index = 0;
      PreemptThreadProcess(thread_index);
      thread_index++;
      next_preempt = GetNextPreemptTime();
      next_timeout = Utils::Minimum(next_preempt, next_profile);
    }

    if (is_profile) {
      // Send a profile signal to all running processes.
      int thread_count = thread_count_;
      for (int i = 0; i < thread_count; i++) ProfileThreadProcess(i);
      next_profile += kProfileIntervalUs;
      next_timeout = Utils::Minimum(next_preempt, next_profile);
    }
  }
  preempt_monitor_->Unlock();
  thread_pool_.JoinAll();

  gc_thread_->StopThread();

  switch (last_process_exit_.load()) {
    case Signal::kTerminated:
      return 0;
    case Signal::kCompileTimeError:
      return kCompileTimeErrorExitCode;
    case Signal::kUncaughtException:
      return kUncaughtExceptionExitCode;
    // TODO(kustermann): We should consider returning a different exitcode if a
    // process was killed via a signal or killed programmatically.
    case Signal::kUnhandledSignal:
      return kUncaughtExceptionExitCode;
    case Signal::kKilled:
      return kUncaughtExceptionExitCode;
    case Signal::kShouldKill:
      UNREACHABLE();
  }
  UNREACHABLE();
  return 0;
}

void Scheduler::DeleteTerminatedProcess(Process* process, Signal::Kind kind) {
  Program* program = process->program();
  processes_--;
  if (program->ScheduleProcessForDeletion(process, kind)) {
    last_process_exit_ = program->exit_kind();
  }

  if (Flags::gc_on_delete) {
    ASSERT(gc_thread_ != NULL);
    gc_thread_->TriggerGC(program);
  }
}

void Scheduler::ExitAtTermination(Process* process, Signal::Kind kind) {
  ASSERT(process->state() == Process::kTerminated);
  process->ChangeState(Process::kTerminated, Process::kWaitingForChildren);

  DeleteTerminatedProcess(process, kind);
  if (processes_ == 0) NotifyAllThreads();
}

void Scheduler::ExitAtUncaughtException(Process* process, bool print_stack) {
  ASSERT(process->state() == Process::kUncaughtException);
  process->ChangeState(Process::kUncaughtException,
                       Process::kWaitingForChildren);

  if (print_stack) {
    Program* program = process->program();
    Class* nsm_class = program->no_such_method_error_class();
    Object* exception = process->exception();
    bool using_snapshots = program->was_loaded_from_snapshot();
    bool is_optimized = program->is_optimized();

    if (using_snapshots && is_optimized && exception->IsInstance() &&
        Instance::cast(exception)->get_class() == nsm_class) {
      Instance* nsm_exception = Instance::cast(exception);
      Object* klass_obj = nsm_exception->GetInstanceField(1);
      Object* selector_obj = nsm_exception->GetInstanceField(2);

      word class_offset = -1;
      if (klass_obj->IsClass()) {
        class_offset = program->OffsetOf(Class::cast(klass_obj));
      }

      int selector = -1;
      if (selector_obj->IsSmi()) selector = Smi::cast(selector_obj)->value();

      Print::Out("NoSuchMethodError(%ld, %d)\n", class_offset, selector);
    } else {
      Print::Out("Uncaught exception:\n");
      exception->Print();
    }

    if (using_snapshots && is_optimized) {
      Coroutine* coroutine = process->coroutine();
      while (true) {
        Stack* stack = coroutine->stack();

        int index = 0;
        Frame frame(stack);
        while (frame.MovePrevious()) {
          Function* function = frame.FunctionFromByteCodePointer();
          Print::Out("Frame % 2d: Function(%ld)\n", index,
                     program->OffsetOf(function));
          index++;
        }

        if (coroutine->has_caller()) {
          Print::Out(" <<called-by-coroutine>>\n");
          coroutine = coroutine->caller();
        } else {
          break;
        }
      }
    }
  }

  ExitWith(process, kUncaughtExceptionExitCode, Signal::kUncaughtException);
}

void Scheduler::ExitAtCompileTimeError(Process* process) {
  ASSERT(process->state() == Process::kCompileTimeError);
  process->ChangeState(Process::kCompileTimeError,
                       Process::kWaitingForChildren);

  ExitWith(process, kCompileTimeErrorExitCode, Signal::kCompileTimeError);
}

void Scheduler::ExitAtBreakpoint(Process* process) {
  ASSERT(process->state() == Process::kBreakPoint);
  process->ChangeState(Process::kBreakPoint, Process::kWaitingForChildren);

  // TODO(kustermann): Maybe we want to make a different constant for this? It
  // is a very strange case and one could even argue that if the session
  // detaches after hitting a breakpoint the process should not be killed but
  // rather resumed.
  ExitWith(process, kBreakPointExitCode, Signal::kTerminated);
}

void Scheduler::ExitWith(Process* process, int exit_code, Signal::Kind kind) {
  DeleteTerminatedProcess(process, kind);
  ScopedMonitorLock scoped_lock(preempt_monitor_);
  if (processes_ == 0) NotifyAllThreads();
}

void Scheduler::RescheduleProcess(Process* process, ThreadState* state,
                                  bool terminate) {
  ASSERT(process->state() == Process::kRunning);
  if (terminate) {
    process->ChangeState(Process::kRunning, Process::kTerminated);
    ExitAtTermination(process, Signal::kTerminated);
  } else {
    process->ChangeState(Process::kRunning, Process::kReady);
    EnqueueOnAnyThread(process, state->thread_id() + 1);
  }
}

void Scheduler::PreemptThreadProcess(int thread_id) {
  Process* process = current_processes_[thread_id];
  while (true) {
    if (process == kPreemptMarker) {
      break;
    } else if (process == NULL) {
      if (current_processes_[thread_id].compare_exchange_strong(
              process, kPreemptMarker)) {
        break;
      }
    } else {
      if (current_processes_[thread_id].compare_exchange_strong(process,
                                                                NULL)) {
        process->Preempt();
        current_processes_[thread_id] = process;
        break;
      }
    }
  }
}

void Scheduler::ProfileThreadProcess(int thread_id) {
  Process* process = current_processes_[thread_id];
  if (process != NULL && process != kPreemptMarker) {
    if (current_processes_[thread_id].compare_exchange_strong(process, NULL)) {
      process->Profile();
      current_processes_[thread_id] = process;
    }
  }
}

uint64 Scheduler::GetNextPreemptTime() {
  // Wait between 1 and 100 ms.
  int current_threads = Utils::Maximum<int>(1, thread_count_);
  uint64 now = Platform::GetMicroseconds();
  return now + Utils::Maximum(1, 100 / current_threads) * 1000L;
}

void Scheduler::EnqueueProcessAndNotifyThreads(ThreadState* thread_state,
                                               Process* process) {
  ASSERT(process != NULL);

  if (thread_count_ == 0 || thread_state == NULL) {
    // No running threads, use the startup_queue_.
    bool was_empty;
    while (!startup_queue_->TryEnqueue(process, &was_empty)) {
    }
  } else {
    int thread_id = thread_count_ - 1;
    if (thread_state != NULL) {
      thread_id = thread_state->thread_id() + 1;
    }
    // If we were able to enqueue on an idle thread, no need to spawn a new one.
    if (EnqueueOnAnyThread(process, thread_id)) return;
  }

  // Start a worker thread, if less than [processes_] threads are running.
  while (!thread_pool_.TryStartThread(RunThread, this, processes_)) {
  }
}

void Scheduler::PushIdleThread(ThreadState* thread_state) {
  ThreadState* idle_threads = idle_threads_;
  while (true) {
    if (idle_threads == kLockedThreadState) {
      idle_threads = idle_threads_;
    } else if (idle_threads_.compare_exchange_weak(idle_threads,
                                                   kLockedThreadState)) {
      break;
    }
  }

  ASSERT(idle_threads != NULL);

  // Add thread_state to idle_threads_, if it is not already in it.
  if (thread_state->next_idle_thread() == NULL) {
    thread_state->set_next_idle_thread(idle_threads);
    idle_threads = thread_state;
  }

  idle_threads_ = idle_threads;
}

ThreadState* Scheduler::PopIdleThread() {
  ThreadState* idle_threads = idle_threads_;
  while (true) {
    if (idle_threads == kEmptyThreadState) {
      return NULL;
    } else if (idle_threads == kLockedThreadState) {
      idle_threads = idle_threads_;
    } else if (idle_threads_.compare_exchange_weak(idle_threads,
                                                   kLockedThreadState)) {
      break;
    }
  }

  ThreadState* next = idle_threads->next_idle_thread();
  idle_threads->set_next_idle_thread(NULL);

  idle_threads_ = next;

  return idle_threads;
}

void Scheduler::RunInThread() {
  ThreadState* thread_state = new ThreadState();
  ThreadEnter(thread_state);
  while (true) {
    if (processes_ == 0) {
      preempt_monitor_->Lock();
      preempt_monitor_->Notify();
      preempt_monitor_->Unlock();
      break;
    } else if (pause_) {
      LookupCache* cache = thread_state->cache();
      if (cache != NULL) cache->Clear();

      // Take lock to be sure StopProgram is waiting.
      {
        ScopedMonitorLock locker(pause_monitor_);
        sleeping_threads_++;
        pause_monitor_->NotifyAll();
      }
      {
        ScopedMonitorLock idle_locker(thread_state->idle_monitor());
        while (pause_) thread_state->idle_monitor()->Wait();
      }
      {
        ScopedMonitorLock locker(pause_monitor_);
        sleeping_threads_--;
        pause_monitor_->NotifyAll();
      }
    } else {
      RunInterpreterLoop(thread_state);
    }

    // Sleep until there is something new to execute.
    ScopedMonitorLock scoped_lock(thread_state->idle_monitor());
    while (thread_state->queue()->is_empty() && startup_queue_->is_empty() &&
           !pause_ && processes_ > 0) {
      PushIdleThread(thread_state);
      // The thread is becoming idle.
      thread_state->idle_monitor()->Wait();
      // At this point the thread_state may still be in idle_threads_. That's
      // okay, as it will just be ignored later on.
    }
  }
  ThreadExit(thread_state);
}

#ifdef FLETCH_ENABLE_MULTIPLE_PROCESS_HEAPS

void Scheduler::RunInterpreterLoop(ThreadState* thread_state) {
  // We use this heap for allocating new immutable objects.
  Program* program = NULL;
  SharedHeap* shared_heap = NULL;
  SharedHeap::Part* shared_heap_part = NULL;

  while (!pause_) {
    Process* process = NULL;
    DequeueFromThread(thread_state, &process);
    // No more processes for this state, break.
    if (process == NULL) break;

    while (process != NULL) {
      // If we changed programs, merge the current part back to it's heap
      // and get a new part from the new program.
      if (process->program() != program) {
        if (shared_heap_part != NULL) {
          if (shared_heap->ReleasePart(shared_heap_part)) {
            gc_thread_->TriggerImmutableGC(program);
          }
        }
        program = process->program();
        shared_heap = program->shared_heap();
        shared_heap_part = shared_heap->AcquirePart();
      }

      // Interpret and trigger GC if interpretation resulted in immutable
      // allocation failure.
      bool allocation_failure = false;
      Process* new_process = InterpretProcess(
          process, shared_heap_part->heap(), thread_state, &allocation_failure);
      if (allocation_failure) {
        if (shared_heap->ReleasePart(shared_heap_part)) {
          gc_thread_->TriggerImmutableGC(program);
        }
        shared_heap_part = shared_heap->AcquirePart();
      }

      // Possibly switch to a new process.
      process = new_process;
    }
  }

  // Always merge remaining immutable heap part back before (possibly) going
  // to sleep.
  if (shared_heap != NULL && shared_heap->ReleasePart(shared_heap_part)) {
    gc_thread_->TriggerImmutableGC(program);
  }
}

#else  // FLETCH_ENABLE_MULTIPLE_PROCESS_HEAPS

void Scheduler::RunInterpreterLoop(ThreadState* thread_state) {
  // We use this heap for allocating new immutable objects.
  while (!pause_) {
    Process* process = NULL;
    DequeueFromThread(thread_state, &process);
    // No more processes for this state, break.
    if (process == NULL) break;

    while (process != NULL) {
      bool allocation_failure = false;
      Heap* shared_heap = process->program()->shared_heap()->heap();

      Process* new_process = InterpretProcess(
          process, shared_heap, thread_state, &allocation_failure);

      if (allocation_failure) {
        // Can never run into an immutable allocation failure.
        UNREACHABLE();
      }

      // Possibly switch to a new process.
      process = new_process;
    }
  }
}

#endif  // FLETCH_ENABLE_MULTIPLE_PROCESS_HEAPS

void Scheduler::SetCurrentProcessForThread(int thread_id, Process* process) {
  if (thread_id == -1) return;
  Process* value = current_processes_[thread_id];
  while (true) {
    if (value == kPreemptMarker) {
      process->Preempt();
      current_processes_[thread_id] = process;
      break;
    } else {
      // Take value at each attempt, as value will be overriden on failure.
      if (current_processes_[thread_id].compare_exchange_weak(value, process)) {
        break;
      }
    }
  }
}

void Scheduler::ClearCurrentProcessForThread(int thread_id, Process* process) {
  if (thread_id == -1) return;
  while (true) {
    // Take value at each attempt, as value will be overriden on failure.
    Process* value = process;
    if (current_processes_[thread_id].compare_exchange_weak(value, NULL)) {
      break;
    }
  }
}

Process* Scheduler::InterpretProcess(Process* process, Heap* shared_heap,
                                     ThreadState* thread_state,
                                     bool* allocation_failure) {
  ASSERT(process->exception()->IsNull());

  Signal* signal = process->signal();
  if (signal != NULL) {
    process->ChangeState(Process::kRunning, Process::kTerminated);
    if (signal->kind() == Signal::kShouldKill) {
      HANDLE_BY_SESSION_OR_SELF(session->Killed(process),
                                ExitAtTermination(process, Signal::kKilled));
    } else {
      HANDLE_BY_SESSION_OR_SELF(
          session->UncaughtSignal(process),
          ExitAtTermination(process, Signal::kUnhandledSignal));
    }

    return NULL;
  }

  int thread_id = thread_state->thread_id();
  SetCurrentProcessForThread(thread_id, process);

  // Mark the process as owned by the current thread while interpreting.
  process->set_thread_state(thread_state);
  Interpreter interpreter(process);

  // Warning: These two lines should not be moved, since the code further down
  // will potentially push the process on a queue which is accessed by other
  // threads, which would create a race.
  shared_heap->set_random(process->random());
  process->set_immutable_heap(shared_heap);
  interpreter.Run();
  process->set_immutable_heap(NULL);
  shared_heap->set_random(NULL);

  process->set_thread_state(NULL);
  ClearCurrentProcessForThread(thread_id, process);

  if (interpreter.IsImmutableAllocationFailure()) {
#if !defined(FLETCH_ENABLE_MULTIPLE_PROCESS_HEAPS)
    UNREACHABLE();
#endif
    *allocation_failure = true;
    return process;
  }

  if (interpreter.IsYielded()) {
    process->ChangeState(Process::kRunning, Process::kYielding);
    if (process->mailbox()->IsEmpty() && process->signal() == NULL) {
      process->ChangeState(Process::kYielding, Process::kSleeping);
    } else {
      process->ChangeState(Process::kYielding, Process::kReady);
      EnqueueOnThread(thread_state, process);
    }
    return NULL;
  }

  if (interpreter.IsTargetYielded()) {
    TargetYieldResult result = interpreter.target_yield_result();

    // The returned port currently has the lock. Unlock as soon as we know the
    // process is not kRunning (ChangeState either succeeded or failed).
    Port* port = result.port();
    ASSERT(port != NULL);
    ASSERT(port->IsLocked());
    Process* target = port->process();
    ASSERT(target != NULL);

    // TODO(ajohnsen): If the process is terminating and it's resuming another
    // process, consider returning that process.
    bool terminate = result.ShouldTerminate();

    if (target->ChangeState(Process::kSleeping, Process::kRunning)) {
      port->Unlock();
      RescheduleProcess(process, thread_state, terminate);
      return target;
    } else {
      ProcessQueue* target_queue = target->process_queue();
      if (target_queue != NULL && target_queue->TryDequeueEntry(target)) {
        port->Unlock();
        ASSERT(target->state() == Process::kRunning);
        RescheduleProcess(process, thread_state, terminate);
        return target;
      }
    }
    port->Unlock();
    RescheduleProcess(process, thread_state, terminate);
    return NULL;
  }

  if (interpreter.IsInterrupted()) {
    // No need to notify threads, as 'this' is now available.
    process->ChangeState(Process::kRunning, Process::kReady);
    EnqueueOnThread(thread_state, process);
    return NULL;
  }

  if (interpreter.IsTerminated()) {
    process->ChangeState(Process::kRunning, Process::kTerminated);
    HANDLE_BY_SESSION_OR_SELF(session->ProcessTerminated(process),
                              ExitAtTermination(process, Signal::kTerminated));
    return NULL;
  }

  if (interpreter.IsUncaughtException()) {
    process->ChangeState(Process::kRunning, Process::kUncaughtException);
    HANDLE_BY_SESSION_OR_SELF(session->UncaughtException(process),
                              ExitAtUncaughtException(process, true));
    return NULL;
  }

  if (interpreter.IsCompileTimeError()) {
    process->ChangeState(Process::kRunning, Process::kCompileTimeError);
    HANDLE_BY_SESSION_OR_SELF(session->CompileTimeError(process),
                              ExitAtCompileTimeError(process));
    return NULL;
  }

  if (interpreter.IsAtBreakPoint()) {
    process->ChangeState(Process::kRunning, Process::kBreakPoint);
    // We should only reach a breakpoint if a session is attached and it can
    // handle [process].
    HANDLE_BY_SESSION_OR_SELF(
        session->BreakPoint(process),
        FATAL("We should never hit a breakpoint without a session being able "
              "to handle it."));
    return NULL;
  }

  UNREACHABLE();
  return NULL;
}

void Scheduler::ThreadEnter(ThreadState* thread_state) {
  Thread::BlockOSSignals();
  // TODO(ajohnsen): This only works because we never return threads, unless
  // the scheduler is done.
  int thread_id = thread_count_++;
  ASSERT(thread_id < max_threads_);
  thread_state->set_thread_id(thread_id);
  threads_[thread_id] = thread_state;
  // Notify pause_monitor_ when changing threads_.
  pause_monitor_->Lock();
  pause_monitor_->NotifyAll();
  pause_monitor_->Unlock();
}

void Scheduler::ThreadExit(ThreadState* thread_state) {
  threads_[thread_state->thread_id()] = NULL;
  ReturnThreadState(thread_state);
  // Notify pause_monitor_ when changing threads_.
  pause_monitor_->Lock();
  pause_monitor_->NotifyAll();
  pause_monitor_->Unlock();
  Thread::UnblockOSSignals();
}

static void NotifyThread(ThreadState* thread_state) {
  Monitor* monitor = thread_state->idle_monitor();
  monitor->Lock();
  monitor->Notify();
  monitor->Unlock();
}

void Scheduler::NotifyAllThreads() {
  for (int i = 0; i < thread_count_; i++) {
    ThreadState* thread_state = threads_[i];
    if (thread_state != NULL) NotifyThread(thread_state);
  }
}

void Scheduler::ReturnThreadState(ThreadState* thread_state) {
  ThreadState* next = thread_states_to_delete_;
  while (true) {
    thread_state->set_next_idle_thread(next);
    if (thread_states_to_delete_.compare_exchange_weak(next, thread_state)) {
      break;
    }
  }
}

void Scheduler::DequeueFromThread(ThreadState* thread_state,
                                  Process** process) {
  ASSERT(*process == NULL);
  while (!TryDequeueFromAnyThread(process, thread_state->thread_id())) {
  }
}

static bool TryDequeue(ProcessQueue* queue, Process** process,
                       bool* should_retry) {
  if (queue->TryDequeue(process)) {
    if (*process != NULL) {
      return true;
    }
  } else {
    *should_retry = true;
  }
  return false;
}

bool Scheduler::TryDequeueFromAnyThread(Process** process, int start_id) {
  ASSERT(*process == NULL);
  int count = thread_count_;
  bool should_retry = false;
  for (int i = start_id; i < count; i++) {
    ThreadState* thread_state = threads_[i];
    if (thread_state == NULL) continue;
    if (TryDequeue(thread_state->queue(), process, &should_retry)) return true;
  }
  for (int i = 0; i < start_id; i++) {
    ThreadState* thread_state = threads_[i];
    if (thread_state == NULL) continue;
    if (TryDequeue(thread_state->queue(), process, &should_retry)) return true;
  }
  // TODO(ajohnsen): Merge startup_queue_ into the first thread we start, or
  // use it for queing other proceses as well?
  if (TryDequeue(startup_queue_, process, &should_retry)) return true;
  return !should_retry;
}

void Scheduler::EnqueueOnThread(ThreadState* thread_state, Process* process) {
  if (thread_state->thread_id() == -1) {
    EnqueueOnAnyThread(process);
    return;
  }
  while (!thread_state->queue()->TryEnqueue(process)) {
    int count = thread_count_;
    for (int i = 0; i < count; i++) {
      ThreadState* thread_state = threads_[i];
      if (thread_state != NULL && thread_state->queue()->TryEnqueue(process)) {
        return;
      }
    }
  }
}

bool Scheduler::TryEnqueueOnIdleThread(Process* process) {
  while (true) {
    ThreadState* thread_state = PopIdleThread();
    if (thread_state == NULL) return false;
    bool was_empty = false;
    bool enqueued = thread_state->queue()->TryEnqueue(process, &was_empty);
    // Always notify the idle thread, so it can be re-inserted into the idle
    // thread pool.
    NotifyThread(thread_state);
    // We enqueued, we are done. Otherwise, try another.
    if (enqueued) return true;
  }
  UNREACHABLE();
  return false;
}

bool Scheduler::EnqueueOnAnyThread(Process* process, int start_id) {
  ASSERT(process->state() == Process::kReady);
  // First try to resume an idle thread.
  if (TryEnqueueOnIdleThread(process)) return true;
  // Loop threads until enqueued.
  int i = start_id;
  while (true) {
    if (i >= thread_count_) i = 0;
    ThreadState* thread_state = threads_[i];
    bool was_empty = false;
    if (thread_state != NULL &&
        thread_state->queue()->TryEnqueue(process, &was_empty)) {
      if (was_empty && current_processes_[i].load() == NULL) {
        NotifyThread(thread_state);
      }
      return false;
    }
    i++;
  }
  UNREACHABLE();
  return false;
}

void Scheduler::EnqueueOnAnyThreadSafe(Process* process, int start_id) {
  // There can be two cases: Either the program is stopped at the moment or
  // not. If it is stopped, we add the process to the list of paused processes
  // and otherwise we enqueue it on any thread.
  ScopedMonitorLock locker(pause_monitor_);

  Program* program = process->program();
  ASSERT(program->scheduler() == this);
  ProgramState* state = program->program_state();
  if (state->is_paused()) {
    // If the program is paused, there is no way the process can be enqueued
    // on any process queues.
    ASSERT(process->process_queue() == NULL);

    // Only add the process into the paused list if it is not already in
    // there.
    if (process->next() == NULL) {
      state->AddPausedProcess(process);
    }
  } else {
    EnqueueOnAnyThread(process, start_id);
  }
}

void Scheduler::RunThread(void* data) {
  Scheduler* scheduler = reinterpret_cast<Scheduler*>(data);
  scheduler->RunInThread();
}

}  // namespace fletch
