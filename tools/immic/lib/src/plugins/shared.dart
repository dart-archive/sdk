// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library immic.plugins.shared;

import 'package:strings/strings.dart' as strings;
import 'package:path/path.dart' show basename, basenameWithoutExtension;

import '../parser.dart';
export '../parser.dart';

abstract class CodeGenerationVisitor extends Visitor {
  final String path;
  final StringBuffer buffer = new StringBuffer();
  HashMap<String, List<Type>> methodSignatures = {};

  CodeGenerationVisitor(this.path);

  String get libraryFile => basenameWithoutExtension(path);
  String get libraryName => 'immi.$libraryFile';
  String get baseName => camelize(libraryName);
  String serviceName = 'ImmiServiceLayer';
  String serviceFile = 'immi_service';
  String serviceImplName = 'ImmiServiceImpl';
  String serviceImplFile = 'immi_service_impl';
  String serviceImplLib = 'immi_service_impl';
  String immiGenPkg = 'package:immi_gen';

  void write(String s) => buffer.write(s);
  void writeln([String s = '']) => buffer.writeln(s);
  void writeComma() => buffer.write(', ');

  String camelize(String name) {
    return strings.camelize(strings.underscore(name));
  }

  void forEachSlot(Struct node,
                   void sep(),
                   void f(Type slotType, String slotName)) {
    bool first = true;
    for (StructSlot slot in node.layout.slots) {
      if (!first && sep != null) sep();
      f(slot.slot.type, slot.slot.name);
      first = false;
    }
  }

  void forEachSlotAndMethod(Struct node,
                            void sep(),
                            void f(field, String name)) {
    bool first = true;
    for (StructSlot slot in node.layout.slots) {
      if (!first && sep != null) sep();
      f(slot.slot, slot.slot.name);
      first = false;
    }
    for (Method method in node.methods) {
      if (!first && sep != null) sep();
      f(method, method.name);
      first = false;
    }
  }

  visit(Node node) => node.accept(this);

  visitStruct(Struct node) {
    // TODO(kasper): Stop ignoring this.
  }

  visitUnion(Union node) {
    // TODO(kasper): Stop ignoring this.
  }

  visitImport(Import node) {
  }

  visitNodes(List<Node> nodes, String separatedBy(bool first)) {
    bool first = true;
    for (int i = 0; i < nodes.length; i++) {
      write(separatedBy(first));
      if (first) first = false;
      visit(nodes[i]);
    }
  }

  void collectMethodSignatures(Unit unit) {
    for (var node in unit.structs) {
      for (var method in node.methods) {
        assert(method.returnType.isVoid);
        String signature =
            method.arguments.map((formal) => formal.type.identifier);
        methodSignatures.putIfAbsent('$signature', () {
          return method.arguments.map((formal) => formal.type);
        });
      }
    }
  }

  String actionTypeSuffix(List<Type> types) {
    if (types.isEmpty) return 'Void';
    return types.map((Type type) => camelize(type.identifier)).join();
  }

  Iterable mapWithIndex(List list, f(int i, element)) {
    int i = 0;
    return list.map((e) => f(i++, e));
  }
}
