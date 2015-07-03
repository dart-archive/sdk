// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PROGRAM_H_
#define SRC_VM_PROGRAM_H_

#include "src/shared/globals.h"
#include "src/shared/random.h"
#include "src/vm/event_handler.h"
#include "src/vm/heap.h"
#include "src/vm/scheduler.h"

namespace fletch {

class Class;
class Function;
class Method;
class Process;
class ProgramTableRewriter;
class Session;

// Defines all the roots in the program heap.
#define ROOTS_DO(V)                              \
  V(ComplexHeapObject, null_object)              \
  V(ComplexHeapObject, false_object)             \
  V(ComplexHeapObject, true_object)              \
  V(ComplexHeapObject, sentinel_object)          \
  /* Global literals up to this line */          \
  V(Array, empty_array)                          \
  V(String, empty_string)                        \
  V(Class, meta_class)                           \
  V(Class, smi_class)                            \
  V(Class, boxed_class)                          \
  V(Class, large_integer_class)                  \
  V(Class, num_class)                            \
  V(Class, bool_class)                           \
  V(Class, int_class)                            \
  V(Class, string_class)                         \
  V(Class, object_class)                         \
  V(Class, array_class)                          \
  V(Class, function_class)                       \
  V(Class, byte_array_class)                     \
  V(Class, double_class)                         \
  V(Class, stack_class)                          \
  V(Class, coroutine_class)                      \
  V(Class, port_class)                           \
  V(Class, foreign_function_class)               \
  V(Class, foreign_memory_class)                 \
  V(Class, initializer_class)                    \
  V(Class, constant_list_class)                  \
  V(Class, constant_map_class)                   \
  V(HeapObject, raw_retry_after_gc)              \
  V(HeapObject, raw_wrong_argument_type)         \
  V(HeapObject, raw_index_out_of_bounds)         \
  V(HeapObject, raw_illegal_state)               \
  V(HeapObject, raw_should_preempt)              \
  V(Object, native_failure_result)

class Program {
 public:
  Program();
  ~Program();

  void Initialize();

  bool ProcessRun(Process* process);

  // Unfold the program into a new heap where all indices are resolved
  // and stored in the literals section of methods. Having
  // self-contained methods makes it easier to do changes to the live
  // system. The caller of Unfold should stop all processes running for this
  // program before calling.
  void Unfold();
  Object* UnfoldFunction(Function* function, Space* to, void* map);

  // Fold the program into a compact format where methods, classes and
  // constants are stored in global tables in the program instead of
  // duplicated out in the literals sections of methods. The caller of
  // Fold should stop all processes running for this program before calling.
  void Fold();
  void FoldFunction(Function* old_function,
                    Function* new_function,
                    ProgramTableRewriter* rewriter);

  // Is the program in the compact table representation?
  bool is_compact() const { return is_compact_; }
  void set_is_compact(bool value) { is_compact_ = value; }

  Function* entry() const { return entry_; }
  void set_entry(Function* entry) { entry_ = entry; }

  int main_arity() const { return main_arity_; }
  void set_main_arity(int value) { main_arity_ = value; }

  Array* classes() const { return classes_; }
  void set_classes(Object* classes) { classes_ = Array::cast(classes); }
  Class* class_at(int index) const { return Class::cast(classes_->get(index)); }

  Array* constants() const { return constants_; }
  void set_constants(Object* constants) { constants_ = Array::cast(constants); }
  Object* constant_at(int index) const { return constants_->get(index); }

  Array* static_methods() const { return static_methods_; }
  void set_static_methods(Object* static_methods) {
    static_methods_ = Array::cast(static_methods);
  }
  Function* static_method_at(int index) const {
    return Function::cast(static_methods_->get(index));
  }

  Array* static_fields() const { return static_fields_; }
  void set_static_fields(Object* static_fields) {
    static_fields_ = Array::cast(static_fields);
  }

  Array* dispatch_table() const { return dispatch_table_; }
  void set_dispatch_table(Object* dispatch_table) {
    dispatch_table_ = Array::cast(dispatch_table);
  }

  Array* vtable() const { return vtable_; }
  void set_vtable(Object* vtable) {
    vtable_ = Array::cast(vtable);
  }

  Scheduler* scheduler() const { return scheduler_; }
  void set_scheduler(Scheduler* scheduler) {
    ASSERT(scheduler_ == NULL);
    scheduler_ = scheduler;
  }

  EventHandler* event_handler() { return &event_handler_; }

  // TODO(ager): Support more than one active session at a time.
  void AddSession(Session* session) {
    ASSERT(session_ == NULL);
    session_ = session;
  }

  Session* session() { return session_; }

  Heap* heap() { return &heap_; }

  HeapObject* ObjectFromFailure(Failure* failure) {
    if (failure == Failure::wrong_argument_type()) {
      return raw_wrong_argument_type();
    } else if (failure == Failure::index_out_of_bounds()) {
      return raw_index_out_of_bounds();
    } else if (failure == Failure::illegal_state()) {
      return raw_illegal_state();
    } else if (failure == Failure::should_preempt()) {
      return raw_should_preempt();
    }
    UNREACHABLE();
    return NULL;
  }

  Process* SpawnProcess();
  Process* ProcessSpawnForMain();

  Object* CreateArray(int capacity) {
    return CreateArrayWith(capacity, null_object());
  }
  Object* CreateArrayWith(int capacity, Object* initial_value);
  Object* CreateClass(int fields);
  Object* CreateDouble(double value);
  Object* CreateFunction(int arity,
                         List<uint8> bytes,
                         int number_of_literals);
  Object* CreateInteger(int64 value);
  Object* CreateLargeInteger(int64 value);
  Object* CreateStringFromAscii(List<const char> str);
  Object* CreateString(List<uint16> str);
  Object* CreateInstance(Class* klass);
  Object* CreateInitializer(Function* function);

  void CollectGarbage();

  void PrintStatistics();

  // Iterates over all roots in the program.
  void IterateRoots(PointerVisitor* visitor);

  // Dispatch table support.
  void ClearDispatchTableIntrinsics();
  void SetupDispatchTableIntrinsics();

  // Root objects.
#define ROOT_ACCESSOR(type, name)                                       \
  type* name() const { return name##_; }                                \
  static int name##_offset() { return OFFSET_OF(Program, name##_); }
  ROOTS_DO(ROOT_ACCESSOR)
#undef ROOT_ACCESSOR

  static int ClassesOffset() { return OFFSET_OF(Program, classes_); }
  static int ConstantsOffset() { return OFFSET_OF(Program, constants_); }

  static int StaticMethodsOffset() {
    return OFFSET_OF(Program, static_methods_);
  }

  static int DispatchTableOffset() {
    return OFFSET_OF(Program, dispatch_table_);
  }

  static int VTableOffset() {
    return OFFSET_OF(Program, vtable_);
  }

  RandomLCG* random() { return &random_; }

 private:
  // Access to the address of the first and last root.
  Object** first_root_address() { return bit_cast<Object**>(&null_object_); }
  Object** last_root_address() { return &native_failure_result_; }

  void PrepareProgramGC(Process** additional_processes);
  void PerformProgramGC(Space* to,
                        PointerVisitor* visitor,
                        Process* additional_processes);
  void FinishProgramGC(Process* additional_processes);

  RandomLCG random_;

  Heap heap_;

  Scheduler* scheduler_;

  EventHandler event_handler_;

  // Session operating on this program.
  Session* session_;

  Function* entry_;
  int main_arity_;

  Array* classes_;
  Array* constants_;
  Array* static_methods_;
  Array* static_fields_;

  Array* dispatch_table_;
  Array* vtable_;

  bool is_compact_;

#define ROOT_DECLARATION(type, name) type* name##_;
  ROOTS_DO(ROOT_DECLARATION)
#undef ROOT_DECLARATION
};

#undef ROOTS_DO

}  // namespace fletch

#endif  // SRC_VM_PROGRAM_H_
