// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.primitives;

enum PrimitiveType {
  INT16,
  INT32
}

int size(PrimitiveType type) {
  switch (type) {
    case PrimitiveType.INT16: return 2;
    case PrimitiveType.INT32: return 4;
  }
  return -1;
}

PrimitiveType lookup(String identifier) {
  Map<String, PrimitiveType> types = const {
    'Int16': PrimitiveType.INT16,
    'Int32': PrimitiveType.INT32
  };
  return types[identifier];
}
