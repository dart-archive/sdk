// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include "echo_service.h"
#include "include/service_api.h"
#include <stdlib.h>

static ServiceId service_id_ = kNoServiceId;

void EchoService::setup() {
  service_id_ = ServiceApiLookup("EchoService");
}

void EchoService::tearDown() {
  ServiceApiTerminate(service_id_);
  service_id_ = kNoServiceId;
}

static const MethodId kEchoId_ = reinterpret_cast<MethodId>(1);

int32_t EchoService::echo(int32_t n) {
  static const int kSize = 40;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int32_t*>(_buffer + 32) = n;
  ServiceApiInvoke(service_id_, kEchoId_, _buffer, kSize);
  return *reinterpret_cast<int64_t*>(_buffer + 32);
}

static void Unwrap_int32_8(void* raw) {
  typedef void (*cbt)(int);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 32);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 40);
  free(buffer);
  callback(result);
}

void EchoService::echoAsync(int32_t n, void (*callback)(int32_t)) {
  static const int kSize = 40 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int32_t*>(_buffer + 32) = n;
  *reinterpret_cast<void**>(_buffer + 40) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kEchoId_, Unwrap_int32_8, _buffer, kSize);
}

static const MethodId kPingId_ = reinterpret_cast<MethodId>(2);

int32_t EchoService::ping() {
  static const int kSize = 40;
  char _bits[kSize];
  char* _buffer = _bits;
  ServiceApiInvoke(service_id_, kPingId_, _buffer, kSize);
  return *reinterpret_cast<int64_t*>(_buffer + 32);
}

void EchoService::pingAsync(void (*callback)(int32_t)) {
  static const int kSize = 40 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<void**>(_buffer + 40) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kPingId_, Unwrap_int32_8, _buffer, kSize);
}
