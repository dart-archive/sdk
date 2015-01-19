// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// TODO(ager): This file should be auto-generated from something like.
//
// service Echo {
//   echo(int32) : int32;
// }

#include "tests/service_tests/echo/echo_service.h"

static const MethodId kEchoMethodId = reinterpret_cast<MethodId>(1);
static ServiceId service_id = kNoServiceId;

void EchoService::Setup() {
  service_id = ServiceApiLookup("Echo");
}

void EchoService::TearDown() {
  ServiceApiTerminate(service_id);
  service_id = kNoServiceId;
}

ServiceApiValueType EchoService::Echo(ServiceApiValueType arg) {
  return ServiceApiInvoke(service_id, kEchoMethodId, arg);
}

void EchoService::EchoAsync(ServiceApiValueType arg,
                            ServiceApiCallback callback) {
  ServiceApiInvokeAsync(service_id, kEchoMethodId, arg, callback, NULL);
}
