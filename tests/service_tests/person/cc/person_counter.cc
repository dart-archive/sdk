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

static const MethodId _kCountId = reinterpret_cast<MethodId>(1);

int PersonCounter::Count(Person* person) {
  static const int kSize = 36;
  char _bits[kSize];
  char* _buffer = _bits;
  // *reinterpret_cast<int*>(_buffer + 32) = n;
  ServiceApiInvoke(_service_id, _kCountId, _buffer, kSize);
  return *reinterpret_cast<int*>(_buffer + 32);
}
