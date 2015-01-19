// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.pretty_printer;

import 'parser.dart';
import 'dart:core' hide Type;

class PrettyPrinter implements Visitor {
  final StringBuffer buffer = new StringBuffer();

  visit(Node node) => node.accept(this);

  visitUnit(Unit node) {
    node.services.forEach(visit);
  }

  visitService(Service node) {
    buffer.writeln("service ${node.name} {");
    node.methods.forEach(visit);
    buffer.writeln("}");
  }

  visitMethod(Method node) {
    buffer.write("  ${node.name}(");
    visit(node.argumentType);
    buffer.write("): ");
    visit(node.returnType);
    buffer.writeln(";");
  }

  visitType(Type node) {
    buffer.write(node.identifier);
  }
}
