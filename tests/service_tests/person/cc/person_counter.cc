// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include "person_counter.h"
#include "include/service_api.h"
#include <stdlib.h>

static ServiceId _service_id = kNoServiceId;

void PersonCounter::Setup() {
  _service_id = ServiceApiLookup("PersonCounter");
}

void PersonCounter::TearDown() {
  ServiceApiTerminate(_service_id);
  _service_id = kNoServiceId;
}

static const MethodId _kGetAgeId = reinterpret_cast<MethodId>(1);

int PersonCounter::GetAge(PersonBuilder person) {
  return person.InvokeMethod(_service_id, _kGetAgeId);
}

static const MethodId _kGetAgeStatsId = reinterpret_cast<MethodId>(2);

AgeStats PersonCounter::GetAgeStats(PersonBuilder person) {
  int64_t result = person.InvokeMethod(_service_id, _kGetAgeStatsId);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = new Segment(memory, 8);
  return AgeStats(segment, 0);
}

static const MethodId _kCountId = reinterpret_cast<MethodId>(3);

int PersonCounter::Count(PersonBuilder person) {
  return person.InvokeMethod(_service_id, _kCountId);
}

List<PersonBuilder> PersonBuilder::NewChildren(int length) {
  Builder result = NewList(8, length, 16);
  return List<PersonBuilder>(result);
}
