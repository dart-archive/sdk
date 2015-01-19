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
  visitMethod(Method method);
  visitType(Type type);
}

abstract class Node {
  accept(Visitor visitor);
}

class Unit extends Node {
  final List<Service> services;
  Unit(this.services);
  accept(Visitor visitor) => visitor.visitUnit(this);
}

class Service extends Node {
  final String name;
  final List<Method> methods;
  Service(this.name, this.methods);
  accept(Visitor visitor) => visitor.visitService(this);
}

class Method extends Node {
  final String name;
  final Type argumentType;
  final Type returnType;
  Method(this.name, this.argumentType, this.returnType);
  accept(Visitor visitor) => visitor.visitMethod(this);
}

class Type extends Node {
  final String identifier;
  Type(this.identifier);
  accept(Visitor visitor) => visitor.visitType(this);
}


// --------------------------------------------------------------

class _ServiceParserDefinition extends ServiceGrammarDefinition {
  unit() => super.unit()
      .map((each) => new Unit(each));
  service() => super.service()
      .map((each) => new Service(each[1], each[3]));
  method() => super.method()
      .map((each) => new Method(each[0], each[2], each[5]));
  type() => super.type()
      .map((each) => new Type(each));
  identifier() => super.identifier()
      .flatten();
}