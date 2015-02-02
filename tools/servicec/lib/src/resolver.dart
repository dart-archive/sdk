// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.resolver;

import 'parser.dart';
import 'dart:core' hide Type;

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

  visitType(Type node) {
    String type = node.identifier;
    if (definitions.containsKey(type)) {
      node.resolved = definitions[type];
    } else if (type != 'Int32') {
      throw new UnsupportedError("Cannot deal with type $type");
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
  }

  visitMethod(Method node) {
    node.arguments.forEach(visit);
    visit(node.returnType);
  }

  visitFormal(Formal node) {
    visit(node.type);
  }

  visitType(Type node) {
  }
}
