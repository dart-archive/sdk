// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/service_api_impl.h"

#include "src/vm/natives.h"
#include "src/vm/port.h"
#include "src/vm/process.h"
#include "src/vm/thread.h"

static const int kRequestHeaderSize = 32;

namespace fletch {

class ServiceRegistry {
 public:
  ServiceRegistry() : monitor_(Platform::CreateMonitor()), service_(NULL) { }

  ~ServiceRegistry() {
    delete service_;
    delete monitor_;
  }

  void Register(Service* service) {
    ScopedMonitorLock lock(monitor_);
    delete service_;
    service_ = service;
    monitor_->NotifyAll();
  }

  void Unregister(Service* service) {
    ScopedMonitorLock lock(monitor_);
    ASSERT(service_ == service);
    delete service_;
    service_ = NULL;
  }

  Service* LookupService(const char* name) {
    ScopedMonitorLock lock(monitor_);
    while (service_ == NULL || strcmp(name, service_->name()) != 0) {
      monitor_->Wait();
    }
    return service_;
  }

 private:
  Monitor* monitor_;
  Service* service_;
};

static ServiceRegistry* service_registry = NULL;

struct ServiceRequest {
  int method_id;
  bool has_result;
  ThreadIdentifier thread;
  Service* service;
  void* callback;
};

__attribute__((visibility("default")))
int PostResultToService(char* buffer) {
  ServiceRequest* request = reinterpret_cast<ServiceRequest*>(buffer);
  if (request->callback == NULL) {
    request->service->NotifyResult(request);
  } else {
    ServiceApiCallback callback =
        reinterpret_cast<ServiceApiCallback>(request->callback);
    ASSERT(callback != NULL);
    callback(buffer);
  }
  return 0;
}

Service::Service(char* name, Port* port)
    : result_monitor_(Platform::CreateMonitor()),
      name_(name),
      port_(port) {
  port_->IncrementRef();
}

Service::~Service() {
  port_->DecrementRef();
  delete result_monitor_;
  free(name_);
}

void Service::NotifyResult(ServiceRequest* request) {
  request->has_result = true;
  if (Thread::IsCurrent(&request->thread)) return;
  ScopedMonitorLock lock(result_monitor_);
  result_monitor_->NotifyAll();
}

void Service::WaitForResult(ServiceRequest* request) {
  // Double-checked locking to avoid monitors in the case where the calling
  // thread is used by the Scheduler to handle the message.
  if (!request->has_result) {
    ScopedMonitorLock lock(result_monitor_);
    while (!request->has_result) result_monitor_->Wait();
  }
}

void Service::Invoke(int id, void* buffer, int size) {
  port_->Lock();
  Process* process = port_->process();
  if (process == NULL) {
    // TODO(ajohnsen): Report error - service disappeared while sending.
    port_->Unlock();
    return;
  }
  ASSERT(sizeof(ServiceRequest) <= kRequestHeaderSize);
  ServiceRequest* request = reinterpret_cast<ServiceRequest*>(buffer);
  request->method_id = id;
  request->has_result = false;
  request->thread = ThreadIdentifier();
  request->service = this;
  request->callback = NULL;
  process->EnqueueForeign(port_, buffer, size, false);
  process->program()->scheduler()->ProcessRunOnCurrentThread(process, port_);
  WaitForResult(request);
}

void Service::InvokeAsync(int id,
                          ServiceApiCallback callback,
                          void* buffer,
                          int size) {
  port_->Lock();
  Process* process = port_->process();
  if (process == NULL) {
    // TODO(ajohnsen): Report error - service disappeared while sending.
    port_->Unlock();
    return;
  }
  ASSERT(sizeof(ServiceRequest) <= kRequestHeaderSize);
  ServiceRequest* request = reinterpret_cast<ServiceRequest*>(buffer);
  request->method_id = id;
  request->has_result = false;
  request->callback = reinterpret_cast<void*>(callback);
  process->EnqueueForeign(port_, buffer, size, false);
  process->program()->scheduler()->ResumeProcess(process);
  port_->Unlock();
}

NATIVE(ServiceRegister) {
  if (!arguments[0]->IsString()) return Failure::illegal_state();
  String* name = String::cast(arguments[0]);
  if (!arguments[1]->IsInstance()) return Failure::illegal_state();
  Instance* port_instance = Instance::cast(arguments[1]);
  if (!port_instance->IsPort()) return Failure::illegal_state();
  Object* field = port_instance->GetInstanceField(0);
  uword address = AsForeignWord(field);
  if (address == 0) return Failure::illegal_state();
  Port* port = reinterpret_cast<Port*>(address);
  Service* service = new Service(name->ToCString(), port);
  service_registry->Register(service);
  return process->program()->null_object();
}

}  // namespace fletch

void ServiceApiSetup() {
  fletch::service_registry = new fletch::ServiceRegistry();
}

void ServiceApiTearDown() {
  delete fletch::service_registry;
  fletch::service_registry = NULL;
}

ServiceId ServiceApiLookup(const char* name) {
  fletch::Service* service = fletch::service_registry->LookupService(name);
  return reinterpret_cast<ServiceId>(service);
}

void ServiceApiInvoke(ServiceId service_id,
                      MethodId method,
                      void* buffer,
                      int size) {
  fletch::Service* service = reinterpret_cast<fletch::Service*>(service_id);
  intptr_t method_id = reinterpret_cast<intptr_t>(method);
  service->Invoke(method_id, buffer, size);
}

void ServiceApiInvokeAsync(ServiceId service_id,
                           MethodId method,
                           ServiceApiCallback callback,
                           void* buffer,
                           int size) {
  fletch::Service* service = reinterpret_cast<fletch::Service*>(service_id);
  intptr_t method_id = reinterpret_cast<intptr_t>(method);
  service->InvokeAsync(method_id, callback, buffer, size);
}

void ServiceApiTerminate(ServiceId service_id) {
  char buffer[kRequestHeaderSize];
  ServiceApiInvoke(service_id, kTerminateMethodId, buffer, sizeof(buffer));
  fletch::Service* service = reinterpret_cast<fletch::Service*>(service_id);
  fletch::service_registry->Unregister(service);
}
