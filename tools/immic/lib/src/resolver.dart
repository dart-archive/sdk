// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library immic.resolver;

import 'dart:core' hide Type;

import 'parser.dart';
import 'primitives.dart' as primitives;
import 'struct_layout.dart';

void resolve(Unit unit) {
  Definer definer = new Definer();
  definer.visit(unit);
  Resolver resolver = new Resolver(definer.definitions);
  resolver.visit(unit);
  resolver.resolveAllStructs();
}

class Definer extends ResolutionVisitor {
  final Map<String, Node> definitions = <String, Node>{};

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
  final Map<Struct, Set<Struct>> dependencyMap = <Struct, Set<Struct>>{};
  Resolver(this.definitions);

  void resolveAllStructs() {
    for (Struct struct in dependencyMap.keys) {
      resolveStruct(struct, new Set<Struct>());
    }
  }

  void resolveStruct(Struct struct, Set<Struct> visited) {
    if (visited.contains(struct)) {
      if (struct.layout != null) return;
      throw new UnsupportedError("Cyclic struct graph at ${struct.name}.");
    }

    visited.add(struct);
    Set<Struct> dependencies = dependencyMap[struct];
    dependencies.forEach((Struct each) { resolveStruct(each, visited); });
    struct.layout = new StructLayout(struct);
  }

  visitMethod(Method node) {
    super.visitMethod(node);

    if (node.returnType.isPrimitive) {
      node.outputKind = OutputKind.PRIMITIVE;
    } else {
      node.outputKind = OutputKind.STRUCT;
      if (!node.returnType.isPointer) {
        throw new UnsupportedError("Cannot return structs by value.");
      }
    }

    List<Formal> arguments = node.arguments;
    if (arguments.any((e) => !e.type.isPrimitive && !e.type.isPointer)) {
      throw new UnsupportedError("Cannot pass structs by value as arguments.");
    }

    if (arguments.any((e) => e.type.isVoid)) {
      throw new UnsupportedError("Cannot pass void as argument.");
    }

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
    super.visitStruct(node);

    Iterable<Struct> computeDependencies(Iterable<Formal> slots) {
      return slots
          .where((Formal slot) => !slot.type.isPointer)
          .where((Formal slot) => !slot.type.isPrimitive &&
                                  !slot.type.isList &&
                                  !slot.type.isString)
          .map((Formal slot) => definitions[slot.type.identifier]);
    }

    Set<Struct> dependencies = dependencyMap[node] =
        computeDependencies(node.slots).toSet();

    if (node.slots.any((Formal slot) => slot.type.isVoid)) {
      throw new UnsupportedError("Cannot have void slots in struct");
    }

    if (node.unions.isNotEmpty) {
      if (node.unions.length != 1) {
        throw new UnsupportedError("Structs can have at most one union");
      }
      Union union = node.unions.single;
      union.struct = node;
      node.slots.add(union.tag);
      dependencies.addAll(computeDependencies(union.slots));
    }
  }

  void resolveType(Type node) {
    if (node.isString) return;
    primitives.PrimitiveType primitiveType = primitives.lookup(node.identifier);
    if (primitiveType != null) {
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

  visitFormal(Formal node) {
    super.visitFormal(node);
    if (node.type.isList) {
      ListType listType = node.type;
      if (listType.elementType.isPointer) {
        throw new UnsupportedError("Cannot handle lists of pointers");
      }
    } else if (node.type.isPointer) {
      if (node.type.isPrimitive) {
        throw new UnsupportedError("Cannot handle pointers to primitive types");
      }
    }
  }
}

class ResolutionVisitor extends Visitor {
  visit(Node node) => node.accept(this);

  visitUnit(Unit node) {
    node.structs.forEach(visit);
  }

  visitStruct(Struct node) {
    node.slots.forEach(visit);
    node.unions.forEach(visit);
  }

  visitUnion(Union node) {
    visit(node.tag);
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
