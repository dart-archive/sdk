// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/service_api_impl.h"

#include "src/vm/natives.h"
#include "src/vm/port.h"
#include "src/vm/process.h"

namespace fletch {

class ServiceRegistry {
 public:
  ServiceRegistry() : monitor_(Platform::CreateMonitor()), service_(NULL) { }

  ~ServiceRegistry() { delete service_; }

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
  Service* service;
  ServiceApiCallback callback;
  void* data;
};

__attribute__((visibility("default")))
void PostResultToService(char* buffer) {
  ServiceRequest* request = reinterpret_cast<ServiceRequest*>(buffer);
  Service* service = request->service;
  if (service != NULL) {
    service->PostResult();
  } else {
    int result = *reinterpret_cast<int*>(buffer + 32);
    void* data = request->data;
    ServiceApiCallback callback = request->callback;
    ASSERT(callback != NULL);

    free(request);
    callback(result, data);
  }
}

Service::Service(char* name, Port* port)
    : result_monitor_(Platform::CreateMonitor()),
      has_result_(false),
      name_(name),
      port_(port) {
  port_->IncrementRef();
}

Service::~Service() {
  port_->DecrementRef();
  delete result_monitor_;
}

void Service::PostResult() {
  ScopedMonitorLock lock(result_monitor_);
  has_result_ = true;
  result_monitor_->Notify();
}

void Service::WaitForResult() {
  // TODO(ajohnsen): Make it work for multiple sync calls at the same time.
  // Double-checked locking to avoid monitors in the case where the calling
  // thread is used by the Scheduler to handle the message.
  if (!has_result_) {
    ScopedMonitorLock lock(result_monitor_);
    while (!has_result_) result_monitor_->Wait();
  }
  has_result_ = false;
}

ServiceApiValueType Service::Invoke(int id, ServiceApiValueType arg) {
  char bits[32 + 4];
  char* buffer = bits;
  *reinterpret_cast<int*>(buffer + 32) = arg;

  port_->Lock();
  Process* process = port_->process();
  if (process != NULL) {
    ServiceRequest* request = reinterpret_cast<ServiceRequest*>(buffer);
    request->method_id = id;
    request->service = this;
    request->callback = NULL;
    process->EnqueueForeign(port_, buffer, sizeof(bits), false);
    process->program()->scheduler()->ResumeProcess(process);
  }
  port_->Unlock();
  WaitForResult();
  return *reinterpret_cast<int*>(buffer + 32);
}

void Service::InvokeX(int id, void* buffer, int size) {
  port_->Lock();
  Process* process = port_->process();
  if (process != NULL) {
    ServiceRequest* request = reinterpret_cast<ServiceRequest*>(buffer);
    request->method_id = id;
    request->service = this;
    request->callback = NULL;
    process->EnqueueForeign(port_, buffer, size, false);
    process->program()->scheduler()->RunProcessOnCurrentThread(process, port_);
  } else {
    port_->Unlock();
  }
  WaitForResult();
}

void Service::InvokeAsync(int id,
                          ServiceApiValueType arg,
                          ServiceApiCallback callback,
                          void* data) {
  port_->Lock();
  Process* process = port_->process();
  if (process != NULL) {
    int size = 32 + 4;
    char* buffer = reinterpret_cast<char*>(malloc(size));
    *reinterpret_cast<int*>(buffer + 32) = arg;

    ServiceRequest* request = reinterpret_cast<ServiceRequest*>(buffer);
    request->method_id = id;
    request->callback = callback;
    request->data = data;
    process->EnqueueForeign(port_, request, size, false);
    process->program()->scheduler()->ResumeProcess(process);
  }
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

ServiceApiValueType ServiceApiInvoke(ServiceId service_id,
                                     MethodId method,
                                     ServiceApiValueType argument) {
  fletch::Service* service = reinterpret_cast<fletch::Service*>(service_id);
  intptr_t method_id = reinterpret_cast<intptr_t>(method);
  return service->Invoke(method_id, argument);
}

void ServiceApiInvokeX(ServiceId service_id,
                       MethodId method,
                       void* buffer,
                       int size) {
  fletch::Service* service = reinterpret_cast<fletch::Service*>(service_id);
  intptr_t method_id = reinterpret_cast<intptr_t>(method);
  service->InvokeX(method_id, buffer, size);
}

void ServiceApiInvokeAsync(ServiceId service_id,
                           MethodId method,
                           ServiceApiValueType argument,
                           ServiceApiCallback callback,
                           void* data) {
  fletch::Service* service = reinterpret_cast<fletch::Service*>(service_id);
  intptr_t method_id = reinterpret_cast<intptr_t>(method);
  service->InvokeAsync(method_id, argument, callback, data);
}

void ServiceApiTerminate(ServiceId service_id) {
  ServiceApiInvoke(service_id, kTerminateMethodId, 0);
  fletch::Service* service = reinterpret_cast<fletch::Service*>(service_id);
  fletch::service_registry->Unregister(service);
}
