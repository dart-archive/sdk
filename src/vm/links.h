// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_LINKS_H_
#define SRC_VM_LINKS_H_

#include "src/vm/multi_hashset.h"
#include "src/vm/port.h"
#include "src/vm/process_handle.h"
#include "src/vm/signal.h"
#include "src/vm/spinlock.h"

namespace dartino {

class Process;

class Links {
 public:
  Links() : half_dead_(false), exit_kind_(Signal::kTerminated) {}
  ~Links() {
    ASSERT(handles_.size() == 0);
    ASSERT(ports_.size() == 0);
  }

  Signal::Kind exit_signal() const { return exit_kind_; }

  void InsertPort(Port* port);
  bool InsertHandle(ProcessHandle* handle);
  void RemovePort(Port* port);
  void RemoveHandle(ProcessHandle* handle);

  // TODO(kustermann): Instead of an integer we should really enqueue a
  // sensible message.
  void NotifyLinkedProcesses(ProcessHandle* handle, Signal::Kind kind);
  void NotifyMonitors(ProcessHandle* handle);

 private:
  // Used to send an exit [Signal] to a given [port] (aka monitoring port).
  //
  // The [signal] may be NULL in which case the method may allocate one if it
  // needs to. If it did, it will return the allocated value, otherwise it
  // returns what was passed in.
  // This is an optimization to
  //   a) avoid unnecessary allocation of [Signal]
  //   b) share one refcounted [Signal] across all [EnqueueSignal]/[SendSignal]
  //      calls
  Signal* EnqueueSignal(Port* port, ProcessHandle* dying_handle,
                        Signal::Kind kind, Signal* signal);

  // Used to send a [Signal] to a specific process (aka linked process).
  // This will make the process [handle] is referring to die if it's not already
  // dead.
  //
  // See above for description of the [signal] argument and return value.
  Signal* SendSignal(ProcessHandle* handle, ProcessHandle* dying_handle,
                     Signal::Kind kind, Signal* signal);

  Spinlock lock_;
  // If [half_dead_] is `true` the process will no longer execute any Dart code
  // and is just waiting for the remaining processes in it's process tree to
  // die.
  bool half_dead_;
  Signal::Kind exit_kind_;
  MultiHashSet<Port*> ports_;
  MultiHashSet<ProcessHandle*> handles_;
};

}  // namespace dartino

#endif  // SRC_VM_LINKS_H_
