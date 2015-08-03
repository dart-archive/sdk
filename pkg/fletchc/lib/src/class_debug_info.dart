// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.class_debug_info;

import 'package:compiler/src/elements/elements.dart';

import '../fletch_system.dart';

class ClassDebugInfo {
  final FletchClass klass;
  List<String> fieldNames;

  ClassDebugInfo(FletchClass klass)
      : this.klass = klass,
        fieldNames = _computeFieldNames(klass);

  static _computeFieldNames(FletchClass klass) {
    int localFields = klass.fields.length - klass.superclassFields;
    List fieldNames = new List(localFields);
    int index = 0;
    ClassElement classElement = klass.element.implementation;
    String className = classElement.name != null ? '${classElement.name}.' : '';
    classElement.forEachInstanceField((_, FieldElement field) {
      fieldNames[index++] = '$className${field.name}';
    });
    assert(index == localFields);
    return fieldNames;
  }
}
