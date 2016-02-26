// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef PLATFORMS_STM_DISCO_DARTINO_SRC_PAGE_ALLOC_H_
#define PLATFORMS_STM_DISCO_DARTINO_SRC_PAGE_ALLOC_H_

#define PAGE_SIZE_SHIFT 12
#define PAGE_SIZE (1 << PAGE_SIZE_SHIFT)

#define ANY_ARENA (-1)
typedef struct memory_range_struct {
  void* address;
  size_t size;
} memory_range_t;

#ifdef __cplusplus
extern "C" {
#endif

void* page_alloc(size_t pages, int arenas);
void page_free(void* start, size_t pages);
int get_arena_locations(memory_range_t* ranges_return, int ranges);

#ifdef __cplusplus
}
#endif

#endif  // PLATFORMS_STM_DISCO_DARTINO_SRC_PAGE_ALLOC_H_ 1
