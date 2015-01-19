// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_STRING_BUFFER_H_
#define SRC_COMPILER_STRING_BUFFER_H_

#include <cstdarg>

#include "src/compiler/list_builder.h"

namespace fletch {

class StringBuffer : public StackAllocated {
 public:
  explicit StringBuffer(Zone* zone);

  const char* ToString();
  void Print(const char* format, ...);
  void VPrint(const char *format, va_list arguments);

  void Clear();

 private:
  ListBuilder<char, 1024> builder_;
};

}  // namespace fletch

#endif  // SRC_COMPILER_STRING_BUFFER_H_
