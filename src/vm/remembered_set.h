// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_REMEMBERED_SET_H_
#define SRC_VM_REMEMBERED_SET_H_

namespace dartino {

// TODO(erikcorry): Implement remembered set.
class RememberedSet {
 public:
  inline void Insert(HeapObject* h) {}
};

}  // namespace dartino

#endif  // SRC_VM_REMEMBERED_SET_H_
