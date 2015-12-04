// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PAIR_H_
#define SRC_VM_PAIR_H_

namespace fletch {

// Basically the same as a std::pair, but we don't want to rely on that
// being present on a given platform.
template <typename First, typename Second>
class Pair {
 public:
  Pair(First f, Second s) : first(f), second(s) {}

  First first;
  Second second;
};

}  // namespace fletch

#endif  // SRC_VM_PAIR_H_
