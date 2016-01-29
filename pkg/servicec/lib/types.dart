// Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.types;

enum TypeKind {
  VOID,
  BOOL,

  UINT8,
  UINT16,

  INT8,
  INT16,
  INT32,
  INT64,

  FLOAT32,
  FLOAT64,

  STRING,
  LIST,

  STRUCT,
  POINTER
}

final List<TypeKind> primitiveTypes = [
  TypeKind.VOID,
  TypeKind.BOOL,

  TypeKind.UINT8,
  TypeKind.UINT16,

  TypeKind.INT8,
  TypeKind.INT16,
  TypeKind.INT32,
  TypeKind.INT64,

  TypeKind.FLOAT32,
  TypeKind.FLOAT64
];

TypeKind lookupType(String identifier) {
  Map<String, TypeKind> types = const {
    'void'    : TypeKind.VOID,
    'bool'    : TypeKind.BOOL,

    'uint8'   : TypeKind.UINT8,
    'uint16'  : TypeKind.UINT16,

    'int8'    : TypeKind.INT8,
    'int16'   : TypeKind.INT16,
    'int32'   : TypeKind.INT32,
    'int64'   : TypeKind.INT64,

    'float32' : TypeKind.FLOAT32,
    'float64' : TypeKind.FLOAT64,

    'String'  : TypeKind.STRING,
    'List'    : TypeKind.LIST,
  };
  return types[identifier];
}
