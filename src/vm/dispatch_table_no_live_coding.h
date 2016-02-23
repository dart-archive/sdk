// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_DISPATCH_TABLE_NO_LIVE_CODING_H_
#define SRC_VM_DISPATCH_TABLE_NO_LIVE_CODING_H_

#ifndef SRC_VM_DISPATCH_TABLE_H_
#error \
  "Do not import dispatch_table_no_live_coding.h directly, "  \
  "import dispatch_table.h"
#endif

namespace dartino {

class Breakpoints;
class DebugInfo;

class DispatchTable {
 public:
  DispatchTable() {}
  void ResetBreakpoints(
      const DebugInfo* debug_info,
      const Breakpoints* program_breakpoints) {}
};

}  // namespace dartino

#endif  // SRC_VM_DISPATCH_TABLE_NO_LIVE_CODING_H_
