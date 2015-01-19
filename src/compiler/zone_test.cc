// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/compiler/allocation.h"
#include "src/shared/test_case.h"
#include "src/compiler/zone.h"

namespace fletch {

TEST_CASE(Zone) {
  Zone zone;
  void* first = zone.Allocate(10);
  void* second = zone.Allocate(20);
  EXPECT(first != second);
  EXPECT(zone.Allocate(10 * MB) != NULL);
}

TEST_CASE(ZoneAllocated) {
  static int marker;
  class SimpleZoneObject : public ZoneAllocated {
   public:
    SimpleZoneObject() : slot(marker++) { }
    int slot;
  };

  // Reset the marker.
  marker = 0;

  // Create a few zone allocated objects.
  Zone zone;
  SimpleZoneObject* first = new(&zone) SimpleZoneObject();
  EXPECT(first != NULL);
  SimpleZoneObject* second = new(&zone) SimpleZoneObject();
  EXPECT(second != NULL);
  EXPECT(first != second);

  // Make sure the constructors were invoked.
  EXPECT_EQ(0, first->slot);
  EXPECT_EQ(1, second->slot);

  // Make sure we can write to the members of the zone objects.
  first->slot = 42;
  second->slot = 87;
  EXPECT_EQ(42, first->slot);
  EXPECT_EQ(87, second->slot);
}

}  // namespace fletch
