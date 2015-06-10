// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_system;

import '../bytecodes.dart';

import '../commands.dart';

// TODO(ajohnsen): Move to separate file.
class FletchConstant {
  final int id;
  final MapId mapId;
  const FletchConstant(this.id, this.mapId);

  String toString() => "FletchConstant($id, $mapId)";
}

// TODO(ajohnsen): Move to separate file.
class FletchClass {
  final int classId;
  final String name;
  final int superclassId;

  const FletchClass(this.classId, this.name, this.superclassId);

  bool get hasSuperclassId => superclassId >= 0;

  String toString() => "FletchClass($classId, '$name')";
}

// TODO(ajohnsen): Move to separate file.
class FletchFunction {
  final int methodId;
  final String name;
  final List<Bytecode> bytecodes;
  final List<FletchConstant> constants;
  final int memberOf;

  const FletchFunction(
      this.methodId,
      this.name,
      this.bytecodes,
      this.constants,
      this.memberOf);

  bool get hasMemberOf => memberOf >= 0;

  String toString() {
    StringBuffer buffer = new StringBuffer();
    buffer.write("FletchFunction($methodId, '$name'");
    if (hasMemberOf) {
      buffer.write(", memberOf=$memberOf");
    }
    buffer.write(")");
    return buffer.toString();
  }
}

class FletchSystem {
}
