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

PresenterPatchSet BuildBotService::refresh() {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  ServiceApiInvoke(service_id_, kRefreshId_, _buffer, kSize);
  int64_t result = *reinterpret_cast<int64_t*>(_buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  return PresenterPatchSet(segment, 8);
}

static void Unwrap_PresenterPatchSet_8(void* raw) {
  typedef void (*cbt)(PresenterPatchSet);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback(PresenterPatchSet(segment, 8));
}

void BuildBotService::refreshAsync(void (*callback)(PresenterPatchSet)) {
  static const int kSize = 56 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kRefreshId_, Unwrap_PresenterPatchSet_8, _buffer, kSize);
}

ConsolePatchSetBuilder PresenterPatchSetBuilder::initConsolePatchSet() {
  setTag(1);
  return ConsolePatchSetBuilder(segment(), offset() + 0);
}

ConsolePatchSet PresenterPatchSet::getConsolePatchSet() const { return ConsolePatchSet(segment(), offset() + 0); }

StrDataBuilder ConsoleNodeDataBuilder::initTitle() {
  return StrDataBuilder(segment(), offset() + 0);
}

StrDataBuilder ConsoleNodeDataBuilder::initStatus() {
  return StrDataBuilder(segment(), offset() + 8);
}

List<CommitNodeDataBuilder> ConsoleNodeDataBuilder::initCommits(int length) {
  Reader result = NewList(16, length, 24);
  return List<CommitNodeDataBuilder>(result.segment(), result.offset(), length);
}

StrData ConsoleNodeData::getTitle() const { return StrData(segment(), offset() + 0); }

StrData ConsoleNodeData::getStatus() const { return StrData(segment(), offset() + 8); }

StrDataBuilder CommitNodeDataBuilder::initAuthor() {
  return StrDataBuilder(segment(), offset() + 0);
}

StrDataBuilder CommitNodeDataBuilder::initMessage() {
  return StrDataBuilder(segment(), offset() + 8);
}

StrData CommitNodeData::getAuthor() const { return StrData(segment(), offset() + 0); }

StrData CommitNodeData::getMessage() const { return StrData(segment(), offset() + 8); }

List<ConsoleNodePatchDataBuilder> ConsolePatchSetBuilder::initPatches(int length) {
  Reader result = NewList(0, length, 32);
  return List<ConsoleNodePatchDataBuilder>(result.segment(), result.offset(), length);
}

ConsoleNodeDataBuilder ConsoleNodePatchDataBuilder::initReplace() {
  setTag(1);
  return ConsoleNodeDataBuilder(segment(), offset() + 0);
}

StrDataBuilder ConsoleNodePatchDataBuilder::initTitle() {
  setTag(2);
  return StrDataBuilder(segment(), offset() + 0);
}

StrDataBuilder ConsoleNodePatchDataBuilder::initStatus() {
  setTag(3);
  return StrDataBuilder(segment(), offset() + 0);
}

ListCommitNodePatchDataBuilder ConsoleNodePatchDataBuilder::initCommits() {
  setTag(4);
  Builder result = NewStruct(0, 16);
  return ListCommitNodePatchDataBuilder(result);
}

ConsoleNodeData ConsoleNodePatchData::getReplace() const { return ConsoleNodeData(segment(), offset() + 0); }

StrData ConsoleNodePatchData::getTitle() const { return StrData(segment(), offset() + 0); }

StrData ConsoleNodePatchData::getStatus() const { return StrData(segment(), offset() + 0); }

ListCommitNodePatchData ConsoleNodePatchData::getCommits() const { return ReadStruct<ListCommitNodePatchData>(0); }

CommitNodeDataBuilder CommitNodePatchDataBuilder::initReplace() {
  setTag(1);
  return CommitNodeDataBuilder(segment(), offset() + 0);
}

StrDataBuilder CommitNodePatchDataBuilder::initAuthor() {
  setTag(3);
  return StrDataBuilder(segment(), offset() + 0);
}

StrDataBuilder CommitNodePatchDataBuilder::initMessage() {
  setTag(4);
  return StrDataBuilder(segment(), offset() + 0);
}

CommitNodeData CommitNodePatchData::getReplace() const { return CommitNodeData(segment(), offset() + 0); }

StrData CommitNodePatchData::getAuthor() const { return StrData(segment(), offset() + 0); }

StrData CommitNodePatchData::getMessage() const { return StrData(segment(), offset() + 0); }

List<CommitNodeDataBuilder> ListCommitNodePatchDataBuilder::initReplace(int length) {
  setTag(1);
  Reader result = NewList(0, length, 24);
  return List<CommitNodeDataBuilder>(result.segment(), result.offset(), length);
}

List<uint8_t> StrDataBuilder::initChars(int length) {
  Reader result = NewList(0, length, 1);
  return List<uint8_t>(result.segment(), result.offset(), length);
}
