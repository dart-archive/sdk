// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_LINKS_H_
#define SRC_VM_LINKS_H_

#include "src/vm/hash_set.h"
#include "src/vm/port.h"
#include "src/vm/process_handle.h"
#include "src/vm/signal_mailbox.h"
#include "src/vm/spinlock.h"

namespace fletch {

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
  void EnqueueSignal(Port* port, Signal::Kind kind);

  void SendSignal(ProcessHandle* handle,
                  ProcessHandle* dying_handle,
                  Signal::Kind kind);

  Spinlock lock_;
  // If [half_dead_] is `true` the process will no longer execute any Dart code
  // and is just waiting for the remaining processes in it's process tree to
  // die.
  bool half_dead_;
  Signal::Kind exit_kind_;
  HashSet<Port*> ports_;
  HashSet<ProcessHandle*> handles_;
};

}  // namespace fletch

#endif  // SRC_VM_LINKS_H_
