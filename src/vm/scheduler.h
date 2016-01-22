// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SCHEDULER_H_
#define SRC_VM_SCHEDULER_H_

#include "src/shared/atomic.h"

#include "src/vm/signal.h"
#include "src/vm/thread_pool.h"
#include "src/vm/thread.h"

namespace fletch {

class GCThread;
class Heap;
class Object;
class Port;
class ProcessQueue;
class Process;
class Program;

const int kCompileTimeErrorExitCode = 254;
const int kUncaughtExceptionExitCode = 255;
const int kBreakPointExitCode = 0;

class ThreadState {
 public:
  ThreadState();
  ~ThreadState();

  int thread_id() const { return thread_id_; }
  void set_thread_id(int thread_id) {
    ASSERT(thread_id_ == -1);
    thread_id_ = thread_id;
  }

  const ThreadIdentifier* thread() const { return &thread_; }

  // Update the thread field to point to the current thread.
  void AttachToCurrentThread();

  Monitor* idle_monitor() const { return idle_monitor_; }

 private:
  int thread_id_;
  ThreadIdentifier thread_;
  Monitor* idle_monitor_;
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
  static void Setup();
  static void TearDown();
  static Scheduler* GlobalInstance() { return scheduler_; }

  Scheduler();
  ~Scheduler();

  void ScheduleProgram(Program* program, Process* main_process);
  void UnscheduleProgram(Program* program);

  void StopProgram(Program* program);
  void ResumeProgram(Program* program);

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

  void Run();

  // There are 4 reasons for the interpretation of a process to be interrupted:
  //   * termination
  //   * uncaught exception
  //   * compile-time error
  //   * break point
  // these are the default implementations. They might be invoked if no session
  // is attached or the session might call them if it is about to end.
  //
  // TODO(kustermann): Once we've made more progress on the design of a
  // multiprocess system, we should consider making an abstraction for these.
  void ExitAtTermination(Process* process, Signal::Kind kind);
  void ExitAtUncaughtException(Process* process, bool print_stack);
  void ExitAtCompileTimeError(Process* process);
  void ExitAtBreakpoint(Process* process);

 private:
  friend class Fletch;

  // Global scheduler instance.
  static Scheduler* scheduler_;

  ThreadPool thread_pool_;

  Atomic<int> sleeping_threads_;
  Atomic<int> thread_count_;
  Atomic<ThreadState*> interpreting_thread_;
  ProcessQueue* ready_queue_;

  Monitor* pause_monitor_;
  Atomic<bool> pause_;
  Atomic<bool> shutdown_;

  InterpretationBarrier interpretation_barrier_;

  GCThread* gc_thread_;

  void DeleteTerminatedProcess(Process* process, Signal::Kind kind);

  // Exit the program for the given process with the given exit code.
  void ExitWith(Process* process, int exit_code, Signal::Kind kind);

  void RescheduleProcess(Process* process, ThreadState* state, bool terminate);

  void RunInThread();
  void RunInterpreterLoop(ThreadState* thread_state);

  // Interpret [process] as thread [thread] with id [thread_id]. Returns the
  // next Process that should be run on this thraed.
  Process* InterpretProcess(Process* process, ThreadState* thread_state);
  void ThreadEnter();
  void ThreadExit();
  void NotifyInterpreterThread();

  void EnqueueProcess(Process* process);
  void DequeueProcess(Process** process);

  // The [process] will be enqueued on any thread. In case the program is paused
  // the process will be enqueued once the program is resumed.
  void EnqueueOnAnyThreadSafe(Process* process, int start_id = 0);

  static void RunThread(void* data);
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
           Process** main_processes = NULL);

 private:
  Monitor* monitor_;
  Program** programs_;
  int* exitcodes_;
  int count_;
  int remaining_;

  static void CaptureExitCode(Program* program, int exitcode, void* data);
};


}  // namespace fletch

#endif  // SRC_VM_SCHEDULER_H_
