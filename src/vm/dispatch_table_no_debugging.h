// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_DISPATCH_TABLE_NO_DEBUGGING_H_
#define SRC_VM_DISPATCH_TABLE_NO_DEBUGGING_H_

#ifndef SRC_VM_DISPATCH_TABLE_H_
#error \
  "Do not import dispatch_table_no_debugging.h directly, "  \
  "import dispatch_table.h"
#endif

namespace dartino {

class Breakpoints;
class ProcessDebugInfo;
class ProgramDebugInfo;

class DispatchTable {
 public:
  DispatchTable() {}
  void ResetBreakpoints(
      const ProgramDebugInfo* program_info,
      const ProcessDebugInfo* process_info) {}
};

}  // namespace dartino

#endif  // SRC_VM_DISPATCH_TABLE_NO_DEBUGGING_H_
