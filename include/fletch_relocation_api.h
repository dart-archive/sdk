// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef INCLUDE_FLETCH_RELOCATION_API_H_
#define INCLUDE_FLETCH_RELOCATION_API_H_

#include <stdint.h>
#include <stddef.h>

#include "include/fletch_api.h"

// Returns the memory requirement in bytes for the given program. The
// reported memory requirement includes the size of an info block as
// appended when relocating a program. It is thus suitable as size
// argument to FletchRelocateProgram.
FLETCH_EXPORT size_t FletchGetProgramSize(FletchProgram program);

// Relocates the given program to the new address given by base.
// The resulting blob is written to the memory region referred to
// by target.
//
// base and target may coincide, if the new location of the program
// is in random access memory. Otherwise, the caller is responsible
// for copying the blob written to target to its new location.
//
// The memory region pointed to by target has to be big enough to
// hold the relocated program plus an appended info block. The
// function FletchGetProgramSize can be used to query this information.
//
// The address referred to by base has to be 4k aligned.
//
// On success, the number of bytes written is returned. Otherwise,
// a negative value is returned.
FLETCH_EXPORT int FletchRelocateProgram(FletchProgram program,
                                        void* target,
                                        uintptr_t base);

#endif  // INCLUDE_FLETCH_RELOCATION_API_H_
