// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include "person_counter.h"
#include "include/service_api.h"
#include <stdlib.h>

static ServiceId service_id_ = kNoServiceId;

void PersonCounter::Setup() {
  service_id_ = ServiceApiLookup("PersonCounter");
}

void PersonCounter::TearDown() {
  ServiceApiTerminate(service_id_);
  service_id_ = kNoServiceId;
}

static const MethodId _kGetAgeId = reinterpret_cast<MethodId>(1);
static const MethodId _kCountId = reinterpret_cast<MethodId>(2);
static const MethodId _kGetAgeStatsId = reinterpret_cast<MethodId>(3);

int PersonCounter::GetAge(PersonBuilder person) {
  return person.InvokeMethod(service_id_, _kGetAgeId);
}

AgeStats PersonCounter::GetAgeStats(PersonBuilder person) {
  int result = person.InvokeMethod(service_id_, _kGetAgeStatsId);
  char* memory = reinterpret_cast<char*>(result);
  Segment* segment = new Segment(memory, 32 + 8 + AgeStats::kSize);
  return AgeStats(segment, 32 + 8);
}

int PersonCounter::Count(PersonBuilder person) {
  return person.InvokeMethod(service_id_, _kCountId);
}

List<PersonBuilder> PersonBuilder::NewChildren(int length) {
  Builder result = NewList(Person::kChildrenOffset, length, Person::kSize);
  return List<PersonBuilder>(result);
}
