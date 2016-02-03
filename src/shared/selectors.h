// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_SELECTORS_H_
#define SRC_SHARED_SELECTORS_H_

#include "src/shared/utils.h"

namespace dartino {

class Selector {
 public:
  enum Kind { METHOD, GETTER, SETTER };

  static uword Encode(int id, Kind kind, int arity) {
    return IdField::encode(id) | KindField::encode(kind) |
           ArityField::encode(arity);
  }

  static uword EncodeGetter(int id) { return Encode(id, GETTER, 0); }

  static uword EncodeSetter(int id) { return Encode(id, SETTER, 1); }

  static uword EncodeMethod(int id, int arity) {
    return Encode(id, METHOD, arity);
  }

  class ArityField : public BitField<int, 0, 8> {};
  class KindField : public BitField<Kind, 8, 2> {};
  class IdField : public BitField<int, 10, 22> {};
};

}  // namespace dartino

#endif  // SRC_SHARED_SELECTORS_H_
