// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_DISPATCH_TABLE_H_
#define SRC_VM_DISPATCH_TABLE_H_

#ifndef DARTINO_ENABLE_LIVE_CODING
#include "src/vm/dispatch_table_no_live_coding.h"
#else  // DARTINO_ENABLE_LIVE_CODING

namespace dartino {

class Breakpoints;
class ProcessDebugInfo;
class ProgramDebugInfo;

class DispatchTable {
 public:
  DispatchTable() : state_(kClean) {}

  void ResetBreakpoints(
      const ProgramDebugInfo* program_info,
      const ProcessDebugInfo* process_info);

 private:
  enum State {
    kClean,
    kDirty,
    kStepping
  };

  void SetBreakpoints(const Breakpoints* breakpoints);
  void SetStepping();
  void ClearAllBreakpoints();

  State state_;
};

}  // namespace dartino

#endif  // DARTINO_ENABLE_LIVE_CODING
#endif  // SRC_VM_DISPATCH_TABLE_H_
