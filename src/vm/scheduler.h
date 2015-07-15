// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SCHEDULER_H_
#define SRC_VM_SCHEDULER_H_

#include <unordered_map>

#include "src/vm/thread_pool.h"

namespace fletch {

class Object;
class Port;
class Process;
class ProcessQueue;
class Program;
class ThreadState;

class ProcessVisitor {
 public:
  virtual ~ProcessVisitor() { }

  virtual void VisitProcess(Process* process) = 0;
};

class Scheduler {
 public:
  Scheduler();
  ~Scheduler();

  void ScheduleProgram(Program* program);

  bool StopProgram(Program* program);
  void ResumeProgram(Program* program);
  void VisitProcesses(Program* program, ProcessVisitor* visitor);

  // Enqueue [process] in the scheduler. The [process] will be run until
  // termination.
  // If [thread_state] is not NULL, the scheduler will use [thread_state] as a
  // hint when deciding what thread to schedule the process for.
  void EnqueueProcess(Process* process, ThreadState* thread_state = NULL);

  // Resume a process. If the process is already running, this function will do
  // nothing. This function is thread safe.
  void ResumeProcess(Process* process);

  // Continue a process that is stopped at a break point.
  void ProcessContinue(Process* process);

  // Run the [process] on the current thread if possible.
  // The [port] must be locked, and will be unlocked by this method.
  // Returns false if [process] is already scheduled or running.
  // TODO(ajohnsen): This could be improved by taking a Port and a 'message',
  // and avoid the extra allocation on the process queue (in the case where it's
  // empty).
  bool ProcessRunOnCurrentForeignThread(Process* process, Port* port);

  bool Run();

  // Terminate and delete a process that is paused at a breakpoint. Used
  // by the debugger to terminate gracefully.
  void DeleteProcessAtBreakpoint(Process* process);

 private:
  struct ProcessList {
    ProcessList() : head(NULL) {}
    Process* head;
  };

  const int max_threads_;
  ThreadPool thread_pool_;
  Monitor* preempt_monitor_;
  std::atomic<int> processes_;
  std::atomic<int> sleeping_threads_;
  std::atomic<int> thread_count_;
  std::atomic<ThreadState*> idle_threads_;
  std::atomic<ThreadState*>* threads_;
  std::atomic<ThreadState*> temporary_thread_states_;
  std::atomic<int> foreign_threads_;
  std::unordered_map<Program*, ProcessList> stopped_processes_map_;
  ProcessQueue* startup_queue_;

  Monitor* pause_monitor_;
  std::atomic<bool> pause_;
  std::atomic<Process*>* current_processes_;

  void DeleteProcess(Process* process);
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

  void SetCurrentProcessForThread(int thread_id, Process* process);
  void ClearCurrentProcessForThread(int thread_id, Process* process);
  // Interpret [process] as thread [thread] with id [thread_id]. Returns the
  // next Process that should be run on this thraed.
  Process* InterpretProcess(Process* process, ThreadState* thread_state);
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

  static void RunThread(void* data);
};

}  // namespace fletch

#endif  // SRC_VM_SCHEDULER_H_
