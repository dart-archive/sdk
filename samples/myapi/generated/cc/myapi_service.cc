// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include "myapi_service.h"
#include "include/service_api.h"
#include <stdlib.h>

static ServiceId service_id_ = kNoServiceId;

void MyApiService::setup() {
  service_id_ = ServiceApiLookup("MyApiService");
}

void MyApiService::tearDown() {
  ServiceApiTerminate(service_id_);
  service_id_ = kNoServiceId;
}

static const MethodId kCreateId_ = reinterpret_cast<MethodId>(1);

int32_t MyApiService::create() {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  ServiceApiInvoke(service_id_, kCreateId_, _buffer, kSize);
  return *reinterpret_cast<int64_t*>(_buffer + 48);
}

static void Unwrap_int32_8(void* raw) {
  typedef void (*cbt)(int32_t);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback(result);
}

void MyApiService::createAsync(void (*callback)(int32_t)) {
  static const int kSize = 56 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kCreateId_, Unwrap_int32_8, _buffer, kSize);
}

static const MethodId kDestroyId_ = reinterpret_cast<MethodId>(2);

void MyApiService::destroy(int32_t api) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = api;
  ServiceApiInvoke(service_id_, kDestroyId_, _buffer, kSize);
}

static void Unwrap_void_8(void* raw) {
  typedef void (*cbt)();
  char* buffer = reinterpret_cast<char*>(raw);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback();
}

void MyApiService::destroyAsync(int32_t api, void (*callback)()) {
  static const int kSize = 56 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = api;
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kDestroyId_, Unwrap_void_8, _buffer, kSize);
}

static const MethodId kFooId_ = reinterpret_cast<MethodId>(3);

int32_t MyApiService::foo(int32_t api) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = api;
  ServiceApiInvoke(service_id_, kFooId_, _buffer, kSize);
  return *reinterpret_cast<int64_t*>(_buffer + 48);
}

void MyApiService::fooAsync(int32_t api, void (*callback)(int32_t)) {
  static const int kSize = 56 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = api;
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kFooId_, Unwrap_int32_8, _buffer, kSize);
}

static const MethodId kMyObjectFunkId_ = reinterpret_cast<MethodId>(4);

void MyApiService::MyObject_funk(int32_t api, int32_t id, int32_t o) {
  static const int kSize = 64;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = api;
  *reinterpret_cast<int32_t*>(_buffer + 52) = id;
  *reinterpret_cast<int32_t*>(_buffer + 56) = o;
  ServiceApiInvoke(service_id_, kMyObjectFunkId_, _buffer, kSize);
}

static void Unwrap_void_16(void* raw) {
  typedef void (*cbt)();
  char* buffer = reinterpret_cast<char*>(raw);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback();
}

void MyApiService::MyObject_funkAsync(int32_t api, int32_t id, int32_t o, void (*callback)()) {
  static const int kSize = 64 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = api;
  *reinterpret_cast<int32_t*>(_buffer + 52) = id;
  *reinterpret_cast<int32_t*>(_buffer + 56) = o;
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kMyObjectFunkId_, Unwrap_void_16, _buffer, kSize);
}
