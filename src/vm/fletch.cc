// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/fletch.h"

#include "src/shared/platform.h"

#include "src/vm/ffi.h"
#include "src/vm/object_memory.h"
#include "src/vm/object.h"
#include "src/vm/thread.h"

namespace fletch {

void Fletch::Setup() {
  Platform::Setup();
  ObjectMemory::Setup();
  StaticClassStructures::Setup();
  ForeignFunctionInterface::Setup();
}

void Fletch::TearDown() {
  ForeignFunctionInterface::TearDown();
  StaticClassStructures::TearDown();
  ObjectMemory::TearDown();
  Platform::TearDown();
}

}  // namespace fletch
