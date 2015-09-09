// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SCHEDULER_H_
#define SRC_VM_SCHEDULER_H_

#include "src/shared/atomic.h"

#include "src/vm/thread_pool.h"

namespace fletch {

class GCThread;
class Heap;
class Object;
class Port;
class ProcessQueue;
class Process;
class Program;
class ThreadState;

const int kCompileTimeErrorExitCode = 254;
const int kUncaughtExceptionExitCode = 255;
const int kBreakPointExitCode = 0;

class ProcessVisitor {
 public:
  virtual ~ProcessVisitor() { }

  virtual void VisitProcess(Process* process) = 0;
};

class Scheduler {
 public:
  Scheduler();
  ~Scheduler();

  void ScheduleProgram(Program* program, Process* main_process);
  void UnscheduleProgram(Program* program);

  void StopProgram(Program* program);
  void ResumeProgram(Program* program);

  void PauseGcThread();
  void ResumeGcThread();

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
  void ProcessContinue(Process* process);

  int Run();

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
  void ExitAtTermination(Process* process, ThreadState* thread_state = NULL);
  void ExitAtUncaughtException(Process* process);
  void ExitAtCompileTimeError(Process* process);
  void ExitAtBreakpoint(Process* process);

  size_t process_count() const { return processes_; }

 private:
  const int max_threads_;
  ThreadPool thread_pool_;
  Monitor* preempt_monitor_;
  Atomic<int> processes_;
  Atomic<int> sleeping_threads_;
  Atomic<int> thread_count_;
  Atomic<ThreadState*> idle_threads_;
  Atomic<ThreadState*>* threads_;
  Atomic<ThreadState*> temporary_thread_states_;
  Atomic<int> foreign_threads_;
  ProcessQueue* startup_queue_;

  Monitor* pause_monitor_;
  Atomic<int> shutdown_;
  Atomic<Program*> shutdown_program_;
  Atomic<bool> pause_;
  Atomic<Process*>* current_processes_;

  GCThread* gc_thread_;

  void ExitWith(Program* program, int exit_code);

  void DeleteProcessAndMergeHeaps(Process* process, ThreadState* thread_state);
  void RescheduleProcess(Process* process, ThreadState* state, bool terminate);

  void PreemptThreadProcess(int thread_id);
  void ProfileThreadProcess(int thread_id);
  uint64 GetNextPreemptTime();
  void EnqueueProcessAndNotifyThreads(ThreadState* thread_state,
                                      Process* process);

  void PushIdleThread(ThreadState* thread_state);
  ThreadState* PopIdleThread();
  void RunInThread();
  void RunInterpreterLoop(ThreadState* thread_state);

  void SetCurrentProcessForThread(int thread_id, Process* process);
  void ClearCurrentProcessForThread(int thread_id, Process* process);
  // Interpret [process] as thread [thread] with id [thread_id]. Returns the
  // next Process that should be run on this thraed.
  Process* InterpretProcess(Process* process,
                            Heap* immutable_heap,
                            ThreadState* thread_state,
                            bool* allocation_failure);
  void ThreadEnter(ThreadState* thread_state);
  void ThreadExit(ThreadState* thread_state);
  void NotifyAllThreads();

  ThreadState* TakeThreadState();
  void ReturnThreadState(ThreadState* thread_state);
  void FlushCacheInThreadStates();

  // Dequeue from [thread_state]. If [process] is [NULL] after a call to
  // DequeueFromThread, the [thread_state] is empty. Note that DequeueFromThread
  // may dequeue a process from another ThreadState.
  void DequeueFromThread(ThreadState* thread_state, Process** process);
  // Returns true if it was able to dequeue a process, or all thread_states were
  // empty. Returns false if the operation should be retried.
  bool TryDequeueFromAnyThread(Process** process, int start_id = 0);
  void EnqueueOnThread(ThreadState* thread_state, Process* process);
  // Returns true if it was able to enqueue the process on an idle thread.
  bool TryEnqueueOnIdleThread(Process* process);
  // Returns true if it was able to enqueue the process on an idle thread.
  bool EnqueueOnAnyThread(Process* process, int start_id = 0);

  // The [process] will be enqueued on any thread. In case the program is paused
  // the process will be enqueued once the program is resumed.
  void EnqueueOnAnyThreadSafe(Process* process, int start_id = 0);

  static void RunThread(void* data);
};

class StoppedGcThreadScope {
 public:
  explicit StoppedGcThreadScope(Scheduler* scheduler)
      : scheduler_(scheduler) {
    scheduler->PauseGcThread();
  }

  ~StoppedGcThreadScope() {
    scheduler_->ResumeGcThread();
  }

 private:
  Scheduler* scheduler_;
};

}  // namespace fletch

#endif  // SRC_VM_SCHEDULER_H_
