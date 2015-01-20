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
  ServiceApiValueType argument;
  Service* service;
  ServiceApiCallback callback;
  void* data;
};

__attribute__((visibility("default")))
void PostResultToService(ServiceRequest* request) {
  Service* service = request->service;
  if (service != NULL) {
    service->PostResult(request->argument);
  } else {
    ASSERT(request->callback != NULL);
    request->callback(request->argument, request->data);
  }
}

Service::Service(char* name, Port* port)
    : result_monitor_(Platform::CreateMonitor()),
      has_result_(false),
      result_(0),
      name_(name),
      port_(port) {
  port_->IncrementRef();
}

Service::~Service() {
  port_->DecrementRef();
  delete result_monitor_;
}

void Service::PostResult(int result) {
  ScopedMonitorLock lock(result_monitor_);
  result_ = result;
  has_result_ = true;
  result_monitor_->Notify();
}

int Service::WaitForResult() {
  ScopedMonitorLock lock(result_monitor_);
  while (!has_result_) result_monitor_->Wait();
  has_result_ = false;
  return result_;
}

ServiceApiValueType Service::Invoke(int id, ServiceApiValueType arg) {
  port_->Lock();
  Process* process = port_->process();
  if (process != NULL) {
    ServiceRequest* request =
        reinterpret_cast<ServiceRequest*>(malloc(sizeof(ServiceRequest)));
    request->method_id = id;
    request->argument = arg;
    request->service = this;
    request->callback = NULL;
    process->EnqueueForeign(port_, request, sizeof(*request));
    process->program()->scheduler()->ResumeProcess(process);
  }
  port_->Unlock();
  return WaitForResult();
}

void Service::InvokeAsync(int id,
                          ServiceApiValueType arg,
                          ServiceApiCallback callback,
                          void* data) {
  port_->Lock();
  Process* process = port_->process();
  if (process != NULL) {
    ServiceRequest* request =
        reinterpret_cast<ServiceRequest*>(malloc(sizeof(ServiceRequest)));
    request->method_id = id;
    request->argument = arg;
    request->service = NULL;
    request->callback = callback;
    request->data = data;
    process->EnqueueForeign(port_, request, sizeof(*request));
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
