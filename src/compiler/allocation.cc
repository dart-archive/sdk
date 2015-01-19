// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/compiler/allocation.h"
#include "src/compiler/zone.h"

namespace fletch {

StackResource::StackResource() {
}

StackResource::~StackResource() {
}

void* ZoneAllocated::operator new(size_t size, Zone* zone) {
  return zone->Allocate(size);
}

}  // namespace fletch
