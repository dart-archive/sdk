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
  ~Links() {
    ASSERT(objects_.Begin() == objects_.End());
  }

  void InsertPort(Port* port);
  void InsertHandle(ProcessHandle* handle);
  void RemovePort(Port* port);
  void RemoveHandle(ProcessHandle* handle);

  // TODO(kustermann): Instead of an integer we should really enqueue a
  // sensible message.
  void CleanupWithSignal(ProcessHandle* handle, Signal::Kind kind);

 private:
  // NOTE: This tagging mechanism assumes that all [Port] and [ProcessHandle]
  // objects are at least 2-byte aligned.
  static const int kPortTag = 1;
  typedef void* PortOrHandle;

  bool IsPort(PortOrHandle object) {
    uword value = reinterpret_cast<uword>(object);
    return ((value & kPortTag) == kPortTag);
  }

  PortOrHandle MarkPort(Port* port) {
    uword value = reinterpret_cast<uword>(port);
    return reinterpret_cast<PortOrHandle>(value | kPortTag);
  }

  Port* UnmarkPort(PortOrHandle object) {
    uword value = reinterpret_cast<uword>(object);
    return reinterpret_cast<Port*>(value & ~kPortTag);
  }

  PortOrHandle MarkHandle(ProcessHandle* handle) {
    return reinterpret_cast<PortOrHandle>(handle);
  }

  ProcessHandle* UnmarkHandle(PortOrHandle handle) {
    return reinterpret_cast<ProcessHandle*>(handle);
  }

  void EnqueueSignal(Port* port, Signal::Kind kind);

  void SendSignal(ProcessHandle* handle,
                  ProcessHandle* dying_handle,
                  Signal::Kind kind);

  Spinlock lock_;
  HashSet<PortOrHandle> objects_;
};

}  // namespace fletch

#endif  // SRC_VM_LINKS_H_
