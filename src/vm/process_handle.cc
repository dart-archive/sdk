// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/process_handle.h"

#include "src/vm/heap.h"
#include "src/vm/natives.h"
#include "src/vm/object.h"
#include "src/vm/process.h"
#include "src/vm/scheduler.h"
#include "src/vm/spinlock.h"

namespace dartino {

ProcessHandle* ProcessHandle::FromDartObject(Object* o) {
  Instance* dart_pid = Instance::cast(o);
  uword handle_address = Smi::cast(dart_pid->GetInstanceField(0))->value() << 2;
  return reinterpret_cast<ProcessHandle*>(handle_address);
}

void ProcessHandle::InitializeDartObject(Object* o) {
  Instance* dart_pid = Instance::cast(o);
  uword address = reinterpret_cast<uword>(this);
  ASSERT((address & 3) == 0);  // Always aligned.
  dart_pid->SetInstanceField(0, Smi::FromWord(address >> 2));
}

extern "C" Object* NativeProcessLink(Process* process, Object* dart_handle) {
  ProcessHandle* handle = ProcessHandle::FromDartObject(dart_handle);
  {
    ScopedSpinlock locker(handle->lock());
    Process* handle_process = handle->process();
    if (handle_process != NULL &&
        handle_process->links()->InsertHandle(process->process_handle())) {
      return process->program()->true_object();
    }

    return process->program()->false_object();
  }
}

extern "C" Object* NativeProcessUnlink(Process* process, Object* dart_handle) {
  ProcessHandle* handle = ProcessHandle::FromDartObject(dart_handle);
  {
    ScopedSpinlock locker(handle->lock());
    Process* handle_process = handle->process();
    if (handle_process != NULL) {
      if (handle_process == process->parent()) {
        return Failure::wrong_argument_type();
      }
      handle_process->links()->RemoveHandle(process->process_handle());
    }
  }
  return process->program()->null_object();
}

extern "C" Object* NativeProcessMonitor(Process* process, Object* dart_handle, Object* instance) {
  ProcessHandle* handle = ProcessHandle::FromDartObject(dart_handle);
  Instance* dart_port = Instance::cast(instance);
  if (!dart_port->IsPort()) return Failure::wrong_argument_type();
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

extern "C" Object* NativeProcessUnmonitor(Process* process, Object* dart_handle, Object* instance) {
  ProcessHandle* handle = ProcessHandle::FromDartObject(dart_handle);
  Instance* dart_port = Instance::cast(instance);
  if (!dart_port->IsPort()) return Failure::wrong_argument_type();
  Port* port = Port::FromDartObject(dart_port);

  {
    ScopedSpinlock locker(handle->lock());
    Process* handle_process = handle->process();
    if (handle_process != NULL) {
      handle_process->links()->RemovePort(port);
    }
  }
  return process->program()->null_object();
}

extern "C" Object* NativeProcessKill(Process* process, Object* dart_handle) {
  ProcessHandle* handle = ProcessHandle::FromDartObject(dart_handle);

  // Avoid allocating [Signal] if destination is already dead, but do allocate
  // [Signal] outside spinlock.
  Process* handle_process = handle->process();
  if (handle_process != NULL) {
    Signal* signal = new Signal(process->process_handle(), Signal::kShouldKill);

    ScopedSpinlock locker(handle->lock());
    handle_process = handle->process();
    if (handle_process != NULL) {
      handle_process->SendSignal(signal);
      process->program()->scheduler()->SignalProcess(handle_process);
    } else {
      delete signal;
    }
  }
  return process->program()->null_object();
}

}  // namespace dartino
