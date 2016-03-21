// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.class_debug_info;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement;

import '../dartino_class.dart' show
    DartinoClass;

import '../dartino_field.dart' show
    DartinoField;

class ClassDebugInfo {
  final DartinoClass klass;
  List<String> fieldNames;

  ClassDebugInfo(DartinoClass klass)
      : this.klass = klass,
        fieldNames = _computeFieldNames(klass);

  static List<String> _computeFieldNames(DartinoClass klass) {
    String className;
    if (klass.element != null) {
      className = klass.element.name;
    }
    if (className != null) {
      className = "$className.";
    }
    int index = 0;
    return new List<String>.from(klass.mixedInFields.map((DartinoField field) {
      String elementName = field.element.name;
      String fieldName;
      if (field.isThis) {
        fieldName = "<boxed this $elementName>";
      } else if (field.isBoxed) {
        fieldName = "<boxed local value $elementName>";
      } else {
        fieldName = "$className$elementName";
      }
      return fieldName;
    }));
  }
}
