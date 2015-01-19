// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SCHEDULER_H_
#define SRC_VM_SCHEDULER_H_

#include <unordered_map>

#include "src/vm/thread_pool.h"

namespace fletch {

class Object;
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

  bool Run();

 private:
  struct ProcessList {
    ProcessList() : head(NULL) {}
    Process* head;
  };

  const int max_threads_;
  ThreadPool thread_pool_;
  Monitor* preempt_monitor_;
  std::atomic<int> processes_;
  std::atomic<int> queued_processes_;
  std::atomic<int> sleeping_threads_;
  std::atomic<int> thread_count_;
  std::atomic<ThreadState*>* threads_;
  std::unordered_map<Program*, ProcessList> stopped_processes_map_;
  ProcessQueue* startup_queue_;

  Monitor* pause_monitor_;
  std::atomic<bool> pause_;
  std::atomic<Process*>* current_processes_;

  void PreemptThreadProcess(int thread_id);
  int GetPreemptInterval();
  void EnqueueProcessAndNotifyThreads(ThreadState* thread_state,
                                      Process* process);

  void RunInThread();

  // Interpret [process] as thread [thread] with id [thread_id]. Returns the
  // next Process that should be run on this thraed.
  Process* InterpretProcess(Process* process, ThreadState* thread_state);
  void ThreadEnter(ThreadState* thread_state);
  void ThreadExit(ThreadState* thread_state);
  void NotifyAllThreads();

  // Dequeue from [thread_state]. If [process] is [NULL] after a call to
  // DequeueFromThread, the [thread_state] is empty. Note that DequeueFromThread
  // may dequeue a process from another ThreadState.
  void DequeueFromThread(ThreadState* thread_state, Process** process);
  // Returns true if it was able to dequeue a process, or all thread_states were
  // empty. Returns false if the operation should be retried.
  bool TryDequeueFromAnyThread(Process** process, int start_id = 0);
  void EnqueueOnThread(ThreadState* thread_state, Process* process);
  void EnqueueOnAnyThread(Process* process, int start_id = 0);

  static void RunThread(void* data);
};

}  // namespace fletch

#endif  // SRC_VM_SCHEDULER_H_
