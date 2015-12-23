// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef FLETCH_TARGET_OS_POSIX

#include "src/vm/tick_sampler.h"

namespace fletch {

Atomic<bool> TickSampler::is_active_(false);
void TickSampler::Setup() {}
void TickSampler::Teardown() {}

}  // namespace fletch

#endif  // FLETCH_TICK_SAMPLER_MACOS
