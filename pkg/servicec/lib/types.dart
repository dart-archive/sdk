// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.types;

import 'node.dart'
    show TypeNode;

bool isPrimitiveType(TypeNode type) {
  final List<String> primitiveTypes =
    ["void", "bool", "uint8", "uint16", "int8", "int16", "int32", "int64"];
  return primitiveTypes.contains(type.identifier.value);
}
