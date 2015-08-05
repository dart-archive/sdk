// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PROGRAM_H_
#define SRC_VM_PROGRAM_H_

#include "src/shared/globals.h"
#include "src/shared/random.h"
#include "src/vm/event_handler.h"
#include "src/vm/heap.h"
#include "src/vm/program_folder.h"

namespace fletch {

class Class;
class Function;
class Method;
class Process;
class ProcessVisitor;
class ProgramTableRewriter;
class Scheduler;
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
  V(HeapObject, raw_stack_overflow)              \
  V(Object, native_failure_result)

class ProgramState {
 public:
  ProgramState() : paused_processes_head_(NULL), is_paused_(false) {}

  // The [Scheduler::pause_monitor_] must be locked when calling this method.
  void AddPausedProcess(Process* process) ;

  bool is_paused() const { return is_paused_; }
  void set_is_paused(bool value) { is_paused_ = value; }

  Process* paused_processes_head() const { return paused_processes_head_; }
  void set_paused_processes_head(Process* value) {
    paused_processes_head_ = value;
  }

 private:
  Process* paused_processes_head_;
  bool is_paused_;
};

class Program {
 public:
  Program();
  ~Program();

  void Initialize();

  // Is the program in the compact table representation?
  bool is_compact() const { return is_compact_; }
  void set_is_compact(bool value) { is_compact_ = value; }

  Function* entry() const { return entry_; }
  void set_entry(Function* entry) { entry_ = entry; }

  int main_arity() const { return main_arity_; }
  void set_main_arity(int value) { main_arity_ = value; }

  Array* classes() const { return classes_; }
  void set_classes(Array* classes) { classes_ = classes; }
  Class* class_at(int index) const { return Class::cast(classes_->get(index)); }

  Array* constants() const { return constants_; }
  void set_constants(Array* constants) { constants_ = constants; }
  Object* constant_at(int index) const { return constants_->get(index); }

  Array* static_methods() const { return static_methods_; }
  void set_static_methods(Array* static_methods) {
    static_methods_ = static_methods;
  }
  Function* static_method_at(int index) const {
    return Function::cast(static_methods_->get(index));
  }

  Array* static_fields() const { return static_fields_; }
  void set_static_fields(Array* static_fields) {
    static_fields_ = static_fields;
  }

  Array* dispatch_table() const { return dispatch_table_; }
  void set_dispatch_table(Array* dispatch_table) {
    dispatch_table_ = dispatch_table;
  }

  Array* vtable() const { return vtable_; }
  void set_vtable(Array* vtable) {
    vtable_ = vtable;
  }

  Scheduler* scheduler() const { return scheduler_; }
  void set_scheduler(Scheduler* scheduler) {
    ASSERT((scheduler_ == NULL && scheduler != NULL) ||
           (scheduler_ != NULL && scheduler == NULL));
    ASSERT(program_state_.paused_processes_head() == NULL);
    ASSERT(!program_state_.is_paused());
    scheduler_ = scheduler;
  }

  ProgramState* program_state() { return &program_state_; }

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
    }

    UNREACHABLE();
    return NULL;
  }

  Process* SpawnProcess();
  Process* ProcessSpawnForMain();
  void DeleteProcess(Process* process);

  // This function should only be called once the program has been stopped.
  void VisitProcesses(ProcessVisitor* visitor);

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
  void CollectImmutableGarbage();

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

  void PrepareProgramGC(bool disable_heap_validation_before_gc = false);
  void PerformProgramGC(Space* to, PointerVisitor* visitor);
  void FinishProgramGC();

 private:
  // Access to the address of the first and last root.
  Object** first_root_address() { return bit_cast<Object**>(&null_object_); }
  Object** last_root_address() { return &native_failure_result_; }

  void ValidateGlobalHeapsAreConsistent();

  // Chaining of all processes of this program.
  void AddToProcessList(Process* process);
  void RemoveFromProcessList(Process* process);

  // Chained doubly linked list of all processes protected by a lock.
  Mutex* process_list_mutex_;
  Process* process_list_head_;

  RandomLCG random_;

  Heap heap_;

  Scheduler* scheduler_;
  ProgramState program_state_;

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
