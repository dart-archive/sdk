// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/gc_llvm.h"

#include "src/shared/utils.h"
#include "src/vm/heap.h"
#include "src/vm/object.h"
#include "src/vm/object_memory.h"

namespace dartino {

HashMap<char*, StackMapEntry> StackMap::return_address_to_stack_map_;

void StackMap::Visit(Heap* process_heap, PointerVisitor* visitor, char* fp) {
  Space* from = process_heap->space();
  Space* to = process_heap->to_space();
  Space* old = process_heap->old_space();
  while (fp != nullptr) {
    char* return_address = (reinterpret_cast<char**>(fp))[1];
    auto iterator = return_address_to_stack_map_.Find(return_address);
    if (iterator != return_address_to_stack_map_.End()) {

      StackMapRecord* record = iterator->second.map;
      int stack_size = iterator->second.stack_size;
      StackMapRecordLocation* locations = &record->first_location;
      // It can be useful during debugging to call Dump(record) here.

      for (int i = 0; i < record->num_locations; i++) {
        StackMapLocation l = static_cast<StackMapLocation>(locations[i].location_type);
        if (l == ConstantLocation || l == ConstantIndexLocation) {
          continue;
        } else {
          ASSERT(l == IndirectLocation);  // Unimplemented stack map location type.
          // These are in pairs (base-derived pointer).
          ASSERT(i + 1 < record->num_locations);
          // Base-derived pair.
          ASSERT(locations[i].location_type == locations[i + 1].location_type);
          Object** base = reinterpret_cast<Object**>((uword)fp + 16 + locations[i].offset_or_small_constant);
          Object** derived = reinterpret_cast<Object**>((uword)fp + 16 + locations[i + 1 ].offset_or_small_constant);
          if (!(*base)->IsSmi()) {
            uword addr = HeapObject::cast(*base)->address();
            if (from->Includes(addr) || old->Includes(addr)) {
              uword diff = (uword)*derived - (uword)*base;
              visitor->Visit(base);
              *derived = reinterpret_cast<Object*>((uword)*base + diff);
            }
          } else {
            if (!(*derived)->IsSmi()) {
              uword addr = HeapObject::cast(*derived)->address();
              ASSERT(!from->Includes(addr));
              ASSERT(!old->Includes(addr));
              ASSERT(!to || !to->Includes(addr));
            }
          }
          i++;
        }
      }
      fp += stack_size + kWordSize;
    } else {
      // We have reached the bottom of the stack.
      break;
    }
  }
}

void StackMap::EnsureComputed() {
  if (return_address_to_stack_map_.size() != 0) return;

  ASSERT(__LLVM_StackMaps.version == 1);

  StackSizeRecord* stack_sizes = reinterpret_cast<StackSizeRecord*>((&__LLVM_StackMaps) + 1);

  HashMap<char*, int> function_to_stack_size;
  
  for (unsigned i = 0; i < __LLVM_StackMaps.num_functions; i++) {
    function_to_stack_size[stack_sizes[i].function_address] = stack_sizes[i].stack_size;
  }
 
  StackMapConstant* constants = reinterpret_cast<StackMapConstant*>(stack_sizes + __LLVM_StackMaps.num_functions);

  StackMapRecord* record = reinterpret_cast<StackMapRecord*>(constants + __LLVM_StackMaps.num_constants);

  char** table = &dartino_function_table;

  for (unsigned i = 0; i < __LLVM_StackMaps.num_records; i++) {
    // For patch point ID we just use an integer that identifies the function object.
    char* code = table[record->patch_point_id];
    int stack_size = function_to_stack_size[code];
    // A stack size of -1 is seen if a non-lowered alloca in the function makes
    // the stack size non-static.
    ASSERT(stack_size > 0);
    char* return_address = code + record->instruction_offset;
    return_address_to_stack_map_[return_address] = {stack_size, record};

    // Step across variable-sized stack map record object.
    uword addr = reinterpret_cast<uword>(&record->first_location);
    addr += sizeof(record->first_location) * record->num_locations;
    StackMapRecordPart2* part_2 = reinterpret_cast<StackMapRecordPart2*>(addr);
    addr = reinterpret_cast<uword>(&part_2->first_live_out);
    addr += sizeof(part_2->first_live_out) * part_2->num_live_outs;
    addr = Utils::RoundUp(addr, 8);
    record = reinterpret_cast<StackMapRecord*>(addr);
  }
}

void StackMap::Dump(StackMapRecord* record) {
  fprintf(stderr, "Record id=%d, offset=%d\n  locations=%d\n",
      static_cast<int>(record->patch_point_id),
      record->instruction_offset, record->num_locations);
  StackMapRecordLocation* location = &record->first_location;
  for (int i = 0; i < record->num_locations; i++) {
    fprintf(stderr, "    type=%d flags=%d, regno=%d, offset=%d\n",
        location->location_type,
        location->reserved,
        location->dwarf_register_number,
        location->offset_or_small_constant);
    location++;
  }
  StackMapRecordPart2* part2 = reinterpret_cast<StackMapRecordPart2*>(location);
  fprintf(stderr, "  liveouts=%d\n", part2->num_live_outs);
  StackMapRecordLiveOut* live_out = &part2->first_live_out;
  for (int i = 0; i < part2->num_live_outs; i++) {
    fprintf(stderr, "    regno=%d, size=%d\n",
        live_out->dwarf_register_number,
        live_out->size_in_bytes);
    live_out++;
  }
}

}  // namespace dartino
