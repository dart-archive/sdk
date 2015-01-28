// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include "echo_service.h"

static void _BlockCallback(ServiceApiValueType result, void* data) {
  ((ServiceApiBlock)data)(result);
}

static ServiceId _service_id;

@implementation EchoService

+ (void)Setup {
  _service_id = kNoServiceId;
  _service_id = ServiceApiLookup("EchoService");
}

+ (void)TearDown {
  ServiceApiTerminate(_service_id);
  _service_id = kNoServiceId;
}

static const MethodId _kEchoId = (MethodId)1;

+ (int)Echo:(int)n {
  static const int kSize = 36;
  char _bits[kSize];
  char* _buffer = _bits;
  *(int*)(_buffer + 32) = n;
  ServiceApiInvoke(_service_id, _kEchoId, _buffer, kSize);
  return *(int*)(_buffer + 32);
}

+ (void)EchoAsync:(ServiceApiValueType)arg WithCallback:(ServiceApiCallback)cb {
  ServiceApiInvokeAsync(_service_id, _kEchoId, arg, cb, (void*)0);
}

+ (void)EchoAsync:(ServiceApiValueType)arg WithBlock:(ServiceApiBlock)block {
  ServiceApiInvokeAsync(_service_id, _kEchoId, arg, _BlockCallback, (void*)block);
}

static const MethodId _kSumId = (MethodId)2;

@end
