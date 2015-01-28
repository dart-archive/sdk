// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include "echo_service.h"
#include "include/service_api.h"
#include <stdlib.h>

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
  static const int kSize = 36;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int*>(_buffer + 32) = n;
  ServiceApiInvoke(_service_id, _kEchoId, _buffer, kSize);
  return *reinterpret_cast<int*>(_buffer + 32);
}

static void Unwrap_Int32_1(void* raw) {
  typedef void (*cbt)(int);
  char* buffer = reinterpret_cast<char*>(raw);
  int result = *reinterpret_cast<int*>(buffer + 32);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 36);
  free(buffer);
  callback(result);
}

void EchoService::EchoAsync(int n, void (*callback)(int)) {
  static const int kSize = 36 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int*>(_buffer + 32) = n;
  *reinterpret_cast<void**>(_buffer + 36) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(_service_id, _kEchoId, Unwrap_Int32_1, _buffer, kSize);
}

static const MethodId _kSumId = reinterpret_cast<MethodId>(2);

int EchoService::Sum(int x, int y) {
  static const int kSize = 40;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int*>(_buffer + 32) = x;
  *reinterpret_cast<int*>(_buffer + 36) = y;
  ServiceApiInvoke(_service_id, _kSumId, _buffer, kSize);
  return *reinterpret_cast<int*>(_buffer + 32);
}

static void Unwrap_Int32_2(void* raw) {
  typedef void (*cbt)(int);
  char* buffer = reinterpret_cast<char*>(raw);
  int result = *reinterpret_cast<int*>(buffer + 32);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 40);
  free(buffer);
  callback(result);
}

void EchoService::SumAsync(int x, int y, void (*callback)(int)) {
  static const int kSize = 40 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int*>(_buffer + 32) = x;
  *reinterpret_cast<int*>(_buffer + 36) = y;
  *reinterpret_cast<void**>(_buffer + 40) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(_service_id, _kSumId, Unwrap_Int32_2, _buffer, kSize);
}
