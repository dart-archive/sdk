// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// TODO(ager): This file should be auto-generated from something like.
//
// service EchoService {
//   Echo(int32) : int32;
// }

#include "echo_service.h"

static const MethodId kEchoMethodId = (MethodId)1;
static ServiceId service_id;

static void Callback(ServiceApiValueType result, void* data) {
  ((ServiceApiBlock)data)(result);
}

@implementation EchoService

+ (void)Setup {
  service_id = kNoServiceId;
  service_id = ServiceApiLookup("EchoService");
}

+ (void)TearDown {
  ServiceApiTerminate(service_id);
  service_id = kNoServiceId;
}

+ (ServiceApiValueType)Echo:(ServiceApiValueType)arg {
  return ServiceApiInvoke(service_id, kEchoMethodId, arg);
}

+ (void)EchoAsync:(ServiceApiValueType)arg
        WithCallback:(ServiceApiCallback)callback {
  ServiceApiInvokeAsync(service_id, kEchoMethodId, arg, callback, (void*)0);
}

+ (void)EchoAsync:(ServiceApiValueType)arg
        WithBlock:(ServiceApiBlock)block {
  ServiceApiInvokeAsync(service_id, kEchoMethodId, arg, Callback, (void*)block);
}

@end
