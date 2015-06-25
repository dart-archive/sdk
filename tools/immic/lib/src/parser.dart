// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library immic.parser;

import 'package:petitparser/petitparser.dart';
import 'grammar.dart';
import 'primitives.dart' as primitives;
import 'struct_layout.dart';

Unit parseUnit(String input) {
  Parser parser = new GrammarParser(new _ImmiParserDefinition());
  return parser.parse(input).value;
}

abstract class Visitor {
  visitUnit(Unit unit);
  visitImport(Import import);
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
  final List<Import> imports;
  final List<Struct> structs;
  Unit(this.imports, this.structs);
  accept(Visitor visitor) => visitor.visitUnit(this);
}

class Import extends Node {
  static const String packagePrefix = 'package:';
  String file;
  String prefix;
  String extension;
  Import(List<String> import) {
    int i = 0;
    int k = 0;
    for (int j = 0; j < import.length; ++j) {
      if (import[j] == ':') {
        assert(prefix == null);
        prefix = import.sublist(i, j).join();
        i = j + 1;
      } else if (import[j] == '.') {
        k = j + 1;
      }
    }
    assert(k > 0);
    file = import.sublist(i).join();
    extension = import.sublist(k).join();
  }

  accept(Visitor visitor) => visitor.visitImport(this);
}

class Struct extends Node {
  final String name;
  final List<Formal> slots;
  final List<Union> unions;
  final List<Method> methods;
  Struct(this.name, this.slots, this.unions, this.methods);

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
  bool get isPointer => false;
  bool get isList => false;
  bool get isString => false;
  bool get isNode => false;

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

  bool get isString => true;
}

class NodeType extends Type {
  final String identifier = "node";

  int get hashCode {
    int hash = identifier.hashCode;
    return hash;
  }

  bool operator==(Object other) {
    return other is NodeType;
  }

  bool get isNode => true;
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

  bool get isList => true;

  String get identifier => elementType.identifier;
}

// --------------------------------------------------------------

class _ImmiParserDefinition extends ImmiGrammarDefinition {
  final StringType string = new StringType();
  final NodeType node = new NodeType();
  unit() => super.unit()
          .map((each) => new Unit(
              each[0].toList(),
              each[1].where((e) => e is Struct).toList()));
  import() => super.import()
      .map((each) => new Import(each[1][1]));
  struct() => super.struct()
      .map((each) => new Struct(each[1],
          each[3].where((e) => e is Formal).toList(),
          each[3].where((e) => e is Union).toList(),
          each[3].where((e) => e is Method).toList()));
  method() => super.method()
      .map((each) => new Method(each[1], each[3], each[0]));
  simpleType() => super.simpleType()
      .map((each) => new SimpleType(each[0], each[1]));
  stringType() => super.stringType().map((each) => string);
  nodeType() => super.nodeType().map((each) => node);
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
