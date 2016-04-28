// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_field;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    Element,
    FieldElement,
    LocalElement;

class DartinoField {
  final Element element;

  final bool isBoxed;

  final bool isThis;

  DartinoField(FieldElement field)
      : element = field,
        isBoxed = false,
        isThis = false;

  DartinoField.boxed(LocalElement local)
      : element = local,
        isBoxed = true,
        isThis = false;

  DartinoField.boxedThis(ClassElement cls)
      : element = cls,
        isBoxed = true,
        isThis = true;

  bool operator==(other) {
    return other is DartinoField && element == other.element &&
        isBoxed == other.isBoxed && isThis == other.isThis;
  }

  int get hashCode => element.hashCode;

  String toString() {
    return "DartinoField($element"
        "${isBoxed ? ', isBoxed' : ''}"
        "${isThis ? ', isThis' : ''}"
        ")";
  }
}
