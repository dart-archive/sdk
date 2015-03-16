// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include "conformance_service.h"
#include "include/service_api.h"
#include <stdlib.h>

static ServiceId service_id_ = kNoServiceId;

void ConformanceService::setup() {
  service_id_ = ServiceApiLookup("ConformanceService");
}

void ConformanceService::tearDown() {
  ServiceApiTerminate(service_id_);
  service_id_ = kNoServiceId;
}

static const MethodId kGetAgeId_ = reinterpret_cast<MethodId>(1);

int32_t ConformanceService::getAge(PersonBuilder person) {
  return person.InvokeMethod(service_id_, kGetAgeId_);
}

static void Unwrap_int32_24(void* raw) {
  typedef void (*cbt)(int32_t);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback(result);
}

void ConformanceService::getAgeAsync(PersonBuilder person, void (*callback)(int32_t)) {
  person.InvokeMethodAsync(service_id_, kGetAgeId_, Unwrap_int32_24, reinterpret_cast<void*>(callback));
}

static const MethodId kGetBoxedAgeId_ = reinterpret_cast<MethodId>(2);

int32_t ConformanceService::getBoxedAge(PersonBoxBuilder box) {
  return box.InvokeMethod(service_id_, kGetBoxedAgeId_);
}

static void Unwrap_int32_8(void* raw) {
  typedef void (*cbt)(int32_t);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback(result);
}

void ConformanceService::getBoxedAgeAsync(PersonBoxBuilder box, void (*callback)(int32_t)) {
  box.InvokeMethodAsync(service_id_, kGetBoxedAgeId_, Unwrap_int32_8, reinterpret_cast<void*>(callback));
}

static const MethodId kGetAgeStatsId_ = reinterpret_cast<MethodId>(3);

AgeStats ConformanceService::getAgeStats(PersonBuilder person) {
  int64_t result = person.InvokeMethod(service_id_, kGetAgeStatsId_);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  return AgeStats(segment, 8);
}

static void Unwrap_AgeStats_24(void* raw) {
  typedef void (*cbt)(AgeStats);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback(AgeStats(segment, 8));
}

void ConformanceService::getAgeStatsAsync(PersonBuilder person, void (*callback)(AgeStats)) {
  person.InvokeMethodAsync(service_id_, kGetAgeStatsId_, Unwrap_AgeStats_24, reinterpret_cast<void*>(callback));
}

static const MethodId kCreateAgeStatsId_ = reinterpret_cast<MethodId>(4);

AgeStats ConformanceService::createAgeStats(int32_t averageAge, int32_t sum) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = averageAge;
  *reinterpret_cast<int32_t*>(_buffer + 52) = sum;
  ServiceApiInvoke(service_id_, kCreateAgeStatsId_, _buffer, kSize);
  int64_t result = *reinterpret_cast<int64_t*>(_buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  return AgeStats(segment, 8);
}

static void Unwrap_AgeStats_8(void* raw) {
  typedef void (*cbt)(AgeStats);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback(AgeStats(segment, 8));
}

void ConformanceService::createAgeStatsAsync(int32_t averageAge, int32_t sum, void (*callback)(AgeStats)) {
  static const int kSize = 56 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = averageAge;
  *reinterpret_cast<int32_t*>(_buffer + 52) = sum;
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kCreateAgeStatsId_, Unwrap_AgeStats_8, _buffer, kSize);
}

static const MethodId kCreatePersonId_ = reinterpret_cast<MethodId>(5);

Person ConformanceService::createPerson(int32_t children) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = children;
  ServiceApiInvoke(service_id_, kCreatePersonId_, _buffer, kSize);
  int64_t result = *reinterpret_cast<int64_t*>(_buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  return Person(segment, 8);
}

static void Unwrap_Person_8(void* raw) {
  typedef void (*cbt)(Person);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback(Person(segment, 8));
}

void ConformanceService::createPersonAsync(int32_t children, void (*callback)(Person)) {
  static const int kSize = 56 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = children;
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kCreatePersonId_, Unwrap_Person_8, _buffer, kSize);
}

static const MethodId kCreateNodeId_ = reinterpret_cast<MethodId>(6);

Node ConformanceService::createNode(int32_t depth) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = depth;
  ServiceApiInvoke(service_id_, kCreateNodeId_, _buffer, kSize);
  int64_t result = *reinterpret_cast<int64_t*>(_buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  return Node(segment, 8);
}

static void Unwrap_Node_8(void* raw) {
  typedef void (*cbt)(Node);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback(Node(segment, 8));
}

void ConformanceService::createNodeAsync(int32_t depth, void (*callback)(Node)) {
  static const int kSize = 56 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<int32_t*>(_buffer + 48) = depth;
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kCreateNodeId_, Unwrap_Node_8, _buffer, kSize);
}

static const MethodId kCountId_ = reinterpret_cast<MethodId>(7);

int32_t ConformanceService::count(PersonBuilder person) {
  return person.InvokeMethod(service_id_, kCountId_);
}

void ConformanceService::countAsync(PersonBuilder person, void (*callback)(int32_t)) {
  person.InvokeMethodAsync(service_id_, kCountId_, Unwrap_int32_24, reinterpret_cast<void*>(callback));
}

static const MethodId kDepthId_ = reinterpret_cast<MethodId>(8);

int32_t ConformanceService::depth(NodeBuilder node) {
  return node.InvokeMethod(service_id_, kDepthId_);
}

void ConformanceService::depthAsync(NodeBuilder node, void (*callback)(int32_t)) {
  node.InvokeMethodAsync(service_id_, kDepthId_, Unwrap_int32_24, reinterpret_cast<void*>(callback));
}

static const MethodId kFooId_ = reinterpret_cast<MethodId>(9);

void ConformanceService::foo() {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  ServiceApiInvoke(service_id_, kFooId_, _buffer, kSize);
}

static void Unwrap_void_8(void* raw) {
  typedef void (*cbt)();
  char* buffer = reinterpret_cast<char*>(raw);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback();
}

void ConformanceService::fooAsync(void (*callback)()) {
  static const int kSize = 56 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kFooId_, Unwrap_void_8, _buffer, kSize);
}

static const MethodId kBarId_ = reinterpret_cast<MethodId>(10);

int32_t ConformanceService::bar(EmptyBuilder empty) {
  return empty.InvokeMethod(service_id_, kBarId_);
}

static void Unwrap_int32_0(void* raw) {
  typedef void (*cbt)(int32_t);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback(result);
}

void ConformanceService::barAsync(EmptyBuilder empty, void (*callback)(int32_t)) {
  empty.InvokeMethodAsync(service_id_, kBarId_, Unwrap_int32_0, reinterpret_cast<void*>(callback));
}

static const MethodId kPingId_ = reinterpret_cast<MethodId>(11);

int32_t ConformanceService::ping() {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  ServiceApiInvoke(service_id_, kPingId_, _buffer, kSize);
  return *reinterpret_cast<int64_t*>(_buffer + 48);
}

void ConformanceService::pingAsync(void (*callback)(int32_t)) {
  static const int kSize = 56 + 0 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<void**>(_buffer + 32) = reinterpret_cast<void*>(callback);
  ServiceApiInvokeAsync(service_id_, kPingId_, Unwrap_int32_8, _buffer, kSize);
}

static const MethodId kFlipTableId_ = reinterpret_cast<MethodId>(12);

TableFlip ConformanceService::flipTable(TableFlipBuilder flip) {
  int64_t result = flip.InvokeMethod(service_id_, kFlipTableId_);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  return TableFlip(segment, 8);
}

static void Unwrap_TableFlip_8(void* raw) {
  typedef void (*cbt)(TableFlip);
  char* buffer = reinterpret_cast<char*>(raw);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = MessageReader::GetRootSegment(memory);
  cbt callback = *reinterpret_cast<cbt*>(buffer + 32);
  MessageBuilder::DeleteMessage(buffer);
  callback(TableFlip(segment, 8));
}

void ConformanceService::flipTableAsync(TableFlipBuilder flip, void (*callback)(TableFlip)) {
  flip.InvokeMethodAsync(service_id_, kFlipTableId_, Unwrap_TableFlip_8, reinterpret_cast<void*>(callback));
}

List<uint16_t> PersonBuilder::initNameData(int length) {
  Reader result = NewList(0, length, 2);
  return List<uint16_t>(result.segment(), result.offset(), length);
}

List<PersonBuilder> PersonBuilder::initChildren(int length) {
  Reader result = NewList(8, length, 24);
  return List<PersonBuilder>(result.segment(), result.offset(), length);
}

SmallBuilder LargeBuilder::initS() {
  return SmallBuilder(segment(), offset() + 0);
}

Small Large::getS() const { return Small(segment(), offset() + 0); }

PersonBuilder PersonBoxBuilder::initPerson() {
  Builder result = NewStruct(0, 24);
  return PersonBuilder(result);
}

Person PersonBox::getPerson() const { return ReadStruct<Person>(0); }

ConsBuilder NodeBuilder::initCons() {
  setTag(3);
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

List<uint16_t> TableFlipBuilder::initFlipData(int length) {
  Reader result = NewList(0, length, 2);
  return List<uint16_t>(result.segment(), result.offset(), length);
}
