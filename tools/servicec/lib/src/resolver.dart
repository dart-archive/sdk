// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.resolver;

import 'dart:core' hide Type;

import 'parser.dart';
import 'primitives.dart' as primitives;
import 'struct_layout.dart';

void resolve(Unit unit) {
  Definer definer = new Definer();
  definer.visit(unit);
  new Resolver(definer.definitions).visit(unit);
}

class Definer extends ResolutionVisitor {
  final Map<String, Node> definitions = <String, Node>{};

  visitService(Service node) {
    define(node.name, node);
    super.visitService(node);
  }

  visitStruct(Struct node) {
    define(node.name, node);
    super.visitStruct(node);
  }

  void define(String name, Node node) {
    if (definitions.containsKey(name)) {
      throw "Multiple definitions for $name";
    }
    definitions[name] = node;
  }
}

class Resolver extends ResolutionVisitor {
  final Map<String, Node> definitions;
  Resolver(this.definitions);

  visitMethod(Method node) {
    super.visitMethod(node);

    if (node.returnType.isPrimitive) {
      node.outputKind = OutputKind.PRIMITIVE;
    } else {
      node.outputKind = OutputKind.STRUCT;
    }

    List<Formal> arguments = node.arguments;
    if (arguments.length == 1) {
      node.inputKind = arguments[0].type.isPrimitive
          ? InputKind.PRIMITIVES
          : InputKind.STRUCT;
    } else if (arguments.any((Formal each) => !each.type.isPrimitive)) {
      throw new UnsupportedError("Methods accepting multiple arguments can "
                                 "only take primitive values.");
    } else {
      node.inputKind = InputKind.PRIMITIVES;
    }

    if (node.inputKind == InputKind.PRIMITIVES) {
      StructLayout layout = new StructLayout.forArguments(arguments);
      node.inputPrimitiveStructLayout = layout;
    }
  }

  visitStruct(Struct node) {
    if (node.unions.isNotEmpty) {
      if (node.unions.length != 1) {
        throw new UnsupportedError("Structs can have at most one union");
      }
      Union union = node.unions.single;
      union.struct = node;
      node.slots.add(union.tag);
    }
    super.visitStruct(node);
    node.layout = new StructLayout(node);
  }

  void resolveType(Type node) {
    primitives.PrimitiveType primitiveType = primitives.lookup(node.identifier);
    if (primitiveType != null) {
      if (node.isList) {
        throw new UnsupportedError("Cannot deal with primtive lists yet");
      }
      node.primitiveType = primitiveType;
    } else {
      String type = node.identifier;
      if (definitions.containsKey(type)) {
        node.resolved = definitions[type];
      } else {
        throw new UnsupportedError("Cannot deal with type $type");
      }
    }
  }
}

class ResolutionVisitor extends Visitor {
  visit(Node node) => node.accept(this);

  visitUnit(Unit node) {
    node.services.forEach(visit);
    node.structs.forEach(visit);
  }

  visitService(Service node) {
    node.methods.forEach(visit);
  }

  visitStruct(Struct node) {
    node.slots.forEach(visit);
    node.unions.forEach(visit);
  }

  visitUnion(Union node) {
    node.slots.forEach(visit);
  }

  visitMethod(Method node) {
    node.arguments.forEach(visit);
    resolveType(node.returnType);
  }

  visitFormal(Formal node) {
    resolveType(node.type);
  }

  void resolveType(Type node) {
  }
}
