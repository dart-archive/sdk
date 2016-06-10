// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_FREERTOS_GLOBALS_H_
#define SRC_FREERTOS_GLOBALS_H_

// Use 4kb pages.
#define PAGE_SIZE_SHIFT 12
#define PAGE_SIZE (1 << PAGE_SIZE_SHIFT)

#define MAX(a, b) ((a) > (b) ? (a) : (b))
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#define ROUNDUP(a, b) (((a) + ((b) - 1)) & ~((b) - 1))
#define ROUNDDOWN(a, b) ((a) & ~((b) - 1))
#define ALIGN(a, b) ROUNDUP(a, b)
#define IS_ALIGNED(a, b) (!(((uintptr_t)(a)) & (((uintptr_t)(b)) - 1)))
#define PAGE_ALIGN(x) ALIGN(x, PAGE_SIZE)
#define IS_PAGE_ALIGNED(x) IS_ALIGNED(x, PAGE_SIZE)

#endif  // SRC_FREERTOS_GLOBALS_H_
