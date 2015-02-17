// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.primitives;

enum PrimitiveType {
  VOID,
  BOOL,

  UINT8,
  UINT16,
  UINT32,
  UINT64,

  INT8,
  INT16,
  INT32,
  INT64,

  FLOAT32,
  FLOAT64,
}

int size(PrimitiveType type) {
  switch (type) {
    case PrimitiveType.VOID: return 0;

    case PrimitiveType.BOOL:
    case PrimitiveType.INT8:
    case PrimitiveType.UINT8: return 1;

    case PrimitiveType.INT16:
    case PrimitiveType.UINT16: return 2;

    case PrimitiveType.FLOAT32:
    case PrimitiveType.INT32:
    case PrimitiveType.UINT32: return 4;

    case PrimitiveType.FLOAT64:
    case PrimitiveType.INT64:
    case PrimitiveType.UINT64: return 8;
  }
  return -1;
}

PrimitiveType lookup(String identifier) {
  Map<String, PrimitiveType> types = const {
    'void'    : PrimitiveType.VOID,
    'bool'    : PrimitiveType.BOOL,

    'uint8'   : PrimitiveType.UINT8,
    'uint16'  : PrimitiveType.UINT16,
    'uint32'  : PrimitiveType.UINT32,
    'uint64'  : PrimitiveType.UINT64,

    'int8'    : PrimitiveType.INT8,
    'int16'   : PrimitiveType.INT16,
    'int32'   : PrimitiveType.INT32,
    'int64'   : PrimitiveType.INT64,

    'float32' : PrimitiveType.FLOAT32,
    'float64' : PrimitiveType.FLOAT64,
  };
  return types[identifier];
}
