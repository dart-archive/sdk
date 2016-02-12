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
  delete gc_thread_;
}

void Scheduler::ScheduleProgram(Program* program, Process* main_process) {
  ScopedMonitorLock locker(pause_monitor_);

  program->set_scheduler(this);
  programs_.Append(program);

  // NOTE: Even though this method might be run on any thread, we don't need to
  // guard against the program being stopped, since we insert it the very first
  // time.
  ProgramState* state = program->program_state();
  state->ChangeState(ProgramState::kInitialized, ProgramState::kRunning);
  state->IncreaseProcessCount();
  state->Retain();

  if (!main_process->ChangeState(Process::kSleeping, Process::kReady)) {
    UNREACHABLE();
  }
  EnqueueProcess(main_process);
}

void Scheduler::UnscheduleProgram(Program* program) {
  ScopedMonitorLock locker(pause_monitor_);

  ASSERT(program->scheduler() == this);
  programs_.Remove(program);
  program->set_scheduler(NULL);
  program->program_state()->ChangeState(
      ProgramState::kDone, ProgramState::kPendingDeletion);
}

void Scheduler::StopProgram(Program* program, ProgramState::State stop_state) {
  ASSERT(program->scheduler() == this);

  {
    ScopedMonitorLock pause_locker(pause_monitor_);

    ProgramState* program_state = program->program_state();
    while (program_state->state() != ProgramState::kRunning) {
      pause_monitor_->Wait();
    }
    program_state->ChangeState(ProgramState::kRunning, stop_state);

    pause_ = true;
    NotifyInterpreterThread();

    while (true) {
      interpretation_barrier_.PreemptProcess();
      if (interpreter_is_paused_) break;
      pause_monitor_->Wait();
    }

    ready_queue_.PauseAllProcessesOfProgram(program);

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

void Scheduler::ResumeProgram(Program* program,
                              ProgramState::State stop_state) {
  ASSERT(program->scheduler() == this);

  {
    ScopedMonitorLock locker(pause_monitor_);

    ProgramState* program_state = program->program_state();
    ASSERT(program_state->state() == stop_state);

    auto paused_processes = program_state->paused_processes();
    while (!paused_processes->IsEmpty()) {
      Process* process = paused_processes->RemoveFirst();
      EnqueueProcess(process);
    }
    program_state->ChangeState(stop_state, ProgramState::kRunning);
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
  if (state->Release(count)) {
    program->program_state()->ChangeState(ProgramState::kRunning,
                                          ProgramState::kDone);
    program->NotifyExitListener();
  }
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

bool Scheduler::DequeueProcess(Process** process) {
  return ready_queue_.TryDequeue(process);
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
    if (state->Release()) {
      state->ChangeState(ProgramState::kRunning, ProgramState::kDone);
      program->NotifyExitListener();
    }
  }
}

void Scheduler::RescheduleProcess(Process* process, bool terminate) {
  ASSERT(process->state() == Process::kRunning);
  if (terminate) {
    process->ChangeState(Process::kRunning, Process::kWaitingForChildren);
    DeleteTerminatedProcess(process, Signal::kTerminated);
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
    // Run dartino processes as long as we're not paused or shut down
    // (and there is work to do).
    while (!pause_ && !shutdown_) {
      Process* process = NULL;
      if (!DequeueProcess(&process)) break;

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
    while (ready_queue_.IsEmpty() && !pause_ && !shutdown_) {
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
    if (signal->kind() == Signal::kShouldKill) {
      HandleKilled(process);
    } else {
      HandleUncaughtSignal(process);
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
      if (ready_queue_.TryDequeueEntry(target)) {
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
    HandleTerminated(process);
    return NULL;
  }

  if (interpreter.IsUncaughtException()) {
    HandleUncaughtException(process);
    return NULL;
  }

  if (interpreter.IsCompileTimeError()) {
    HandleCompileTimeError(process);
    return NULL;
  }

  if (interpreter.IsAtBreakPoint()) {
    HandleBreakpoint(process);
    return NULL;
  }

  UNREACHABLE();
  return NULL;
}

void Scheduler::HandleKilled(Process* process) {
  Process::State state = Process::kTerminated;
  ProcessInterruptionEvent result = kExitWithKilledSignal;
  Session* session = process->program()->session();
  process->ChangeState(Process::kRunning, state);
  if (session != NULL && session->CanHandleEvents()) {
    result = session->Killed(process);
  }
  HandleEventResult(result, process, state);
}

void Scheduler::HandleUncaughtSignal(Process* process) {
  Process::State state = Process::kTerminated;
  ProcessInterruptionEvent result = kExitWithUncaughtSignal;
  Session* session = process->program()->session();
  process->ChangeState(Process::kRunning, state);
  if (session != NULL && session->CanHandleEvents()) {
    result = session->UncaughtSignal(process);
  }
  HandleEventResult(result, process, state);
}

void Scheduler::HandleTerminated(Process* process) {
  Process::State state = Process::kTerminated;
  ProcessInterruptionEvent result = kExitWithoutError;
  Session* session = process->program()->session();
  process->ChangeState(Process::kRunning, state);
  if (session != NULL && session->CanHandleEvents()) {
    result = session->ProcessTerminated(process);
  }
  HandleEventResult(result, process, state);
}

void Scheduler::HandleUncaughtException(Process* process) {
  Process::State state = Process::kUncaughtException;
  ProcessInterruptionEvent result =
      kExitWithUncaughtExceptionAndPrintStackTrace;
  Session* session = process->program()->session();
  process->ChangeState(Process::kRunning, state);
  if (session != NULL && session->CanHandleEvents()) {
    result = session->UncaughtException(process);
  }
  HandleEventResult(result, process, state);
}

void Scheduler::HandleCompileTimeError(Process* process) {
  Process::State state = Process::kCompileTimeError;
  ProcessInterruptionEvent result = kExitWithCompileTimeError;
  Session* session = process->program()->session();
  process->ChangeState(Process::kRunning, state);
  if (session != NULL && session->CanHandleEvents()) {
    result = session->CompileTimeError(process);
  }
  HandleEventResult(result, process, state);
}

void Scheduler::HandleBreakpoint(Process* process) {
  Process::State state = Process::kBreakPoint;
  ProcessInterruptionEvent result = kExitWithoutError;
  Session* session = process->program()->session();
  process->ChangeState(Process::kRunning, state);
  if (session != NULL && session->CanHandleEvents()) {
    result = session->BreakPoint(process);
  }
  HandleEventResult(result, process, state);
}

void Scheduler::HandleEventResult(
    ProcessInterruptionEvent result, Process* process, Process::State state) {
  switch (result) {
    case kExitWithCompileTimeError: {
      process->ChangeState(state, Process::kWaitingForChildren);
      DeleteTerminatedProcess(process, Signal::kCompileTimeError);
      break;
    }
    case kExitWithUncaughtExceptionAndPrintStackTrace: {
      process->PrintStackTrace();
      // Fall through
    }
    case kExitWithUncaughtException: {
      process->ChangeState(state, Process::kWaitingForChildren);
      DeleteTerminatedProcess(process, Signal::kUncaughtException);
      break;
    }
    case kExitWithUncaughtSignal: {
      process->ChangeState(state, Process::kWaitingForChildren);
      DeleteTerminatedProcess(process, Signal::kUnhandledSignal);
      break;
    }
    case kExitWithKilledSignal: {
      process->ChangeState(state, Process::kWaitingForChildren);
      DeleteTerminatedProcess(process, Signal::kKilled);
      break;
    }
    case kExitWithoutError: {
      process->ChangeState(state, Process::kWaitingForChildren);
      DeleteTerminatedProcess(process, Signal::kTerminated);
      break;
    }
    case kNoAction: {
      // Nothing to do.
      break;
    }
    default: {
      UNREACHABLE();
    }
  }
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

  if (ready_queue_.Enqueue(process)) {
    // If the queue was empty, we'll notify the interpreter thread.
    NotifyInterpreterThread();
  }
}

void Scheduler::EnqueueSafe(Process* process) {
  // There can be two cases: Either the program is stopped at the moment or
  // not. If it is stopped, we add the process to the list of paused processes
  // and otherwise we enqueue it on any thread.
  ScopedMonitorLock locker(pause_monitor_);

  Program* program = process->program();
  ASSERT(program->scheduler() == this);
  ProgramState* state = program->program_state();
  if (state->state() != ProgramState::kRunning) {
    // Only add the process into the paused list if it is not already in
    // there.
    if (!state->paused_processes()->IsInList(process)) {
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
                              int argc, char** argv,
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
    List<List<uint8>> arguments = List<List<uint8>>::New(argc);
    for (int i = 0; i < argc; i++) {
      uint8* utf8 = reinterpret_cast<uint8*>(strdup(argv[i]));
      arguments[i] = List<uint8>(utf8, strlen(argv[i]));
    }
    if (process == NULL) process = program->ProcessSpawnForMain(arguments);
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
