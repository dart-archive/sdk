// Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library old_servicec.parser;

import 'primitives.dart' as primitives;
import 'struct_layout.dart';

abstract class Visitor {
  visitUnit(Unit node);
  visitService(Service service);
  visitStruct(Struct struct);
  visitUnion(Union union);
  visitMethod(Method method);
  visitFormal(Formal formal);
}

enum InputKind {
  PRIMITIVES,
  STRUCT
}

enum OutputKind {
  PRIMITIVE,
  STRUCT
}

abstract class Node {
  accept(Visitor visitor);
}

class Unit extends Node {
  final List<Service> services;
  final List<Struct> structs;
  Unit(this.services, this.structs);
  accept(Visitor visitor) => visitor.visitUnit(this);
}

class Service extends Node {
  final String name;
  final List<Method> methods;
  Service(this.name, this.methods);
  accept(Visitor visitor) => visitor.visitService(this);
}

class Struct extends Node {
  final String name;
  final List<Formal> slots;
  final List<Union> unions;
  Struct(this.name, this.slots, this.unions);

  // Set by the resolver.
  StructLayout layout;

  accept(Visitor visitor) => visitor.visitStruct(this);
}

class Union extends Node {
  final List<Formal> slots;
  final Formal tag;
  Union(this.slots) : tag = new Formal(new SimpleType("uint16", false), "tag");

  // Set by the resolver.
  Struct struct;

  accept(Visitor visitor) => visitor.visitUnion(this);
}

class Formal extends Node {
  final Type type;
  final String name;
  Formal(this.type, this.name);

  accept(Visitor visitor) => visitor.visitFormal(this);
}

class Method extends Node {
  final String name;
  final List<Formal> arguments;
  final Type returnType;
  Method(this.name, this.arguments, this.returnType);

  // Set by the resolver.
  OutputKind outputKind;

  InputKind inputKind;
  StructLayout inputPrimitiveStructLayout;

  accept(Visitor visitor) => visitor.visitMethod(this);
}

abstract class Type {
  bool get isPointer;
  bool get isList;
  bool get isString;

  bool get isPrimitive => primitiveType != null;

  bool get isVoid => primitiveType == primitives.PrimitiveType.VOID;
  bool get isBool => primitiveType == primitives.PrimitiveType.BOOL;

  // TODO(kasperl): Get rid of this.
  String get identifier;

  // Set by the resolver.
  Node resolved;
  primitives.PrimitiveType primitiveType;
}

class StringType extends Type {
  final String identifier = "String";

  int get hashCode {
    int hash = identifier.hashCode;
    return hash;
  }

  bool operator==(Object other) {
    return other is StringType;
  }

  bool get isPointer => false;
  bool get isList => false;
  bool get isString => true;
}

class SimpleType extends Type {
  final String identifier;
  final bool isPointer;
  SimpleType(this.identifier, this.isPointer);

  int get hashCode {
    int hash = identifier.hashCode;
    if (isPointer) {
      hash = hash ^ ((hash >> 16) | (hash << 16));
    }
    return hash;
  }

  bool operator==(Object other) {
    return other is SimpleType
        && identifier == other.identifier
        && isPointer == other.isPointer;
  }

  bool get isList => false;
  bool get isString => false;
}

class ListType extends Type {
  final SimpleType elementType;
  ListType(this.elementType);

  int get hashCode {
    int hash = elementType.hashCode;
    return ((hash >> 16) | (hash << 16));
  }

  bool operator==(Object other) {
    return other is ListType && elementType == other.elementType;
  }

  bool get isPointer => false;
  bool get isList => true;
  bool get isString => false;

  String get identifier => elementType.identifier;
}
