// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.pretty_printer;

import 'parser.dart';
import 'dart:core' hide Type;

class PrettyPrinter extends Visitor {
  final StringBuffer buffer = new StringBuffer();

  visit(Node node) => node.accept(this);

  visitUnit(Unit node) {
    node.services.forEach(visit);
    node.structs.forEach(visit);
  }

  visitService(Service node) {
    buffer.writeln("service ${node.name} {");
    node.methods.forEach(visit);
    buffer.writeln("}");
  }

  visitMethod(Method node) {
    buffer.write("  ");
    visit(node.returnType);
    buffer.write(" ${node.name}(");
    bool first = true;
    node.arguments.forEach((Formal formal) {
      if (!first) buffer.write(", ");
      first = false;
      visit(formal);
    });
    buffer.writeln(");");
  }

  visitStruct(Struct node) {
    buffer.writeln("struct ${node.name} {");
    for (Formal slot in node.slots) {
      buffer.write("  ");
      visit(slot);
      buffer.writeln(";");
    }
    buffer.writeln("}");
  }

  visitFormal(Formal node) {
    visit(node.type);
    buffer.write(" ${node.name}");
  }

  visitType(Type node) {
    if (node.isList) buffer.write("List<");
    buffer.write(node.identifier);
    if (node.isList) buffer.write(">");
  }
}
