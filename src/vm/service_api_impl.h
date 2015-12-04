// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SERVICE_API_IMPL_H_
#define SRC_VM_SERVICE_API_IMPL_H_

#include "include/service_api.h"

namespace fletch {

class Monitor;
class Port;
struct ServiceRequest;

// TODO(ager): Instead of making this accessible, we should
// probably post a callback into dart? Fix the service param;
// for now it is a pointer to a pointer so we can post something
// into dart that dart can free.
FLETCH_EXPORT
void PostResultToService(char* buffer);

class Service {
 public:
  // The name is assumed to be allocated with malloc and the
  // service takes ownership of the name and deallocates it
  // with free on service destruction.
  Service(char* name, Port* port);
  ~Service();

  void Invoke(int id, void* buffer, int size);

  void InvokeAsync(int id, ServiceApiCallback callback, void* buffer, int size);

  char* name() const { return name_; }

  Service* next() const { return next_; }
  void set_next(Service* next) { next_ = next; }

 private:
  friend void PostResultToService(char* buffer);

  void NotifyResult(ServiceRequest* request);
  void WaitForResult(ServiceRequest* request);

  Monitor* const result_monitor_;

  char* const name_;
  Port* const port_;
  Service* next_;
};

}  // namespace fletch

#endif  // SRC_VM_SERVICE_API_IMPL_H_
