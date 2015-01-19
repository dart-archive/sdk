// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/fletch.h"
#include "src/vm/platform.h"
#include "src/vm/thread.h"
#include "src/vm/object_memory.h"

namespace fletch {

void Fletch::Setup() {
  Platform::Setup();
  ObjectMemory::Setup();
}

void Fletch::TearDown() {
  ObjectMemory::TearDown();
}

}  // namespace fletch
