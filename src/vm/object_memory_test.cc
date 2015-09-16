// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/vm/heap.h"
#include "src/vm/object_memory.h"
#include "src/shared/test_case.h"

namespace fletch {

static Chunk* AllocateChunkAndTestIt(Space* space) {
  // Allocate chunk.
  Chunk* chunk = ObjectMemory::AllocateChunk(space, 4 * KB);
  EXPECT(chunk->base() != 0);

  // Write to the chunk and check the content.
  char* chars = reinterpret_cast<char*>(chunk->base());
  for (unsigned i = 0; i < chunk->size(); i++) {
    chars[i] = i % 128;
    EXPECT_EQ(chars[i], static_cast<char>(i % 128));
  }
  return chunk;
}

TEST_CASE(ObjectMemory) {
  Space space;

  // Allocate.
  Chunk* first = AllocateChunkAndTestIt(&space);
  Chunk* second = AllocateChunkAndTestIt(&space);

  // Compare.
  EXPECT(first != second);

  // Free.
  ObjectMemory::FreeChunk(first);
  ObjectMemory::FreeChunk(second);
}

TEST_CASE(Space_PrependSpace) {
  // Test prepending onto non-empty space.
  {
    Space* space = new Space(32);
    Space* space2 = new Space(32);

    space->AdjustAllocationBudget(0);
    space2->AdjustAllocationBudget(0);

    space->Allocate(8);
    uword space2_object = space2->Allocate(8);
    space2->PrependSpace(space);
    uword space2_object2 = space2->Allocate(8);

    ASSERT(space2_object2 == (space2_object + 8));

    delete space2;
  }
  // Test prepending onto empty space.
  {
    Space* space = new Space(32);
    Space* space2 = new Space();

    space->AdjustAllocationBudget(0);
    space2->AdjustAllocationBudget(0);

    uword space_object = space->Allocate(8);
    space2->PrependSpace(space);
    uword space_object2 = space2->Allocate(8);

    ASSERT(space_object2 == (space_object + 8));

    delete space2;
  }
}

}  // namespace fletch
