// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include "todomvc_service.h"
#include "include/service_api.h"
#include <stdlib.h>

static ServiceId service_id_ = kNoServiceId;

void TodoMVCService::setup() {
  service_id_ = ServiceApiLookup("TodoMVCService");
}

void TodoMVCService::tearDown() {
  ServiceApiTerminate(service_id_);
  service_id_ = kNoServiceId;
}

static const MethodId kCreateItemId_ = reinterpret_cast<MethodId>(1);

void TodoMVCService::createItem(BoxedStringBuilder title) {
  title.InvokeMethod(service_id_, kCreateItemId_);
}

static void Unwrap_void_8(void* raw) {
  typedef void (*cbt)(void*);
  char* buffer = reinterpret_cast<char*>(raw);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 40);
  void* callback_data = *reinterpret_cast<void**>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback(callback_data);
}

void TodoMVCService::createItemAsync(BoxedStringBuilder title, void (*callback)(void*), void* callback_data) {
  title.InvokeMethodAsync(service_id_, kCreateItemId_, Unwrap_void_8, reinterpret_cast<void*>(callback), callback_data);
}

static const MethodId kDeleteItemId_ = reinterpret_cast<MethodId>(2);

void TodoMVCService::deleteItem(int32_t id) {
  static const int kSize = 64;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 48) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 56) = id;
  ServiceApiInvoke(service_id_, kDeleteItemId_, _buffer, kSize);
}

void TodoMVCService::deleteItemAsync(int32_t id, void (*callback)(void*), void* callback_data) {
  static const int kSize = 64 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 48) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 56) = id;
  *reinterpret_cast<void**>(_buffer + 40) = reinterpret_cast<void*>(callback);
  *reinterpret_cast<void**>(_buffer + 32) = callback_data;
  ServiceApiInvokeAsync(service_id_, kDeleteItemId_, Unwrap_void_8, _buffer, kSize);
}

static const MethodId kCompleteItemId_ = reinterpret_cast<MethodId>(3);

void TodoMVCService::completeItem(int32_t id) {
  static const int kSize = 64;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 48) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 56) = id;
  ServiceApiInvoke(service_id_, kCompleteItemId_, _buffer, kSize);
}

void TodoMVCService::completeItemAsync(int32_t id, void (*callback)(void*), void* callback_data) {
  static const int kSize = 64 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 48) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 56) = id;
  *reinterpret_cast<void**>(_buffer + 40) = reinterpret_cast<void*>(callback);
  *reinterpret_cast<void**>(_buffer + 32) = callback_data;
  ServiceApiInvokeAsync(service_id_, kCompleteItemId_, Unwrap_void_8, _buffer, kSize);
}

static const MethodId kUncompleteItemId_ = reinterpret_cast<MethodId>(4);

void TodoMVCService::uncompleteItem(int32_t id) {
  static const int kSize = 64;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 48) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 56) = id;
  ServiceApiInvoke(service_id_, kUncompleteItemId_, _buffer, kSize);
}

void TodoMVCService::uncompleteItemAsync(int32_t id, void (*callback)(void*), void* callback_data) {
  static const int kSize = 64 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 48) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 56) = id;
  *reinterpret_cast<void**>(_buffer + 40) = reinterpret_cast<void*>(callback);
  *reinterpret_cast<void**>(_buffer + 32) = callback_data;
  ServiceApiInvokeAsync(service_id_, kUncompleteItemId_, Unwrap_void_8, _buffer, kSize);
}

static const MethodId kClearItemsId_ = reinterpret_cast<MethodId>(5);

void TodoMVCService::clearItems() {
  static const int kSize = 64;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 48) = 0;
  ServiceApiInvoke(service_id_, kClearItemsId_, _buffer, kSize);
}

void TodoMVCService::clearItemsAsync(void (*callback)(void*), void* callback_data) {
  static const int kSize = 64 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 48) = 0;
  *reinterpret_cast<void**>(_buffer + 40) = reinterpret_cast<void*>(callback);
  *reinterpret_cast<void**>(_buffer + 32) = callback_data;
  ServiceApiInvokeAsync(service_id_, kClearItemsId_, Unwrap_void_8, _buffer, kSize);
}

static const MethodId kDispatchId_ = reinterpret_cast<MethodId>(6);

void TodoMVCService::dispatch(uint16_t id) {
  static const int kSize = 64;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 48) = 0;
  *reinterpret_cast<uint16_t*>(_buffer + 56) = id;
  ServiceApiInvoke(service_id_, kDispatchId_, _buffer, kSize);
}

void TodoMVCService::dispatchAsync(uint16_t id, void (*callback)(void*), void* callback_data) {
  static const int kSize = 64 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 48) = 0;
  *reinterpret_cast<uint16_t*>(_buffer + 56) = id;
  *reinterpret_cast<void**>(_buffer + 40) = reinterpret_cast<void*>(callback);
  *reinterpret_cast<void**>(_buffer + 32) = callback_data;
  ServiceApiInvokeAsync(service_id_, kDispatchId_, Unwrap_void_8, _buffer, kSize);
}

static const MethodId kSyncId_ = reinterpret_cast<MethodId>(7);

PatchSet TodoMVCService::sync() {
  static const int kSize = 64;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 48) = 0;
  ServiceApiInvoke(service_id_, kSyncId_, _buffer, kSize);
  int64_t result = *reinterpret_cast<int64_t*>(_buffer + 56);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  return PatchSet(segment, 8);
}

static void Unwrap_PatchSet_8(void* raw) {
  typedef void (*cbt)(PatchSet, void*);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 56);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 40);
  void* callback_data = *reinterpret_cast<void**>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback(PatchSet(segment, 8), callback_data);
}

void TodoMVCService::syncAsync(void (*callback)(PatchSet, void*), void* callback_data) {
  static const int kSize = 64 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 48) = 0;
  *reinterpret_cast<void**>(_buffer + 40) = reinterpret_cast<void*>(callback);
  *reinterpret_cast<void**>(_buffer + 32) = callback_data;
  ServiceApiInvokeAsync(service_id_, kSyncId_, Unwrap_PatchSet_8, _buffer, kSize);
}

static const MethodId kResetId_ = reinterpret_cast<MethodId>(8);

void TodoMVCService::reset() {
  static const int kSize = 64;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 48) = 0;
  ServiceApiInvoke(service_id_, kResetId_, _buffer, kSize);
}

void TodoMVCService::resetAsync(void (*callback)(void*), void* callback_data) {
  static const int kSize = 64 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 48) = 0;
  *reinterpret_cast<void**>(_buffer + 40) = reinterpret_cast<void*>(callback);
  *reinterpret_cast<void**>(_buffer + 32) = callback_data;
  ServiceApiInvokeAsync(service_id_, kResetId_, Unwrap_void_8, _buffer, kSize);
}

List<uint16_t> NodeBuilder::initStrData(int length) {
  setTag(4);
  Reader result = NewList(0, length, 2);
  return List<uint16_t>(result.segment(), result.offset(), length);
}

ConsBuilder NodeBuilder::initCons() {
  setTag(5);
  return ConsBuilder(segment(), offset() + 0);
}

Cons Node::getCons() const { return Cons(segment(), offset() + 0); }

NodeBuilder ConsBuilder::initFst() {
  Builder result = NewStruct(0, 24);
  return NodeBuilder(result);
}

NodeBuilder ConsBuilder::initSnd() {
  Builder result = NewStruct(8, 24);
  return NodeBuilder(result);
}

Node Cons::getFst() const { return ReadStruct<Node>(0); }

Node Cons::getSnd() const { return ReadStruct<Node>(8); }

NodeBuilder PatchBuilder::initContent() {
  return NodeBuilder(segment(), offset() + 0);
}

List<uint8_t> PatchBuilder::initPath(int length) {
  Reader result = NewList(24, length, 1);
  return List<uint8_t>(result.segment(), result.offset(), length);
}

Node Patch::getContent() const { return Node(segment(), offset() + 0); }

List<PatchBuilder> PatchSetBuilder::initPatches(int length) {
  Reader result = NewList(0, length, 32);
  return List<PatchBuilder>(result.segment(), result.offset(), length);
}

List<uint16_t> BoxedStringBuilder::initStrData(int length) {
  Reader result = NewList(0, length, 2);
  return List<uint16_t>(result.segment(), result.offset(), length);
}
