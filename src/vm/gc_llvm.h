// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_GC_LLVM_H_
#define SRC_VM_GC_LLVM_H_

#include "src/vm/hash_map.h"

#include "src/vm/object.h"

namespace dartino {

class Heap;
class PointerVisitor;

// See http://llvm.org/docs/StackMaps.html

struct StackMapHeader {
  uint8 version;  // Currently 1.
  uint8 reserved1;
  uint16 reserved2;
  uint32 num_functions;
  uint32 num_constants;
  uint32 num_records;
};

struct StackSizeRecord {
  char* function_address;
  uint64 stack_size;
};

struct StackMapConstant {
  uint64 large_constant;
};

typedef enum {
  RegisterLocation = 1,
  DirectLocation,
  IndirectLocation,
  ConstantLocation,
  ConstantIndexLocation
} StackMapLocation;

struct StackMapRecordLocation {
  uint8 location_type;  // Actually StackMapLocation enum.
  uint8 reserved;
  uint16 dwarf_register_number;
  int32 offset_or_small_constant;
};

struct StackMapRecord {
  uint64 patch_point_id;
  uint32 instruction_offset;
  uint16 reserved;
  uint16 num_locations;
  StackMapRecordLocation first_location;  // There may be multiple.
};

struct StackMapRecordLiveOut {
  uint16 dwarf_register_number;
  uint8 reserved;
  uint8 size_in_bytes;
};

struct StackMapRecordPart2 {
  uint16 padding;
  uint16 num_live_outs;
  StackMapRecordLiveOut first_live_out;  // There may be multiple.
};

struct StackMapEntry {
  int stack_size;
  StackMapRecord* map;
};

class StackMap {
 public:
  StackMap() {}
  static void EnsureComputed();
  static StackMapRecord* get(uword return_address);
  static void Visit(TwoSpaceHeap* heap, PointerVisitor* visitor, char* fp);
  static void Dump(StackMapRecord* record);

 private:
  static HashMap<char*, StackMapEntry> return_address_to_stack_map_;
};

}  // namespace dartino

extern "C" {
extern dartino::StackMapHeader __LLVM_StackMaps;
extern char* dartino_function_table;
}

#endif  // SRC_VM_GC_LLVM_H_
