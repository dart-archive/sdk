// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_class_base;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement;

/// Common superclass for [DartinoClass] and [DartinoClassBuilder].
///
/// We maintain an invariant that all properties are final and cannot
/// change. If a property can change, it belongs in one (or both) of the
/// subclasses. Due to this invariant, it is safe to access these properties at
/// any point during compilation, whereas information such methods isn't known
/// until after tree-shaking is completed (tree-shaking is currently intermixed
/// with compilation).
abstract class DartinoClassBase {
  final int classId;
  final String name;
  final ClassElement element;
  final int fieldCount;

  const DartinoClassBase(
      this.classId,
      this.name,
      this.element,
      this.fieldCount);

  String toString() => "DartinoClassBase($classId, '$name')";
}
