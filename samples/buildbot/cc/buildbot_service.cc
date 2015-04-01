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

static const MethodId kRefreshId_ = reinterpret_cast<MethodId>(1);

BuildBotPatchData BuildBotService::refresh() {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  ServiceApiInvoke(service_id_, kRefreshId_, _buffer, kSize);
  int64_t result = *reinterpret_cast<int64_t*>(_buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  return BuildBotPatchData(segment, 8);
}

static void Unwrap_BuildBotPatchData_8(void* raw) {
  typedef void (*cbt)(BuildBotPatchData);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback(BuildBotPatchData(segment, 8));
}

void BuildBotService::refreshAsync(void (*callback)(BuildBotPatchData)) {
  static const int kSize = 56 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kRefreshId_, Unwrap_BuildBotPatchData_8, _buffer, kSize);
}

static const MethodId kSetConsoleCountId_ = reinterpret_cast<MethodId>(2);

void BuildBotService::setConsoleCount(int32_t count) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = count;
  ServiceApiInvoke(service_id_, kSetConsoleCountId_, _buffer, kSize);
}

static void Unwrap_void_8(void* raw) {
  typedef void (*cbt)();
  char* buffer = reinterpret_cast<char*>(raw);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback();
}

void BuildBotService::setConsoleCountAsync(int32_t count, void (*callback)()) {
  static const int kSize = 56 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = count;
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kSetConsoleCountId_, Unwrap_void_8, _buffer, kSize);
}

static const MethodId kSetConsoleMinimumIndexId_ = reinterpret_cast<MethodId>(3);

void BuildBotService::setConsoleMinimumIndex(int32_t index) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = index;
  ServiceApiInvoke(service_id_, kSetConsoleMinimumIndexId_, _buffer, kSize);
}

void BuildBotService::setConsoleMinimumIndexAsync(int32_t index, void (*callback)()) {
  static const int kSize = 56 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = index;
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kSetConsoleMinimumIndexId_, Unwrap_void_8, _buffer, kSize);
}

static const MethodId kSetConsoleMaximumIndexId_ = reinterpret_cast<MethodId>(4);

void BuildBotService::setConsoleMaximumIndex(int32_t index) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = index;
  ServiceApiInvoke(service_id_, kSetConsoleMaximumIndexId_, _buffer, kSize);
}

void BuildBotService::setConsoleMaximumIndexAsync(int32_t index, void (*callback)()) {
  static const int kSize = 56 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = index;
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kSetConsoleMaximumIndexId_, Unwrap_void_8, _buffer, kSize);
}

List<uint16_t> ConsoleNodeDataBuilder::initTitleData(int length) {
  Reader result = NewList(0, length, 2);
  return List<uint16_t>(result.segment(), result.offset(), length);
}

List<uint16_t> ConsoleNodeDataBuilder::initStatusData(int length) {
  Reader result = NewList(8, length, 2);
  return List<uint16_t>(result.segment(), result.offset(), length);
}

List<CommitNodeDataBuilder> ConsoleNodeDataBuilder::initCommits(int length) {
  Reader result = NewList(16, length, 24);
  return List<CommitNodeDataBuilder>(result.segment(), result.offset(), length);
}

List<uint16_t> CommitNodeDataBuilder::initAuthorData(int length) {
  Reader result = NewList(0, length, 2);
  return List<uint16_t>(result.segment(), result.offset(), length);
}

List<uint16_t> CommitNodeDataBuilder::initMessageData(int length) {
  Reader result = NewList(8, length, 2);
  return List<uint16_t>(result.segment(), result.offset(), length);
}

ConsolePatchDataBuilder BuildBotPatchDataBuilder::initConsolePatch() {
  setTag(2);
  return ConsolePatchDataBuilder(segment(), offset() + 0);
}

ConsolePatchData BuildBotPatchData::getConsolePatch() const { return ConsolePatchData(segment(), offset() + 0); }

ConsoleNodeDataBuilder ConsolePatchDataBuilder::initReplace() {
  setTag(1);
  return ConsoleNodeDataBuilder(segment(), offset() + 0);
}

List<ConsoleUpdatePatchDataBuilder> ConsolePatchDataBuilder::initUpdates(int length) {
  setTag(2);
  Reader result = NewList(0, length, 16);
  return List<ConsoleUpdatePatchDataBuilder>(result.segment(), result.offset(), length);
}

ConsoleNodeData ConsolePatchData::getReplace() const { return ConsoleNodeData(segment(), offset() + 0); }

List<uint16_t> ConsoleUpdatePatchDataBuilder::initTitleData(int length) {
  setTag(1);
  Reader result = NewList(0, length, 2);
  return List<uint16_t>(result.segment(), result.offset(), length);
}

List<uint16_t> ConsoleUpdatePatchDataBuilder::initStatusData(int length) {
  setTag(2);
  Reader result = NewList(0, length, 2);
  return List<uint16_t>(result.segment(), result.offset(), length);
}

CommitListPatchDataBuilder ConsoleUpdatePatchDataBuilder::initCommits() {
  setTag(4);
  return CommitListPatchDataBuilder(segment(), offset() + 0);
}

CommitListPatchData ConsoleUpdatePatchData::getCommits() const { return CommitListPatchData(segment(), offset() + 0); }

CommitNodeDataBuilder CommitPatchDataBuilder::initReplace() {
  setTag(1);
  return CommitNodeDataBuilder(segment(), offset() + 0);
}

List<CommitUpdatePatchDataBuilder> CommitPatchDataBuilder::initUpdates(int length) {
  setTag(2);
  Reader result = NewList(0, length, 16);
  return List<CommitUpdatePatchDataBuilder>(result.segment(), result.offset(), length);
}

CommitNodeData CommitPatchData::getReplace() const { return CommitNodeData(segment(), offset() + 0); }

List<uint16_t> CommitUpdatePatchDataBuilder::initAuthorData(int length) {
  setTag(2);
  Reader result = NewList(0, length, 2);
  return List<uint16_t>(result.segment(), result.offset(), length);
}

List<uint16_t> CommitUpdatePatchDataBuilder::initMessageData(int length) {
  setTag(3);
  Reader result = NewList(0, length, 2);
  return List<uint16_t>(result.segment(), result.offset(), length);
}

List<CommitListUpdatePatchDataBuilder> CommitListPatchDataBuilder::initUpdates(int length) {
  Reader result = NewList(0, length, 16);
  return List<CommitListUpdatePatchDataBuilder>(result.segment(), result.offset(), length);
}

List<CommitNodeDataBuilder> CommitListUpdatePatchDataBuilder::initInsert(int length) {
  setTag(1);
  Reader result = NewList(0, length, 24);
  return List<CommitNodeDataBuilder>(result.segment(), result.offset(), length);
}

List<CommitPatchDataBuilder> CommitListUpdatePatchDataBuilder::initPatch(int length) {
  setTag(2);
  Reader result = NewList(0, length, 24);
  return List<CommitPatchDataBuilder>(result.segment(), result.offset(), length);
}
