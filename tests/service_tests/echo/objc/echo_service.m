// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include "echo_service.h"
#include "include/service_api.h"

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
  static const int kSize = 40;
  char _bits[kSize];
  char* _buffer = _bits;
  *(int*)(_buffer + 32) = n;
  ServiceApiInvoke(_service_id, _kEchoId, _buffer, kSize);
  return *(int*)(_buffer + 32);
}

static void Unwrap_Int32_8(void* raw) {
  typedef void (*cbt)(int);
  char* buffer = (char*)(raw);
  int result = *(int*)(buffer + 32);
  cbt callback = *(cbt*)(buffer + 40);
  free(buffer);
  callback(result);
}

+ (void)EchoAsync:(int)n withCallback:(void (*)(int))callback {
  static const int kSize = 40 + 1 * sizeof(void*);
  char* _buffer = (char*)(malloc(kSize));
  *(int*)(_buffer + 32) = n;
  *(void**)(_buffer + 40) = (void*)(callback);
  ServiceApiInvokeAsync(_service_id, _kEchoId, Unwrap_Int32_8, _buffer, kSize);
}

static void Unwrap_Int32_8_Block(void* raw) {
  typedef void (^cbt)(int);
  char* buffer = (char*)(raw);
  int result = *(int*)(buffer + 32);
  cbt callback = *(cbt*)(buffer + 40);
  free(buffer);
  callback(result);
}

+ (void)EchoAsync:(int)n withBlock:(void (^)(int))callback {
  static const int kSize = 40 + 1 * sizeof(void*);
  char* _buffer = (char*)(malloc(kSize));
  *(int*)(_buffer + 32) = n;
  *(void**)(_buffer + 40) = (void*)(callback);
  ServiceApiInvokeAsync(_service_id, _kEchoId, Unwrap_Int32_8_Block, _buffer, kSize);
}

static const MethodId _kSumId = (MethodId)2;

+ (int)Sum:(short)x with:(int)y {
  static const int kSize = 40;
  char _bits[kSize];
  char* _buffer = _bits;
  *(short*)(_buffer + 32) = x;
  *(int*)(_buffer + 36) = y;
  ServiceApiInvoke(_service_id, _kSumId, _buffer, kSize);
  return *(int*)(_buffer + 32);
}

+ (void)SumAsync:(short)x with:(int)y withCallback:(void (*)(int))callback {
  static const int kSize = 40 + 1 * sizeof(void*);
  char* _buffer = (char*)(malloc(kSize));
  *(short*)(_buffer + 32) = x;
  *(int*)(_buffer + 36) = y;
  *(void**)(_buffer + 40) = (void*)(callback);
  ServiceApiInvokeAsync(_service_id, _kSumId, Unwrap_Int32_8, _buffer, kSize);
}

+ (void)SumAsync:(short)x with:(int)y withBlock:(void (^)(int))callback {
  static const int kSize = 40 + 1 * sizeof(void*);
  char* _buffer = (char*)(malloc(kSize));
  *(short*)(_buffer + 32) = x;
  *(int*)(_buffer + 36) = y;
  *(void**)(_buffer + 40) = (void*)(callback);
  ServiceApiInvokeAsync(_service_id, _kSumId, Unwrap_Int32_8_Block, _buffer, kSize);
}

@end
