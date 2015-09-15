// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include "service_two.h"
#include "include/service_api.h"
#include <stdlib.h>

static ServiceId service_id_ = kNoServiceId;

void ServiceTwo::setup() {
  service_id_ = ServiceApiLookup("ServiceTwo");
}

void ServiceTwo::tearDown() {
  ServiceApiTerminate(service_id_);
  service_id_ = kNoServiceId;
}

static const MethodId kEchoId_ = reinterpret_cast<MethodId>(1);

int32_t ServiceTwo::echo(int32_t arg) {
  static const int kSize = 64;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 48) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 56) = arg;
  ServiceApiInvoke(service_id_, kEchoId_, _buffer, kSize);
  return *reinterpret_cast<int64_t*>(_buffer + 56);
}

static void Unwrap_int32_8(void* raw) {
  typedef void (*cbt)(int32_t, void*);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 56);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 40);
  void* callback_data = *reinterpret_cast<void**>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback(result, callback_data);
}

void ServiceTwo::echoAsync(int32_t arg, void (*callback)(int32_t, void*), void* callback_data) {
  static const int kSize = 64 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 48) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 56) = arg;
  *reinterpret_cast<void**>(_buffer + 40) = reinterpret_cast<void*>(callback);
  *reinterpret_cast<void**>(_buffer + 32) = callback_data;
  ServiceApiInvokeAsync(service_id_, kEchoId_, Unwrap_int32_8, _buffer, kSize);
}
