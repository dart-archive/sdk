// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include "echo_service.h"

static ServiceId _service_id = kNoServiceId;

void EchoService::Setup() {
  _service_id = ServiceApiLookup("EchoService");
}

void EchoService::TearDown() {
  ServiceApiTerminate(_service_id);
  _service_id = kNoServiceId;
}

static const MethodId _kEchoId = reinterpret_cast<MethodId>(1);

int EchoService::Echo(int n) {
  char _bits[36];
  char* _buffer = _bits;
  *reinterpret_cast<int*>(_buffer + 32) = n;
  ServiceApiInvokeX(_service_id, _kEchoId, _buffer, 36);
  return *reinterpret_cast<int*>(_buffer + 32);
}

void EchoService::EchoAsync(ServiceApiValueType arg, ServiceApiCallback cb) {
  ServiceApiInvokeAsync(_service_id, _kEchoId, arg, cb, NULL);
}
