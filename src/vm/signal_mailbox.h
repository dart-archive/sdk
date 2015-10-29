// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SIGNAL_MAILBOX_H_
#define SRC_VM_SIGNAL_MAILBOX_H_

#include "src/shared/globals.h"
#include "src/shared/atomic.h"

#include "src/vm/heap.h"
#include "src/vm/mailbox.h"
#include "src/vm/port.h"
#include "src/vm/process_handle.h"
#include "src/vm/storebuffer.h"

namespace fletch {

class Signal : public MailboxMessage<Signal> {
 public:
  // Please keep these in sync with lib/fletch/fletch.dart:SignalKind.
  enum Kind {
    kCompileTimeError,
    kTerminated,
    kUncaughtException,
  };

  Signal(ProcessHandle* handle, Kind kind)
      : process_handle_(handle),
        kind_(kind) {
    process_handle_->IncrementRef();
  }

  ~Signal() {
    ProcessHandle::DecrementRef(process_handle_);
  }

  ProcessHandle* handle() const { return process_handle_; }
  Kind kind() const { return kind_; }

 private:
  ProcessHandle* const process_handle_;
  const Kind kind_;
};

class SignalMailbox : public Mailbox<Signal> { };

}  // namespace fletch


#endif  // SRC_VM_SIGNAL_MAILBOX_H_
