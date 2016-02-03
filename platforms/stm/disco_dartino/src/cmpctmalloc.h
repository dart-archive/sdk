// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef PLATFORMS_STM_DISCO_DARTINO_SRC_CMPCTMALLOC_H_
#define PLATFORMS_STM_DISCO_DARTINO_SRC_CMPCTMALLOC_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>

void *cmpct_alloc(size_t size);
void *cmpct_realloc(void *ptr, size_t size);
void cmpct_free(void *ptr);
void *cmpct_memalign(size_t size, size_t alignment);

void cmpct_init(void);
void cmpct_dump(void);
void cmpct_test(void);
void cmpct_trim(void);

#ifdef __cplusplus
}
#endif

#endif  // PLATFORMS_STM_DISCO_DARTINO_SRC_CMPCTMALLOC_H_
