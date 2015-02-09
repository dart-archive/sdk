// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include "echo_service.h"
#include "include/service_api.h"

static ServiceId service_id_;

@implementation EchoService

+ (void)Setup {
  service_id_ = kNoServiceId;
  service_id_ = ServiceApiLookup("EchoService");
}

+ (void)TearDown {
  ServiceApiTerminate(service_id_);
  service_id_ = kNoServiceId;
}

static const MethodId kEchoId_ = (MethodId)1;

+ (int32_t)echo:(int32_t)n {
  static const int kSize = 40;
  char _bits[kSize];
  char* _buffer = _bits;
  *(int32_t*)(_buffer + 32) = n;
  ServiceApiInvoke(service_id_, kEchoId_, _buffer, kSize);
  return *(int*)(_buffer + 32);
}

static void Unwrap_int32_8(void* raw) {
  typedef void (*cbt)(int);
  char* buffer = (char*)(raw);
  int result = *(int*)(buffer + 32);
  cbt callback = *(cbt*)(buffer + 40);
  free(buffer);
  callback(result);
}

+ (void)echoAsync:(int32_t)n withCallback:(void (*)(int))callback {
  static const int kSize = 40 + 1 * sizeof(void*);
  char* _buffer = (char*)(malloc(kSize));
  *(int32_t*)(_buffer + 32) = n;
  *(void**)(_buffer + 40) = (void*)(callback);
  ServiceApiInvokeAsync(service_id_, kEchoId_, Unwrap_int32_8, _buffer, kSize);
}

static void Unwrap_int32_8_Block(void* raw) {
  typedef void (^cbt)(int);
  char* buffer = (char*)(raw);
  int result = *(int*)(buffer + 32);
  cbt callback = *(cbt*)(buffer + 40);
  free(buffer);
  callback(result);
}

+ (void)echoAsync:(int32_t)n withBlock:(void (^)(int))callback {
  static const int kSize = 40 + 1 * sizeof(void*);
  char* _buffer = (char*)(malloc(kSize));
  *(int32_t*)(_buffer + 32) = n;
  *(void**)(_buffer + 40) = (void*)(callback);
  ServiceApiInvokeAsync(service_id_, kEchoId_, Unwrap_int32_8_Block, _buffer, kSize);
}

@end
