// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_ALLOCATION_H_
#define SRC_COMPILER_ALLOCATION_H_

#include "src/shared/assert.h"

namespace fletch {

// Forward declarations.
class Zone;

class StackAllocated {
 public:
  // Ideally, the delete operator should be private instead of
  // public, but unfortunately the compiler sometimes synthesizes
  // unused destructors for derived classes, which require the
  // operator to be visible. MSVC requires the delete operator
  // to be public.
  void operator delete(void* pointer) { UNREACHABLE(); }

 private:
  void* operator new(size_t size);
};

// Stack resources are stack-allocated objects that are guaranteed
// to have their destructor invoked even in the presence of exceptions
// and unwinding.
class StackResource : public StackAllocated {
 public:
  StackResource();
  virtual ~StackResource();
};

// Zone allocated objects cannot be individually deallocated, but have
// to rely on the Zone::DeleteAll() operation to reclaim memory.
class ZoneAllocated {
 public:
  // Explicitly allocate the object in the specified zone.
  void* operator new(size_t size, Zone* zone);

 protected:
  // Disallow explicit deallocation of nodes. Nodes can only be
  // deallocated by invoking DeleteAll() on the zone they live in.
  void operator delete(void* pointer) { UNREACHABLE(); }
};

}  // namespace fletch

#endif  // SRC_COMPILER_ALLOCATION_H_
