// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SCHEDULER_H_
#define SRC_VM_SCHEDULER_H_

#include "src/shared/atomic.h"

#include "src/vm/signal.h"
#include "src/vm/thread.h"
#include "src/vm/process_queue.h"
#include "src/vm/program.h"

namespace dartino {

class GCThread;
class Heap;
class Object;
class Port;
class Process;
class Scheduler;

class WorkerThread {
 public:
  static void* RunThread(void* data);

  explicit WorkerThread(Scheduler* scheduler);
  ~WorkerThread();

 private:
  void RunInThread();
  void ThreadEnter();
  void ThreadExit();

  Scheduler* scheduler_;
};

class ProcessVisitor {
 public:
  virtual ~ProcessVisitor() {}

  virtual void VisitProcess(Process* process) = 0;
};

class InterpretationBarrier {
 public:
  InterpretationBarrier() : current_process(NULL) {}
  ~InterpretationBarrier() {
    ASSERT(current_process.load() == NULL ||
           current_process.load() == kPreemptMarker);
  }

  void PreemptProcess();

  void Enter(Process* process);
  void Leave(Process* process);

 private:
  Process* const kPreemptMarker = reinterpret_cast<Process*>(1);

  // The currently executing process. Upon preemption, the value may be set to
  // kPreemptMarker if it's NULL (which is the case when no process is being
  // executed). This means that it will always be in either of these 3 cases:
  //   - NULL
  //   - A process
  //   - kPreemptMarker
  Atomic<Process*> current_process;
};

class Scheduler {
 public:
  enum ProcessInterruptionEvent {
    kNoAction,
    kExitWithCompileTimeError,
    kExitWithUncaughtException,
    kExitWithUncaughtExceptionAndPrintStackTrace,
    kExitWithUncaughtSignal,
    kExitWithKilledSignal,
    kExitWithoutError
  };

  static void Setup();
  static void TearDown();
  static Scheduler* GlobalInstance() { return scheduler_; }

  Scheduler();
  ~Scheduler();

  void ScheduleProgram(Program* program, Process* main_process);
  void UnscheduleProgram(Program* program);

  void StopProgram(Program* program, ProgramState::State stop_state);
  void ResumeProgram(Program* program, ProgramState::State stop_state);
  void KillProgram(Program* program);

  void PauseGcThread();
  void ResumeGcThread();

  void PreemptionTick();

  void FinishedGC(Program* program, int count);

  // This method should only be called from a thread which is currently
  // interpreting a process.
  void EnqueueProcessOnSchedulerWorkerThread(Process* interpreting_process,
                                             Process* process);

  // Run the [process] on the current thread if possible.
  // The [port] must be locked, and will be unlocked by this method.
  // Returns false if [process] is already scheduled or running.
  // TODO(ajohnsen): This could be improved by taking a Port and a 'message',
  // and avoid the extra allocation on the process queue (in the case where it's
  // empty).
  bool EnqueueProcess(Process* process, Port* port);

  // Resume a process. If the process is already running, this function will do
  // nothing. This function is thread safe.
  void ResumeProcess(Process* process);

  // Continue a process that is stopped at a break point.
  void ContinueProcess(Process* process);

  // A signal arrived for the process.
  void SignalProcess(Process* process);

 private:
  friend class Dartino;
  friend class WorkerThread;

  // Global scheduler instance.
  static Scheduler* scheduler_;

  // Worker threads
  static const int kThreadCount = 4;
  ThreadIdentifier thread_ids_[kThreadCount];
  WorkerThread* threads_[kThreadCount];

  Atomic<bool> interpreter_is_paused_;
  ProcessQueue ready_queue_;
  ProgramList programs_;

  Monitor* pause_monitor_;
  Atomic<bool> pause_;
  Atomic<bool> shutdown_;

  InterpretationBarrier interpretation_barrier_;

  Monitor* idle_monitor_;
  Semaphore interpreter_semaphore_;
  GCThread* gc_thread_;

  void DeleteTerminatedProcess(Process* process, Signal::Kind kind);

  // Exit the program for the given process with the given exit code.
  void ExitWith(Process* process, int exit_code, Signal::Kind kind);

  void RescheduleProcess(Process* process, bool terminate);

  bool RunInterpreterLoop(WorkerThread* worker);

  // Caller must hold [pause_monitor_].
  void PauseInterpreterLoop();
  // Caller must hold [pause_monitor_].
  void ResumeInterpreterLoop();

  // Interpret [process] as worker [worker]. Returns the next Process that
  // should be run.
  Process* InterpretProcess(Process* process, WorkerThread* worker);
  void NotifyInterpreterThread();

  void EnqueueProcess(Process* process);
  bool DequeueProcess(Process** process);

  // The [process] will be enqueued on any thread. In case the program is paused
  // the process will be enqueued once the program is resumed.
  void EnqueueSafe(Process* process);

  // Handlers for when the interpretation of a process has been interrupted.
  void HandleTerminated(Process* process);
  void HandleUncaughtException(Process* process);
  void HandleCompileTimeError(Process* process);
  void HandleBreakpoint(Process* process);
  void HandleKilled(Process* process);
  void HandleUncaughtSignal(Process* process);

  void HandleEventResult(
      ProcessInterruptionEvent result, Process* process, Process::State state);
};

class StoppedGcThreadScope {
 public:
  explicit StoppedGcThreadScope(Scheduler* scheduler) : scheduler_(scheduler) {
    scheduler->PauseGcThread();
  }

  ~StoppedGcThreadScope() { scheduler_->ResumeGcThread(); }

 private:
  Scheduler* scheduler_;
};

// Used for running one or more programs and waiting for their exit codes.
class SimpleProgramRunner {
 public:
  SimpleProgramRunner();
  ~SimpleProgramRunner();

  void Run(int count,
           int* exitcodes,
           Program** programs,
           int argc,
           char** argv,
           Process** main_processes = NULL);

 private:
  Monitor* monitor_;
  Program** programs_;
  int* exitcodes_;
  int count_;
  int remaining_;

  static void CaptureExitCode(Program* program, int exitcode, void* data);
};


}  // namespace dartino

#endif  // SRC_VM_SCHEDULER_H_
