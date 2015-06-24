// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_system;

import 'package:compiler/src/elements/elements.dart' show
    Element;

import 'bytecodes.dart';
import 'commands.dart';

enum FletchFunctionKind {
  NORMAL,
  LAZY_FIELD_INITIALIZER,
  INITIALIZER_LIST,
  PARAMETER_STUB,
  ACCESSOR
}

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
  final FletchFunctionKind kind;
  // TODO(ajohnsen): Remove name?
  final String name;
  final Element element;
  final List<Bytecode> bytecodes;
  final List<FletchConstant> constants;
  final int memberOf;

  const FletchFunction(
      this.methodId,
      this.kind,
      this.name,
      this.element,
      this.bytecodes,
      this.constants,
      this.memberOf);

  bool get isLazyFieldInitializer {
    return kind == FletchFunctionKind.LAZY_FIELD_INITIALIZER;
  }

  bool get isInitializerList {
    return kind == FletchFunctionKind.INITIALIZER_LIST;
  }

  bool get isAccessor {
    return kind == FletchFunctionKind.ACCESSOR;
  }

  bool get isParameterStub {
    return kind == FletchFunctionKind.PARAMETER_STUB;
  }

  bool get hasMemberOf => memberOf >= 0;

  bool get isInternal => element == null;

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
  final List<FletchFunction> functions;
  final List<FletchClass> classes;

  const FletchSystem(this.functions, this.classes);
}

class FletchDelta {
  final FletchSystem system;
  final FletchSystem predecessorSystem;
  final List<Command> commands;

  const FletchDelta(this.system, this.predecessorSystem, this.commands);
}
