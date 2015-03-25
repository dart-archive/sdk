// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_DEBUG_INFO_H_
#define SRC_VM_DEBUG_INFO_H_

#include "src/vm/list.h"

namespace fletch {

class Function;
class PointerVisitor;

class Breakpoint {
 public:
  Breakpoint(Function* function, int bytecode_index, bool is_one_shot);

  Function* function() const { return function_; }
  int bytecode_index() const { return bytecode_index_; }
  bool is_one_shot() const { return is_one_shot_; }

  // GC support for program GCs.
  void VisitProgramPointers(PointerVisitor* visitor);

 private:
  Function* function_;
  int bytecode_index_;
  bool is_one_shot_;
};

class DebugInfo {
 public:
  DebugInfo();

  bool ShouldBreak(Function* process, int bytecode_index);
  int SetBreakpoint(Function* function, int bytecode_index);
  bool RemoveBreakpoint(int id);
  bool is_stepping() const { return is_stepping_; }
  void set_is_stepping(bool value) { is_stepping_ = value; }
  bool is_at_breakpoint() const { return is_at_breakpoint_; }
  void set_is_at_breakpoint(bool value) { is_at_breakpoint_ = value; }

  // GC support for program GCs.
  void VisitProgramPointers(PointerVisitor* visitor);

 private:
  bool is_stepping_;
  bool is_at_breakpoint_;

  // TODO(ager): Use better data structure for breakpoints to avoid duplicates
  // and to reduce memory use when adding and removing many breakpoints.
  List<Breakpoint*> breakpoints_;
  int next_breakpoint_index_;
};

}  // namespace fletch

#endif  // SRC_VM_DEBUG_INFO_H_
