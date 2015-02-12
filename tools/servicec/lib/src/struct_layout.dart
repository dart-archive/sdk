// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.struct_builder;

import 'parser.dart';
import 'primitives.dart' as primitives;

import 'dart:collection';
import 'dart:core' hide Type;

const int POINTER_SIZE = 8;

int _roundUp(int n, int alignment) {
  return (n + alignment - 1) & ~(alignment - 1);
}

class StructLayout {
  final Map<String, StructSlot> _slots;
  final int size;
  StructLayout._(this._slots, this.size);

  factory StructLayout(Struct struct) {
    _StructBuilder builder = new _StructBuilder();

    struct.slots.forEach(builder.addSlot);
    if (struct.unions.isNotEmpty) {
      builder.addUnionSlots(struct.unions.single);
    }

    StructLayout result = new StructLayout._(
        builder.slots, _roundUp(builder.used, POINTER_SIZE));
    return result;
  }

  factory StructLayout.forArguments(List<Formal> arguments) {
    _StructBuilder builder = new _StructBuilder();
    arguments.forEach(builder.addSlot);
    StructLayout result = new StructLayout._(
        builder.slots, _roundUp(builder.used, POINTER_SIZE));
    return result;
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

class _StructBuilder {
  final Map<String, StructSlot> slots = new LinkedHashMap<String, StructSlot>();
  int used = 0;

  void addSlot(Formal slot) {
    Type type = slot.type;
    int size = computeSize(type);
    used = _roundUp(used, computeAlignment(type));
    _defineSlot(slot, size, null, -1);
    used += size;
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

    int tag = 1;
    used = _roundUp(used, unionAlignment);
    unionSlots.forEach((Formal slot) {
      Type type = slot.type;
      _defineSlot(slot, computeSize(type), union, tag++);
    });
    used += unionSize;
  }

  void _defineSlot(Formal slot, int size, Union union, int unionTag) {
    String name = slot.name;
    if (slots.containsKey(name)) {
      throw new UnsupportedError("Duplicate slot '$name' in struct.");
    }
    slots[name] = new StructSlot(slot, used, size, union, unionTag);
  }

  int computeSize(Type type) {
    if (type.isPrimitive) return primitives.size(type.primitiveType);
    if (type.isPointer || type.isList) return POINTER_SIZE;

    Struct struct = type.resolved;
    StructLayout layout = struct.layout;
    return _roundUp(layout.size, POINTER_SIZE);
  }

  int computeAlignment(Type type) {
    return (type.isPrimitive)
        ? primitives.size(type.primitiveType)
        : POINTER_SIZE;
  }
}
