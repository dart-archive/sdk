// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.struct_builder;

import 'parser.dart';
import 'dart:collection';
import 'dart:core' hide Type;

final Map<String, StructLayout> _cache = <String, StructLayout>{};

int _roundUp(int n, int alignment) {
  return (n + alignment - 1) & ~(alignment - 1);
}

class StructLayout {
  final Map<String, StructSlot> _slots;
  final int size;
  StructLayout._(this._slots, this.size);

  factory StructLayout(Struct struct) {
    String name = struct.name;
    if (_cache.containsKey(name)) return _cache[name];
    _StructBuilder builder = new _StructBuilder();
    struct.slots.forEach(builder.addSlot);
    StructLayout result = new StructLayout._(
        builder.slots, _roundUp(builder.used, 8));
    _cache[name] = result;
    return result;
  }

  Iterable<StructSlot> get slots => _slots.values;
  StructSlot operator[](Formal slot) => _slots[slot.name];
}

class StructSlot {
  final Formal slot;
  final int offset;
  final int size;
  StructSlot(this.slot, this.offset, this.size);
}

class _StructBuilder {
  final Map<String, StructSlot> slots = new LinkedHashMap<String, StructSlot>();
  int used = 0;

  void addSlot(Formal formal) {
    Type type = formal.type;
    int size = computeSize(type);
    used = _roundUp(used, computeAlignment(type));
    slots[formal.name] = new StructSlot(formal, used, size);
    used += size;
  }

  int computeSize(Type type) {
    if (type.identifier == 'Int32') return 4;
    else return 8;
  }

  int computeAlignment(Type type) {
    return computeSize(type);
  }
}
