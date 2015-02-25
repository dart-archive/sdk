// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include "performance_service.h"
#include "include/service_api.h"
#include <stdlib.h>

static ServiceId service_id_ = kNoServiceId;

void PerformanceService::setup() {
  service_id_ = ServiceApiLookup("PerformanceService");
}

void PerformanceService::tearDown() {
  ServiceApiTerminate(service_id_);
  service_id_ = kNoServiceId;
}

static const MethodId kEchoId_ = reinterpret_cast<MethodId>(1);

int32_t PerformanceService::echo(int32_t n) {
  static const int kSize = 48;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int32_t*>(_buffer + 40) = n;
  ServiceApiInvoke(service_id_, kEchoId_, _buffer, kSize);
  return *reinterpret_cast<int64_t*>(_buffer + 40);
}

static void Unwrap_int32_8(void* raw) {
  typedef void (*cbt)(int32_t);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 40);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  free(buffer);
  callback(result);
}

void PerformanceService::echoAsync(int32_t n, void (*callback)(int32_t)) {
  static const int kSize = 48 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int32_t*>(_buffer + 40) = n;
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kEchoId_, Unwrap_int32_8, _buffer, kSize);
}

static const MethodId kCountTreeNodesId_ = reinterpret_cast<MethodId>(2);

int32_t PerformanceService::countTreeNodes(TreeNodeBuilder node) {
  return node.InvokeMethod(service_id_, kCountTreeNodesId_);
}

static const MethodId kBuildTreeId_ = reinterpret_cast<MethodId>(3);

TreeNode PerformanceService::buildTree(int32_t n) {
  static const int kSize = 48;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int32_t*>(_buffer + 40) = n;
  ServiceApiInvoke(service_id_, kBuildTreeId_, _buffer, kSize);
  int64_t result = *reinterpret_cast<int64_t*>(_buffer + 40);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  return TreeNode(segment, 8);
}

static void Unwrap_TreeNode_8(void* raw) {
  typedef void (*cbt)(TreeNode);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 40);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  free(buffer);
  callback(TreeNode(segment, 8));
}

void PerformanceService::buildTreeAsync(int32_t n, void (*callback)(TreeNode)) {
  static const int kSize = 48 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int32_t*>(_buffer + 40) = n;
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kBuildTreeId_, Unwrap_TreeNode_8, _buffer, kSize);
}

List<TreeNodeBuilder> TreeNodeBuilder::initChildren(int length) {
  Reader result = NewList(0, length, 8);
  return List<TreeNodeBuilder>(result.segment(), result.offset(), length);
}
