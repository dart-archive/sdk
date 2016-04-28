// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.element_utils;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    FieldElement;

/// Returns the fields of [cls].
///
/// If [asMixin] is `false`, the fields returned are those declared in [cls]
/// and its superclasses. Otherwise, only fields declared in [cls] are
/// returned.
List<FieldElement> computeFields(ClassElement cls, {bool asMixin: false}) {
  cls = cls.implementation;
  List<FieldElement> fields;
  if (!asMixin && cls.superclass != null) {
    fields = computeFields(cls.superclass, asMixin: asMixin);
  } else {
    fields = <FieldElement>[];
  }
  cls.forEachInstanceField((ClassElement enclosing, FieldElement field) {
    fields.add(field);
  });
  return fields;
}
