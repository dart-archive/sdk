// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.parser;

import 'package:petitparser/petitparser.dart';
import 'grammar.dart';
import 'primitives.dart' as primitives;
import 'struct_layout.dart';

Unit parseUnit(String input) {
  Parser parser = new GrammarParser(new _ServiceParserDefinition());
  return parser.parse(input).value;
}

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

  bool get isPrimitive => primitiveType != null;

  bool get isVoid => primitiveType == primitives.PrimitiveType.VOID;
  bool get isBool => primitiveType == primitives.PrimitiveType.BOOL;

  // TODO(kasperl): Get rid of this.
  String get identifier;

  // Set by the resolver.
  Node resolved;
  primitives.PrimitiveType primitiveType;
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
    if (other is! Type || other.isList) return false;
    return identifier == other.identifier && isPointer == other.isPointer;
  }

  bool get isList => false;
}

class ListType extends Type {
  final SimpleType elementType;
  ListType(this.elementType);

  int get hashCode {
    int hash = elementType.hashCode;
    return ((hash >> 16) | (hash << 16));
  }

  bool operator==(Object other) {
    if (other is! Type || !other.isList) return false;
    return elementType == other.elementType;
  }

  bool get isPointer => false;
  bool get isList => true;

  String get identifier => elementType.identifier;
}

// --------------------------------------------------------------

class _ServiceParserDefinition extends ServiceGrammarDefinition {
  unit() => super.unit()
      .map((each) => new Unit(each.where((e) => e is Service).toList(),
                              each.where((e) => e is Struct).toList()));
  service() => super.service()
      .map((each) => new Service(each[1], each[3]));
  struct() => super.struct()
      .map((each) => new Struct(each[1],
          each[3].where((e) => e is Formal).toList(),
          each[3].where((e) => e is Union).toList()));
  method() => super.method()
      .map((each) => new Method(each[1], each[3], each[0]));
  simpleType() => super.simpleType()
      .map((each) => new SimpleType(each[0], each[1]));
  listType() => super.listType()
      .map((each) => new ListType(each[2]));
  union() => super.union()
      .map((each) => new Union(each[2]));
  slot() => super.slot()
     .map((each) => each[0]);
  formal() => super.formal()
      .map((each) => new Formal(each[0], each[1]));
  identifier() => super.identifier()
      .flatten().map((each) => each.trim());
}
