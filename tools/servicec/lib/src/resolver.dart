// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.resolver;

import 'parser.dart';
import 'dart:core' hide Type;

void resolve(Unit unit) {
  new Resolver().visit(unit);
}

class Resolver implements Visitor {
  visit(Node node) => node.accept(this);

  visitUnit(Unit node) {
    node.services.forEach(visit);
  }

  visitService(Service node) {
    node.methods.forEach(visit);
  }

  visitMethod(Method node) {
    node.arguments.forEach(visit);
    visit(node.returnType);
  }

  visitFormal(Formal node) {
    visit(node.type);
  }

  visitType(Type node) {
    String type = node.identifier;
    if (type != 'Int32') {
      throw new UnsupportedError("Cannot deal with type $type");
    }
  }
}
