// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef DARTINO_TARGET_OS_POSIX

#include "src/vm/tick_sampler.h"

namespace dartino {

Atomic<bool> TickSampler::is_active_(false);
void TickSampler::Setup() {}
void TickSampler::Teardown() {}

}  // namespace dartino

#endif  // DARTINO_TICK_SAMPLER_MACOS
