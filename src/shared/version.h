// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_VERSION_H_
#define SRC_SHARED_VERSION_H_

#ifdef _MSC_VER
// TODO(herhut): Do we need a __declspec here for Windows?
#define DARTINO_VISIBILITY_DEFAULT
#else
#define DARTINO_VISIBILITY_DEFAULT __attribute__((visibility("default")))
#endif

namespace dartino {

extern "C" DARTINO_VISIBILITY_DEFAULT const char* GetVersion();

}  // namespace dartino

#endif  // SRC_SHARED_VERSION_H_
