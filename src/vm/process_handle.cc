// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/process_handle.h"

#include "src/vm/object.h"
#include "src/vm/natives.h"
#include "src/vm/heap.h"
#include "src/vm/process.h"
#include "src/vm/spinlock.h"

namespace fletch {

NATIVE(ProcessLink) {
  Instance* dart_process = Instance::cast(arguments[0]);
  ProcessHandle* handle = reinterpret_cast<ProcessHandle*>(
      AsForeignWord(dart_process->GetInstanceField(0)));
  {
    ScopedSpinlock locker(handle->lock());
    Process* handle_process = handle->process();
    if (handle_process == NULL) {
      return process->program()->false_object();
    }

    if (handle_process->links()->InsertHandle(process->process_handle())) {
      process->links()->InsertHandle(handle);
      return process->program()->true_object();
    }

    return process->program()->false_object();
  }
}

NATIVE(ProcessMonitor) {
  Instance* dart_pid = Instance::cast(arguments[0]);
  ProcessHandle* handle = reinterpret_cast<ProcessHandle*>(
      AsForeignWord(dart_pid->GetInstanceField(0)));
  Instance* dart_port = Instance::cast(arguments[1]);
  if (!dart_port->IsPort()) {
    return Failure::wrong_argument_type();
  }
  Port* port = Port::FromDartObject(dart_port);

  {
    ScopedSpinlock locker(handle->lock());
    Process* handle_process = handle->process();
    if (handle_process != NULL) {
      handle_process->links()->InsertPort(port);
      return process->program()->true_object();
    } else {
      return process->program()->false_object();
    }
  }
}

}  // namespace fletch
