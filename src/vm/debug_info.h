// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_DEBUG_INFO_H_
#define SRC_VM_DEBUG_INFO_H_

#include <unordered_map>

namespace fletch {

class Function;
class PointerVisitor;

class Breakpoint {
 public:
  Breakpoint(Function* function, int bytecode_index, int id, bool is_one_shot);

  Function* function() const { return function_; }
  int bytecode_index() const { return bytecode_index_; }
  int id() const { return id_; }
  bool is_one_shot() const { return is_one_shot_; }

  // GC support for program GCs.
  void VisitProgramPointers(PointerVisitor* visitor);

 private:
  Function* function_;
  int bytecode_index_;
  int id_;
  bool is_one_shot_;
};

class DebugInfo {
 public:
  DebugInfo();

  bool ShouldBreak(uint8_t* bcp);
  int SetBreakpoint(Function* function, int bytecode_index);
  bool DeleteBreakpoint(int id);
  bool is_stepping() const { return is_stepping_; }
  void set_is_stepping(bool value) { is_stepping_ = value; }
  bool is_at_breakpoint() const { return is_at_breakpoint_; }
  void set_is_at_breakpoint(bool value) { is_at_breakpoint_ = value; }

  // GC support for program GCs.
  void VisitProgramPointers(PointerVisitor* visitor);
  void UpdateBreakpoints();

 private:
  bool is_stepping_;
  bool is_at_breakpoint_;

  typedef std::unordered_map<uint8_t*, Breakpoint> BreakpointMap;
  BreakpointMap breakpoints_;
  int next_breakpoint_id_;
};

}  // namespace fletch

#endif  // SRC_VM_DEBUG_INFO_H_
