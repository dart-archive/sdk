// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/service_api_impl.h"

#include "src/vm/natives.h"
#include "src/vm/port.h"
#include "src/vm/process.h"
#include "src/vm/scheduler.h"
#include "src/vm/thread.h"

static const int kRequestHeaderSize = 32;

namespace fletch {

class ServiceRegistry {
 public:
  ServiceRegistry() : monitor_(Platform::CreateMonitor()), service_(NULL) { }

  ~ServiceRegistry() {
    while (service_ != NULL) {
      Service* tmp = service_;
      service_ = service_->next();
      delete tmp;
    }
    delete monitor_;
  }

  void Register(Service* service) {
    ScopedMonitorLock lock(monitor_);
    ASSERT(service->next() == NULL);
    service->set_next(service_);
    service_ = service;
    monitor_->NotifyAll();
  }

  bool Unregister(Service* service) {
    ScopedMonitorLock lock(monitor_);
    ASSERT(service != NULL);
    if (service_ == service) {
      service_ = service->next();
    } else {
      Service* prev = service_;
      while (prev != NULL && prev->next() != service) {
        prev = prev->next();
      }
      if (prev == NULL) {
        FATAL1("Failed to unregister service: %s\n", service->name());
      }
      prev->set_next(service->next());
    }
    delete service;
    return true;
  }

  Service* LookupService(const char* name) {
    ScopedMonitorLock lock(monitor_);
    Service* service;
    while ((service = FindService(name)) == NULL) {
      monitor_->Wait();
    }
    return service;
  }

 private:
  Service* FindService(const char* name) {
    for (Service* next = service_; next != NULL; next = next->next()) {
      if (strcmp(name, next->name()) == 0) {
        return next;
      }
    }
    return NULL;
  }

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
void PostResultToService(char* buffer) {
  ServiceRequest* request = reinterpret_cast<ServiceRequest*>(buffer);
  if (request->callback == NULL) {
    request->service->NotifyResult(request);
  } else {
    ServiceApiCallback callback =
        reinterpret_cast<ServiceApiCallback>(request->callback);
    ASSERT(callback != NULL);
    callback(buffer);
  }
}

Service::Service(char* name, Port* port)
    : result_monitor_(Platform::CreateMonitor()),
      name_(name),
      port_(port),
      next_(NULL) {
  port_->IncrementRef();
}

Service::~Service() {
  port_->DecrementRef();
  delete result_monitor_;
  free(name_);
}

void Service::NotifyResult(ServiceRequest* request) {
  ScopedMonitorLock lock(result_monitor_);
  request->has_result = true;
  result_monitor_->NotifyAll();
}

void Service::WaitForResult(ServiceRequest* request) {
  ScopedMonitorLock lock(result_monitor_);
  while (!request->has_result) result_monitor_->Wait();
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
  process->mailbox()->EnqueueForeign(port_, buffer, size, false);
  process->program()->scheduler()->EnqueueProcess(process, port_);
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
  process->mailbox()->EnqueueForeign(port_, buffer, size, false);
  process->program()->scheduler()->ResumeProcess(process);
  port_->Unlock();
}

NATIVE(ServiceRegister) {
  if (!arguments[1]->IsInstance()) return Failure::illegal_state();
  Instance* port_instance = Instance::cast(arguments[1]);
  if (!port_instance->IsPort()) return Failure::illegal_state();
  Port* port = Port::FromDartObject(port_instance);
  if (port == NULL) return Failure::illegal_state();
  char* name = AsForeignString(arguments[0]);
  if (name == NULL) return Failure::illegal_state();
  Service* service = new Service(name, port);
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
