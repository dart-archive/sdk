// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_class;

import 'package:persistent/persistent.dart' show
    PersistentMap;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement;

import 'dartino_class_base.dart' show
    DartinoClassBase;

import 'src/element_utils.dart' show
    computeFields;

import 'dartino_field.dart' show
    DartinoField;

class DartinoClass extends DartinoClassBase {
  final int superclassId;
  final int superclassFields;
  final PersistentMap<int, int> methodTable;
  final List<DartinoField> mixedInFields;

  DartinoClass(
      int classId,
      String name,
      ClassElement element,
      this.superclassId,
      int superclassFields,
      this.methodTable,
      List<DartinoField> mixedInFields)
      : mixedInFields = new List<DartinoField>.unmodifiable(mixedInFields),
        superclassFields = superclassFields,
        super(classId, name, element, mixedInFields.length + superclassFields);

  factory DartinoClass.validated(
      int classId,
      String name,
      ClassElement element,
      int superclassId,
      int superclassFields,
      PersistentMap<int, int> methodTable,
      List<DartinoField> mixedInFields) {
    return new DartinoClass(
        classId, name, element, superclassId, superclassFields, methodTable,
        mixedInFields)
        ..validate();
  }

  void validate() {
    assert(element == null || fieldCount == computeFields(element).length);
    assert(fieldCount - mixedInFields.length == superclassFields);
  }

  String toString() => "DartinoClass($classId, '$name')";
}
