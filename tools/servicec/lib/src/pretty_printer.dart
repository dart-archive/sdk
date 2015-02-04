// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.pretty_printer;

import 'parser.dart';
import 'struct_layout.dart';

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
    writeType(node.returnType);
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
    StructLayout layout = node.layout;
    buffer.writeln("struct ${node.name} {  // size = ${layout.size} bytes");
    for (Formal slot in node.slots) {
      buffer.write("  ");
      visit(slot);
      buffer.writeln(";  // offset = ${layout[slot].offset}");
    }
    buffer.writeln("}");
  }

  visitFormal(Formal node) {
    writeType(node.type);
    buffer.write(" ${node.name}");
  }

  void writeType(Type node) {
    if (node.isList) buffer.write("List<");
    buffer.write(node.identifier);
    if (node.isList) buffer.write(">");
  }
}
