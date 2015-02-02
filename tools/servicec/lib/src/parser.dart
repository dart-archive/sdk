// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.parser;

import 'package:petitparser/petitparser.dart';
import 'grammar.dart';

Unit parseUnit(String input) {
  Parser parser = new GrammarParser(new _ServiceParserDefinition());
  return parser.parse(input).value;
}

abstract class Visitor {
  visitUnit(Unit node);
  visitService(Service service);
  visitStruct(Struct struct);
  visitMethod(Method method);
  visitFormal(Formal formal);
  visitType(Type type);
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
  Struct(this.name, this.slots);
  accept(Visitor visitor) => visitor.visitStruct(this);
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
  accept(Visitor visitor) => visitor.visitMethod(this);
}

class Type extends Node {
  final String identifier;
  final bool isList;
  Node resolved;
  Type(this.identifier, this.isList);
  accept(Visitor visitor) => visitor.visitType(this);
}

// --------------------------------------------------------------

class _ServiceParserDefinition extends ServiceGrammarDefinition {
  unit() => super.unit()
      .map((each) => new Unit(each.where((e) => e is Service).toList(),
                              each.where((e) => e is Struct).toList()));
  service() => super.service()
      .map((each) => new Service(each[1], each[3]));
  struct() => super.struct()
      .map((each) => new Struct(each[1], each[3]));
  method() => super.method()
      .map((each) => new Method(each[1], each[3], each[0]));
  simpleType() => super.simpleType()
      .map((each) => new Type(each, false));
  listType() => super.listType()
      .map((each) => new Type(each[2], true));
  slot() => super.slot()
     .map((each) => each[0]);
  formal() => super.formal()
      .map((each) => new Formal(each[0], each[1]));
  identifier() => super.identifier()
      .flatten().map((each) => each.trim());
}
