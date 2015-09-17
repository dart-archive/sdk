// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.types;

import 'node.dart'
    show TypeNode;

// TODO(stanm): add these predicates as information on the type nodes.
bool isPrimitiveType(TypeNode type) {
  final List<String> primitiveTypes =
    ["void", "bool", "uint8", "uint16", "int8", "int16", "int32", "int64"];
  return primitiveTypes.contains(type.identifier.value);
}

bool isStringType(TypeNode type) {
  return type.identifier.value == "String";
}

bool isListType(TypeNode type) {
  return type.identifier.value == "List";
}
