// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
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

namespace dartino {

// Global instance of scheduler.
Scheduler* Scheduler::scheduler_ = NULL;

WorkerThread::WorkerThread(Scheduler* scheduler)
    : scheduler_(scheduler) {}

WorkerThread::~WorkerThread() { }

void InterpretationBarrier::PreemptProcess() {
  Process* process = current_process;
  while (true) {
    if (process == kPreemptMarker) {
      break;
    } else if (process == NULL) {
      if (current_process.compare_exchange_weak(process, kPreemptMarker)) {
        break;
      }
    } else {
      if (current_process.compare_exchange_weak(process, NULL)) {
        process->Preempt();
        current_process = process;
        break;
      }
    }
  }
}

void InterpretationBarrier::Enter(Process* process) {
  Process* value = current_process;
  while (true) {
    if (value == kPreemptMarker) {
      process->Preempt();
      current_process = process;
      break;
    } else {
      if (current_process.compare_exchange_weak(value, process)) {
        break;
      }
    }
  }
}

void InterpretationBarrier::Leave(Process* process) {
  // NOTE: This method will ensure we wait until [PreemptProcess] calls
  // (on other threads) are done before we go out of this function.

  while (true) {
    // Take value at each attempt, as value will be overriden on failure.
    Process* value = process;
    if (current_process.compare_exchange_weak(value, NULL)) {
      break;
    }
  }
}

void Scheduler::Setup() {
  ASSERT(scheduler_ == NULL);
  scheduler_ = new Scheduler();
  scheduler_->gc_thread_->StartThread();
}

void Scheduler::TearDown() {
  ASSERT(scheduler_ != NULL);
  scheduler_->shutdown_ = true;
  scheduler_->NotifyInterpreterThread();
  scheduler_->gc_thread_->StopThread();
  delete scheduler_;
  scheduler_ = NULL;
}

Scheduler::Scheduler()
    : interpreter_is_paused_(false),
      ready_queue_(new ProcessQueue()),
      pause_monitor_(Platform::CreateMonitor()),
      pause_(false),
      shutdown_(false),
      idle_monitor_(Platform::CreateMonitor()),
      interpreter_semaphore_(1),
      gc_thread_(new GCThread()) {
  for (int i = 0; i < kThreadCount; i++) {
    WorkerThread* worker = new WorkerThread(this);
    threads_[i] = worker;
    thread_ids_[i] = Thread::Run(WorkerThread::RunThread, worker);
  }
}

Scheduler::~Scheduler() {
  for (int i = 0; i < kThreadCount; i++) {
    thread_ids_[i].Join();
    delete threads_[i];
  }

  delete idle_monitor_;
  delete pause_monitor_;
  delete ready_queue_;
  delete gc_thread_;
}

void Scheduler::ScheduleProgram(Program* program, Process* main_process) {
  program->set_scheduler(this);

  ScopedMonitorLock locker(pause_monitor_);

  // NOTE: Even though this method might be run on any thread, we don't need to
  // guard against the program being stopped, since we insert it the very first
  // time.
  program->program_state()->IncreaseProcessCount();
  program->program_state()->Retain();
  if (!main_process->ChangeState(Process::kSleeping, Process::kReady)) {
    UNREACHABLE();
  }
  EnqueueProcess(main_process);
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
    NotifyInterpreterThread();

    while (true) {
      interpretation_barrier_.PreemptProcess();
      if (interpreter_is_paused_) break;
      pause_monitor_->Wait();
    }

    Process* to_enqueue = NULL;

    while (true) {
      Process* process = NULL;
      // All processes dequeued are marked as Running.
      DequeueProcess(&process);

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
      Process* next = to_enqueue->next();
      to_enqueue->set_next(NULL);
      EnqueueProcess(to_enqueue);
      to_enqueue = next;
    }

    // TODO(kustermann): Stopping a program should not always clear the lookup
    // cache. But if we don't do, then other code might decide to do a
    // ProgramGC (e.g. gc thread) or rewrite instances (e.g. session) and the
    // lookup cache entries are broken.
    //
    // => We should move the responsibility of clearing the cache to the caller
    //    of StopProgram().
    LookupCache* cache = program->cache();
    if (cache != NULL) cache->Clear();

    pause_ = false;
  }

  NotifyInterpreterThread();
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
      EnqueueProcess(process);
      process = next;
    }
    program_state->set_paused_processes_head(NULL);
    program_state->set_is_paused(false);
    pause_monitor_->NotifyAll();
  }
  NotifyInterpreterThread();
}

void Scheduler::KillProgram(Program* program) {
  ASSERT(program->scheduler() == this);
  ProcessHandle* handle = program->MainProcess();
  if (handle == NULL) return;
  Signal* signal = new Signal(handle, Signal::kShouldKill);
  ProcessHandle::DecrementRef(handle);
  {
    ScopedSpinlock locker(handle->lock());
    Process* process = handle->process();
    if (process != NULL) {
      process->SendSignal(signal);
      SignalProcess(process);
    }
  }
}

void Scheduler::PauseGcThread() {
  ASSERT(gc_thread_ != NULL);
  gc_thread_->Pause();
}

void Scheduler::ResumeGcThread() {
  ASSERT(gc_thread_ != NULL);
  gc_thread_->Resume();
}

void Scheduler::PreemptionTick() {
  interpretation_barrier_.PreemptProcess();
}

void Scheduler::FinishedGC(Program* program, int count) {
  ASSERT(count > 0);
  ProgramState* state = program->program_state();
  if (state->Release(count)) program->NotifyExitListener();
}

void Scheduler::EnqueueProcessOnSchedulerWorkerThread(
    Process* interpreting_process, Process* process) {
  process->program()->program_state()->IncreaseProcessCount();
  if (!process->ChangeState(Process::kSleeping, Process::kReady)) UNREACHABLE();

  EnqueueProcess(process);
}

void Scheduler::ResumeProcess(Process* process) {
  if (!process->ChangeState(Process::kSleeping, Process::kReady)) return;
  EnqueueSafe(process);
}

void Scheduler::SignalProcess(Process* process) {
  while (true) {
    switch (process->state()) {
      case Process::kSleeping:
        if (process->ChangeState(Process::kSleeping, Process::kReady)) {
          // TODO(kustermann): If it is guaranteed that [SignalProcess] is only
          // called from a scheduler worker thread, we could use the non *Safe*
          // method here (which doesn't guard against stopped programs).
          EnqueueSafe(process);
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
  EnqueueSafe(process);
}

bool Scheduler::EnqueueProcess(Process* process, Port* port) {
  ASSERT(port->IsLocked());

  if (!process->ChangeState(Process::kSleeping, Process::kReady)) {
    port->Unlock();
    return false;
  }
  port->Unlock();
  EnqueueSafe(process);

  return true;
}

void Scheduler::DequeueProcess(Process** process) {
  while (!ready_queue_->TryDequeue(process)) {}
}

void Scheduler::DeleteTerminatedProcess(Process* process, Signal::Kind kind) {
  Program* program = process->program();
  ProgramState* state = program->program_state();

  program->ScheduleProcessForDeletion(process, kind);

  if (Flags::gc_on_delete) {
    ASSERT(gc_thread_ != NULL);

    state->Retain();
    gc_thread_->TriggerGC(program);
  }

  if (state->DecreaseProcessCount()) {
    // TODO(kustermann): Conditional on result of ScheduleProcessForDeletion.
    if (state->Release()) program->NotifyExitListener();
  }
}

void Scheduler::ExitAtTermination(Process* process, Signal::Kind kind) {
  ASSERT(process->state() == Process::kTerminated);
  process->ChangeState(Process::kTerminated, Process::kWaitingForChildren);

  DeleteTerminatedProcess(process, kind);
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
          if (function == NULL) continue;

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
}

void Scheduler::RescheduleProcess(Process* process, bool terminate) {
  ASSERT(process->state() == Process::kRunning);
  if (terminate) {
    process->ChangeState(Process::kRunning, Process::kTerminated);
    ExitAtTermination(process, Signal::kTerminated);
  } else {
    process->ChangeState(Process::kRunning, Process::kReady);
    EnqueueProcess(process);
  }
}

void WorkerThread::RunInThread() {
  ThreadEnter();
  bool running = true;
  while (running) {
    scheduler_->interpreter_semaphore_.Down();
    running = scheduler_->RunInterpreterLoop(this);
    scheduler_->interpreter_semaphore_.Up();
  }
  ThreadExit();
}

bool Scheduler::RunInterpreterLoop(WorkerThread* worker) {
  while (true) {
    // Run fletch processes as long as we're not paused or shut down
    // (and there is work to do).
    while (!pause_ && !shutdown_) {
      Process* process = NULL;
      DequeueProcess(&process);

      // No more processes for this state, break.
      if (process == NULL) break;

      while (process != NULL && !shutdown_ && !pause_) {
        process = InterpretProcess(process, worker);
      }
      if (process != NULL) {
        process->ChangeState(Process::kRunning, Process::kReady);
        EnqueueProcess(process);
      }
    }

    if (shutdown_) break;

    if (pause_) {
      // Take lock to be sure StopProgram is waiting.
      {
        ScopedMonitorLock locker(pause_monitor_);
        interpreter_is_paused_ = true;
        pause_monitor_->NotifyAll();
      }
      {
        ScopedMonitorLock idle_locker(idle_monitor_);
        while (pause_) idle_monitor_->Wait();
      }
      {
        ScopedMonitorLock locker(pause_monitor_);
        interpreter_is_paused_ = false;
        pause_monitor_->NotifyAll();
      }
      continue;
    }

    // Sleep until there is something new to execute.
    ScopedMonitorLock scoped_lock(idle_monitor_);
    while (ready_queue_->is_empty() && !pause_ && !shutdown_) {
      idle_monitor_->Wait();
    }
    if (shutdown_) break;
  }

  return false;
}

Process* Scheduler::InterpretProcess(Process* process, WorkerThread* worker) {
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

  interpretation_barrier_.Enter(process);

  // Mark the process as owned by the current thread while interpreting.
  Thread::SetProcess(process);
  Interpreter interpreter(process);

  // Warning: These two lines should not be moved, since the code further down
  // will potentially push the process on a queue which is accessed by other
  // threads, which would create a race.
  process->heap()->set_random(process->random());
  interpreter.Run();
  process->heap()->set_random(NULL);

  Thread::SetProcess(NULL);

  interpretation_barrier_.Leave(process);

  if (interpreter.IsYielded()) {
    process->ChangeState(Process::kRunning, Process::kYielding);
    if (process->mailbox()->IsEmpty() && process->signal() == NULL) {
      process->ChangeState(Process::kYielding, Process::kSleeping);
    } else {
      process->ChangeState(Process::kYielding, Process::kReady);
      EnqueueProcess(process);
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
      RescheduleProcess(process, terminate);
      return target;
    } else {
      if (ready_queue_->TryDequeueEntry(target)) {
        port->Unlock();
        ASSERT(target->state() == Process::kRunning);
        RescheduleProcess(process, terminate);
        return target;
      }
    }
    port->Unlock();
    RescheduleProcess(process, terminate);
    return NULL;
  }

  if (interpreter.IsInterrupted()) {
    // No need to notify threads, as 'this' is now available.
    process->ChangeState(Process::kRunning, Process::kReady);
    EnqueueProcess(process);
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

void WorkerThread::ThreadEnter() {
  Thread::SetupOSSignals();
  scheduler_->pause_monitor_->Lock();
  scheduler_->pause_monitor_->NotifyAll();
  scheduler_->pause_monitor_->Unlock();
}

void WorkerThread::ThreadExit() {
  scheduler_->pause_monitor_->Lock();
  scheduler_->pause_monitor_->NotifyAll();
  scheduler_->pause_monitor_->Unlock();
  Thread::TeardownOSSignals();
}

void Scheduler::NotifyInterpreterThread() {
  Monitor* monitor = idle_monitor_;
  monitor->Lock();
  monitor->Notify();
  monitor->Unlock();
}

void Scheduler::EnqueueProcess(Process* process) {
  ASSERT(process->state() == Process::kReady);

  bool was_empty = false;
  while (!ready_queue_->TryEnqueue(process, &was_empty)) {}

  // Maybe we need to wake one up.
  if (was_empty) NotifyInterpreterThread();
}

void Scheduler::EnqueueSafe(Process* process) {
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
    EnqueueProcess(process);
  }
}

void* WorkerThread::RunThread(void* data) {
  WorkerThread* state = reinterpret_cast<WorkerThread*>(data);
  state->RunInThread();
  return NULL;
}

SimpleProgramRunner::SimpleProgramRunner()
    : monitor_(new Monitor()),
      programs_(NULL),
      exitcodes_(NULL),
      count_(0),
      remaining_(0) {
}

SimpleProgramRunner::~SimpleProgramRunner() {
  delete monitor_;
}

void SimpleProgramRunner::Run(int count,
                              int* exitcodes,
                              Program** programs,
                              Process** processes) {
  programs_ = programs;
  exitcodes_ = exitcodes;
  count_ = count;
  remaining_ = count;

  Scheduler* scheduler = Scheduler::GlobalInstance();
  for (int i = 0; i < count; i++) {
    Program* program = programs[i];
    Process* process = processes != NULL ? processes[i] : NULL;

    program->SetProgramExitListener(
        &SimpleProgramRunner::CaptureExitCode, this);
    if (process == NULL) process = program->ProcessSpawnForMain();
    scheduler->ScheduleProgram(program, process);
  }

  {
    ScopedMonitorLock locker(monitor_);
    while (remaining_ > 0) {
      monitor_->Wait();
    }
  }

  for (int i = 0; i < count; i++) {
    scheduler->UnscheduleProgram(programs[i]);
  }
}

void SimpleProgramRunner::CaptureExitCode(Program* program,
                                          int exitcode,
                                          void* data) {
  SimpleProgramRunner* runner = reinterpret_cast<SimpleProgramRunner*>(data);
  ScopedMonitorLock locker(runner->monitor_);
  for (int i = 0; i < runner->count_; i++) {
    if (runner->programs_[i] == program) {
      runner->exitcodes_[i] = exitcode;
      runner->remaining_--;
      runner->monitor_->NotifyAll();
      return;
    }
  }
  UNREACHABLE();
}

}  // namespace dartino
