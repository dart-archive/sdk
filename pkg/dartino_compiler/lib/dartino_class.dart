// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_class;

import 'package:persistent/persistent.dart' show
    PersistentMap;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    FieldElement;

import 'dartino_class_base.dart' show
    DartinoClassBase;

class DartinoClass extends DartinoClassBase {
  final int superclassId;
  final int superclassFields;
  final PersistentMap<int, int> methodTable;
  final List<FieldElement> fields;

  DartinoClass(
      int classId,
      String name,
      ClassElement element,
      this.superclassId,
      this.superclassFields,
      this.methodTable,
      List<FieldElement> fields)
      : fields = new List<FieldElement>.unmodifiable(fields),
        super(classId, name, element, fields.length);

  bool get hasSuperclassId => superclassId >= 0;

  String toString() => "DartinoClass($classId, '$name')";
}
