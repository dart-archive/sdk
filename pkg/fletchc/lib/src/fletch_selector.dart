// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_selector;

enum SelectorKind {
  Method,
  Getter,
  Setter,
}

class FletchSelector {
  static const MAX_ARITY = (1 << 8) - 1;
  static const MAX_UNIQUE_SELECTORS = (1 << 22) - 1;
  static const ID_SHIFT = 10;

  // Encode a fletch selector. The result is a 32bit integer with the following
  // layout (lower to higher):
  //  - 8 bit arity
  //  - 2 bit kind
  //  - 22 bit id
  static int encode(int id, SelectorKind kind, int arity) {
    if (arity > MAX_ARITY) throw "Only arity up to 255 is supported";
    if (id > MAX_UNIQUE_SELECTORS) {
      throw "Only ${MAX_UNIQUE_SELECTORS + 1} unique identifiers is supported";
    }
    return arity | (kind.index << 8) | (id << ID_SHIFT);
  }

  static int encodeMethod(int id, int arity) {
    return encode(id, SelectorKind.Method, arity);
  }

  static int encodeGetter(int id) => encode(id, SelectorKind.Getter, 0);

  static int encodeSetter(int id) => encode(id, SelectorKind.Setter, 1);

  static int decodeId(int selector) => selector >> ID_SHIFT;
}
