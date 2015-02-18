// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.struct_builder;

import 'parser.dart';
import 'primitives.dart' as primitives;

import 'dart:collection';
import 'dart:core' hide Type;
import 'dart:math' show max;

const int POINTER_SIZE = 8;

int _roundUp(int n, int alignment) {
  return (n + alignment - 1) & ~(alignment - 1);
}

class StructLayout {
  final Map<String, StructSlot> _slots;
  final int size;
  final List<_StructHole> _holes;
  StructLayout._(this._slots, this.size, this._holes);

  factory StructLayout(Struct struct) {
    _StructBuilder builder = new _StructBuilder();

    struct.slots.forEach(builder.addSlot);
    if (struct.unions.isNotEmpty) {
      builder.addUnionSlots(struct.unions.single);
    }
    return builder.finalize(0);
  }

  factory StructLayout.forArguments(List<Formal> arguments) {
    _StructBuilder builder = new _StructBuilder();
    arguments.forEach(builder.addSlot);
    return builder.finalize(POINTER_SIZE);
  }

  Iterable<StructSlot> get slots => _slots.values;
  StructSlot operator[](Formal slot) => _slots[slot.name];
}

class StructSlot {
  final Formal slot;
  final int offset;
  final int size;

  final Union union;
  final int unionTag;

  StructSlot(this.slot, this.offset, this.size, this.union, this.unionTag);

  bool get isUnionSlot => union != null;
}

class _StructRegion {
  final int size;
  final int alignment;

  final bool isUnion;
  final owner;

  _StructRegion.forSlot(this.size, this.alignment, Formal this.owner)
      : isUnion = false;

  _StructRegion.forUnion(this.size, this.alignment, Union this.owner)
      : isUnion = true;

  Formal get slot {
    assert(!isUnion);
    return owner;
  }

  Union get union {
    assert(isUnion);
    return owner;
  }
}

class _StructHole extends LinkedListEntry {
  int begin;
  int end;
  _StructHole(this.begin, this.end);

  int get size => end - begin;
}

class _StructBuilder {
  final List<_StructRegion> regions = <_StructRegion>[];
  final Map<String, StructSlot> slots = new LinkedHashMap<String, StructSlot>();
  final LinkedList<_StructHole> holes = new LinkedList<_StructHole>();
  int used = 0;

  StructLayout finalize(int minimum) {
    // Sort the regions by size, so we get the largest regions first.
    regions.sort((x, y) => y.size - x.size);

    for (_StructRegion region in regions) {
      int offset = allocate(region.size, region.alignment);
      if (region.isUnion) {
        Union union = region.union;
        int tag = 1;
        union.slots.forEach((Formal slot) {
          _defineSlot(slot, offset, computeSize(slot.type), union, tag++);
        });
      } else {
        _defineSlot(region.slot, offset, region.size, null, -1);
      }
    }

    int size = max(allocate(0, POINTER_SIZE), minimum);
    return new StructLayout._(slots, size, holes.toList());
  }

  int allocate(int size, int alignment) {
    int result = _allocateFromHole(size, alignment);
    if (result >= 0) return result;

    result = _roundUp(used, alignment);
    int padding = result - used;
    if (padding > 0) {
      holes.add(new _StructHole(result - padding, result));
    }
    used = result + size;
    return result;
  }

  int _allocateFromHole(int size, int alignment) {
    if (size == 0) return -1;
    for (_StructHole hole in holes) {
      int offset = _roundUp(hole.begin, alignment);
      if (offset + size <= hole.end) {
        _splitHole(hole, offset, size);
        return offset;
      }
    }
    return -1;
  }

  void _splitHole(_StructHole hole, int offset, int size) {
     int end = hole.end;
     if (offset + size < end) {
       // Insert hole after.
       hole.insertAfter(new _StructHole(offset + size, end));
     }
     // Shrink the hole before.
     hole.end = offset;
     if (hole.size == 0) holes.remove(hole);
   }

  void addSlot(Formal slot) {
    Type type = slot.type;
    int size = computeSize(type);
    int alignment = computeAlignment(type);
    regions.add(new _StructRegion.forSlot(size, alignment, slot));
  }

  void addUnionSlots(Union union) {
    List<Formal> unionSlots = union.slots;
    if (unionSlots.isEmpty) return;

    int unionSize = 0;
    int unionAlignment = 0;
    unionSlots.forEach((Formal slot) {
      Type type = slot.type;
      int size = computeSize(type);
      if (size > unionSize) unionSize = size;
      int alignment = computeAlignment(type);
      if (alignment > unionAlignment) unionAlignment = alignment;
    });

    regions.add(new _StructRegion.forUnion(unionSize, unionAlignment, union));
  }

  void _defineSlot(Formal slot, int offset, int size, Union union, int tag) {
    String name = slot.name;
    if (slots.containsKey(name)) {
      throw new UnsupportedError("Duplicate slot '$name' in struct.");
    }
    slots[name] = new StructSlot(slot, offset, size, union, tag);
  }

  int computeSize(Type type) {
    if (type.isPointer || type.isList) return POINTER_SIZE;
    if (type.isPrimitive) return primitives.size(type.primitiveType);

    Struct struct = type.resolved;
    StructLayout layout = struct.layout;
    for (_StructHole hole in layout._holes) {
      holes.add(new _StructHole(hole.begin, hole.end));
    }
    return _roundUp(layout.size, POINTER_SIZE);
  }

  int computeAlignment(Type type) {
    return (type.isPrimitive && !type.isList)
        ? primitives.size(type.primitiveType)
        : POINTER_SIZE;
  }
}
