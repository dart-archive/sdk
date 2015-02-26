// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include "buildbot_service.h"
#include "include/service_api.h"
#include <stdlib.h>

static ServiceId service_id_ = kNoServiceId;

void BuildBotService::setup() {
  service_id_ = ServiceApiLookup("BuildBotService");
}

void BuildBotService::tearDown() {
  ServiceApiTerminate(service_id_);
  service_id_ = kNoServiceId;
}

static const MethodId kSyncId_ = reinterpret_cast<MethodId>(1);

PatchSet BuildBotService::sync() {
  static const int kSize = 48;
  char _bits[kSize];
  char* _buffer = _bits;
  ServiceApiInvoke(service_id_, kSyncId_, _buffer, kSize);
  int64_t result = *reinterpret_cast<int64_t*>(_buffer + 40);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  return PatchSet(segment, 8);
}

static void Unwrap_PatchSet_8(void* raw) {
  typedef void (*cbt)(PatchSet);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 40);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  free(buffer);
  callback(PatchSet(segment, 8));
}

void BuildBotService::syncAsync(void (*callback)(PatchSet)) {
  static const int kSize = 48 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kSyncId_, Unwrap_PatchSet_8, _buffer, kSize);
}

List<uint8_t> StrBuilder::initChars(int length) {
  Reader result = NewList(0, length, 1);
  return List<uint8_t>(result.segment(), result.offset(), length);
}

List<uint8_t> PatchBuilder::initPath(int length) {
  Reader result = NewList(0, length, 1);
  return List<uint8_t>(result.segment(), result.offset(), length);
}

NodeBuilder PatchBuilder::initContent() {
  return NodeBuilder(segment(), offset() + 8);
}

Node Patch::getContent() const { return Node(segment(), offset() + 8); }

List<PatchBuilder> PatchSetBuilder::initPatches(int length) {
  Reader result = NewList(0, length, 8);
  return List<PatchBuilder>(result.segment(), result.offset(), length);
}
