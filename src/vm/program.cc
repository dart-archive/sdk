// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/program.h"

#include <stdlib.h>
#include <string.h>

#include "src/shared/flags.h"
#include "src/shared/globals.h"
#include "src/shared/utils.h"
#include "src/shared/selectors.h"
#include "src/shared/platform.h"

#include "src/vm/heap_validator.h"
#include "src/vm/object.h"
#include "src/vm/process.h"
#include "src/vm/port.h"
#include "src/vm/session.h"

namespace fletch {

static List<const char> StringFromCharZ(const char* str) {
  return List<const char>(str, strlen(str));
}

void ProgramState::AddPausedProcess(Process* process) {
  ASSERT(process->next() == NULL);
  process->set_next(paused_processes_head_);
  set_paused_processes_head(process);
  ASSERT(paused_processes_head_ != paused_processes_head_->next());
}

Program::Program()
    : process_list_mutex_(Platform::CreateMutex()),
      process_list_head_(NULL),
      random_(0),
      heap_(&random_),
      scheduler_(NULL),
      session_(NULL),
      entry_(NULL),
      classes_(NULL),
      constants_(NULL),
      static_methods_(NULL),
      static_fields_(NULL),
      dispatch_table_(NULL),
      vtable_(NULL),
      is_compact_(false) {
}

Program::~Program() {
  delete process_list_mutex_;
  ASSERT(process_list_head_ == NULL);
}

Process* Program::SpawnProcess() {
  Process* process = new Process(this);
  AddToProcessList(process);
  return process;
}

Process* Program::ProcessSpawnForMain() {
  if (Flags::print_program_statistics) {
    PrintStatistics();
  }

#ifdef DEBUG
  // TODO(ager): GC for testing only.
  CollectGarbage();
#endif

  Process* process = SpawnProcess();
  Function* entry = process->entry();
  int main_arity = process->main_arity();
  process->SetupExecutionStack();
  Stack* stack = process->stack();
  uint8_t* bcp = entry->bytecode_address_for(0);
  stack->set(0, Smi::FromWord(main_arity));
  stack->set(1, NULL);
  stack->set(2, reinterpret_cast<Object*>(bcp));
  stack->set_top(2);

  return process;
}

void Program::DeleteProcess(Process* process) {
  RemoveFromProcessList(process);
  delete process;
}

void Program::VisitProcesses(ProcessVisitor* visitor) {
  Process* current = process_list_head_;
  while (current != NULL) {
    visitor->VisitProcess(current);
    current = current->process_list_next();
  }
}

Object* Program::CreateArrayWith(int capacity, Object* initial_value) {
  Object* result = heap()->CreateArray(
      array_class(), capacity, initial_value, false);
  return result;
}

Object* Program::CreateByteArray(int capacity) {
  Object* result = heap()->CreateByteArray(byte_array_class(), capacity, true);
  return result;
}

Object* Program::CreateClass(int fields) {
  InstanceFormat format = InstanceFormat::instance_format(fields);
  Object* raw_class = heap()->CreateClass(
      format, meta_class(), null_object());
  if (raw_class->IsFailure()) return raw_class;
  Class* klass = Class::cast(raw_class);
  ASSERT(klass->NumberOfInstanceFields() == fields);
  return klass;
}

Object* Program::CreateDouble(double value) {
  return heap()->CreateDouble(double_class(), value);
}

Object* Program::CreateFunction(int arity,
                                List<uint8> bytes,
                                int number_of_literals) {
  return heap()->CreateFunction(function_class(),
                                arity,
                                bytes,
                                number_of_literals);
}

Object* Program::CreateLargeInteger(int64 value) {
  return heap()->CreateLargeInteger(large_integer_class(), value);
}

Object* Program::CreateInteger(int64 value) {
  if ((sizeof(int64) > sizeof(word) &&
       static_cast<int64>(static_cast<word>(value)) != value) ||
      !Smi::IsValid(value)) {
    return CreateLargeInteger(value);
  }
  return Smi::FromWord(value);
}

Object* Program::CreateStringFromAscii(List<const char> str) {
  Object* raw_result = heap()->CreateStringUninitialized(
      string_class(), str.length(), true);
  if (raw_result->IsFailure()) return raw_result;
  String* result = String::cast(raw_result);
  ASSERT(result->length() == str.length());
  // Set the content.
  for (int i = 0; i < str.length(); i++) {
    result->set_code_unit(i, str[i]);
  }
  return result;
}

Object* Program::CreateString(List<uint16> str) {
  Object* raw_result = heap()->CreateStringUninitialized(
      string_class(), str.length(), true);
  if (raw_result->IsFailure()) return raw_result;
  String* result = String::cast(raw_result);
  ASSERT(result->length() == str.length());
  // Set the content.
  for (int i = 0; i < str.length(); i++) {
    result->set_code_unit(i, str[i]);
  }
  return result;
}

Object* Program::CreateInstance(Class* klass) {
  bool immutable = true;
  return heap()->CreateComplexHeapObject(klass, null_object(), immutable);
}

Object* Program::CreateInitializer(Function* function) {
  return heap()->CreateInitializer(initializer_class_, function);
}

void Program::PrepareProgramGC(bool disable_heap_validation_before_gc) {
  // All threads are stopped and have given their parts back to the
  // [ImmutableHeap], so we can merge them now.
  immutable_heap()->MergeParts();

  if (Flags::validate_heaps && !disable_heap_validation_before_gc) {
    ValidateGlobalHeapsAreConsistent();
  }

  // Loop over all processes and cook all stacks.
  Process* current = process_list_head_;
  while (current != NULL) {
    if (Flags::validate_heaps && !disable_heap_validation_before_gc) {
      current->ValidateHeaps(&immutable_heap_);
    }

    int number_of_stacks = current->CollectGarbageAndChainStacks();
    current->CookStacks(number_of_stacks);
    current = current->process_list_next();
  }
}

void Program::PerformProgramGC(Space* to, PointerVisitor* visitor) {
  {
    NoAllocationFailureScope scope(to);

    // Iterate program roots.
    IterateRoots(visitor);

    // Iterate all immutable objects.
    HeapObjectPointerVisitor object_pointer_visitor(visitor);
    immutable_heap_.heap()->IterateObjects(&object_pointer_visitor);

    // Iterate over all process program pointers.
    Process* current = process_list_head_;
    while (current != NULL) {
      current->IterateProgramPointers(visitor);
      current = current->process_list_next();
    }

    // Finish collection.
    ASSERT(!to->is_empty());
    to->CompleteScavenge(visitor);
  }
  heap_.ReplaceSpace(to);
}

void Program::FinishProgramGC() {
  Process* current = process_list_head_;
  while (current != NULL) {
    // Uncook process
    current->UncookAndUnchainStacks();
    current->UpdateBreakpoints();

    if (Flags::validate_heaps) {
      current->ValidateHeaps(&immutable_heap_);
    }
    current = current->process_list_next();
  }

  if (Flags::validate_heaps) {
    ValidateGlobalHeapsAreConsistent();
  }
}

void Program::ValidateGlobalHeapsAreConsistent() {
  ProgramHeapPointerValidator validator(heap());
  HeapObjectPointerVisitor visitor(&validator);
  IterateRoots(&validator);
  heap()->IterateObjects(&visitor);
}

void Program::ValidateHeapsAreConsistent() {
  // Validate the program heap.
  {
    ProgramHeapPointerValidator validator(heap());
    HeapObjectPointerVisitor object_pointer_visitor(&validator);
    IterateRoots(&validator);
    heap()->IterateObjects(&object_pointer_visitor);
  }
  // Validate the immutable heap
  {
    ImmutableHeapPointerValidator validator(heap(), &immutable_heap_);
    HeapObjectPointerVisitor object_pointer_visitor(&validator);
    immutable_heap_.heap()->IterateObjects(&object_pointer_visitor);
    immutable_heap_.heap()->VisitWeakObjectPointers(&validator);
  }
  // Validate all process heaps.
  {
    ProcessHeapValidatorVisitor validator(heap(), &immutable_heap_);
    VisitProcesses(&validator);
  }
}

void Program::CollectGarbage() {
  if (scheduler() != NULL) {
    scheduler()->StopProgram(this);
  }

  Space* to = new Space();
  ScavengeVisitor scavenger(heap_.space(), to);

  PrepareProgramGC();
  PerformProgramGC(to, &scavenger);
  FinishProgramGC();

  if (scheduler() != NULL) {
    scheduler()->ResumeProgram(this);
  }
}

void Program::AddToProcessList(Process* process) {
  ScopedLock locker(process_list_mutex_);

  ASSERT(process->process_list_next() == NULL &&
         process->process_list_prev() == NULL);
  process->set_process_list_next(process_list_head_);
  if (process_list_head_ != NULL) {
    process_list_head_->set_process_list_prev(process);
  }
  process_list_head_ = process;
}

void Program::RemoveFromProcessList(Process* process) {
  ScopedLock locker(process_list_mutex_);

  Process* next = process->process_list_next();
  Process* prev = process->process_list_prev();
  if (next != NULL) {
    next->set_process_list_prev(prev);
  }
  if (prev != NULL) {
    prev->set_process_list_next(next);
  } else {
    process_list_head_ = next;
  }
  process->set_process_list_next(NULL);
  process->set_process_list_prev(NULL);
}

void Program::CollectImmutableGarbage() {
  Scheduler* scheduler = this->scheduler();
  ASSERT(scheduler != NULL);

  // This will make sure all partial immutable heaps got merged into
  // [program_->immutable_heap()].
  scheduler->StopProgram(this);

  // All threads are stopped and have given their parts back to the
  // [ImmutableHeap], so we can merge them now.
  immutable_heap()->MergeParts();

  if (Flags::validate_heaps) {
    ValidateHeapsAreConsistent();
  }

  Heap* heap = immutable_heap()->heap();
  Space* from = heap->space();
  Space* to = new Space();
  NoAllocationFailureScope alloc(to);

  ScavengeVisitor scavenger(from, to);
  Process* current = process_list_head_;
  while (current != NULL) {
    // NOTE: We could check here if the storebuffer grew to big and do a mutable
    // collection, but if a session thread is accessing the stacks of a process
    // at the same time, this is not safe.
    // TODO(kustermann): The session thread should pause immutable collections
    // so a debugger can inspect mutable/immutable objects.
    current->TakeChildHeaps();
    current->IterateRoots(&scavenger);
    current->store_buffer()->IteratePointersToImmutableSpace(&scavenger);

    current = current->process_list_next();
  }

  to->CompleteScavenge(&scavenger);
  heap->ProcessWeakPointers();
  heap->ReplaceSpace(to);

  if (Flags::validate_heaps) {
    ValidateHeapsAreConsistent();
  }

  scheduler->ResumeProgram(this);
}

class StatisticsVisitor : public HeapObjectVisitor {
 public:
  StatisticsVisitor()
      : object_count_(0),
        class_count_(0),
        array_count_(0),
        array_size_(0),
        string_count_(0),
        string_size_(0),
        function_count_(0),
        function_size_(0),
        bytecode_size_(0) { }

  int object_count() const { return object_count_; }
  int class_count() const { return class_count_; }

  int array_count() const { return array_count_; }
  int array_size() const { return array_size_; }

  int string_count() const { return string_count_; }
  int string_size() const { return string_size_; }

  int function_count() const { return function_count_; }
  int function_size() const { return function_size_; }
  int bytecode_size() const { return bytecode_size_; }

  int function_header_size() const {
    return function_count_ * Function::kSize;
  }

  void Visit(HeapObject* object) {
    object_count_++;
    if (object->IsClass()) {
      VisitClass(Class::cast(object));
    } else if (object->IsArray()) {
      VisitArray(Array::cast(object));
    } else if (object->IsString()) {
      VisitString(String::cast(object));
    } else if (object->IsFunction()) {
      VisitFunction(Function::cast(object));
    }
  }

 private:
  int object_count_;

  int class_count_;

  int array_count_;
  int array_size_;

  int string_count_;
  int string_size_;

  int function_count_;
  int function_size_;

  int bytecode_size_;

  void VisitClass(Class* clazz) {
    class_count_++;
  }

  void VisitArray(Array* array) {
    array_count_++;
    array_size_ += array->ArraySize();
  }

  void VisitString(String* str) {
    string_count_++;
    string_size_ += str->StringSize();
  }

  void VisitFunction(Function* function) {
    function_count_++;
    function_size_ += function->FunctionSize();
    bytecode_size_ += function->bytecode_size();
  }
};

void Program::PrintStatistics() {
  StatisticsVisitor statistics;
  heap_.space()->IterateObjects(&statistics);
  Print::Out("Program\n");
  Print::Out("  - size = %d bytes\n", heap_.space()->Used());
  Print::Out("  - objects = %d\n", statistics.object_count());
  Print::Out("  Classes\n");
  Print::Out("    - count = %d\n", statistics.class_count());
  Print::Out("  Arrays\n");
  Print::Out("    - count = %d\n", statistics.array_count());
  Print::Out("    - size = %d bytes\n", statistics.array_size());
  Print::Out("  Strings\n");
  Print::Out("    - count = %d\n", statistics.string_count());
  Print::Out("    - size = %d bytes\n", statistics.string_size());
  Print::Out("  Functions\n");
  Print::Out("    - count = %d\n", statistics.function_count());
  Print::Out("    - size = %d bytes\n", statistics.function_size());
  Print::Out("    - header size = %d bytes\n",
             statistics.function_header_size());
  Print::Out("    - bytecode size = %d bytes\n", statistics.bytecode_size());
}

void Program::Initialize() {
  // Create root set for the Program. During setup, do not fail
  // allocations, instead allocate new chunks.
  NoAllocationFailureScope scope(heap_.space());

  // Create null as the first object other allocated objects can use
  // null_object for initial values.
  InstanceFormat null_format =
      InstanceFormat::instance_format(0, InstanceFormat::NULL_MARKER);
  null_object_ = reinterpret_cast<ComplexHeapObject*>(
      heap()->Allocate(null_format.fixed_size()));

  meta_class_ = Class::cast(heap()->CreateMetaClass());

  {
    InstanceFormat format = InstanceFormat::array_format();
    array_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
  }

  empty_array_ = Array::cast(CreateArray(0));

  {
    InstanceFormat format = InstanceFormat::instance_format(0);
    object_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
  }

  {
    InstanceFormat format = InstanceFormat::num_format();
    num_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
    num_class_->set_super_class(object_class_);
  }

  {
    InstanceFormat format = InstanceFormat::num_format();
    int_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
    int_class_->set_super_class(num_class_);
  }

  {
    InstanceFormat format = InstanceFormat::smi_format();
    smi_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
    smi_class_->set_super_class(int_class_);
  }

  {
    InstanceFormat format = InstanceFormat::heap_integer_format();
    large_integer_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
    large_integer_class_->set_super_class(int_class_);
  }

  {
    InstanceFormat format = InstanceFormat::double_format();
    double_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
    double_class_->set_super_class(num_class_);
  }

  {
    InstanceFormat format = InstanceFormat::boxed_format();
    boxed_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
  }

  {
    InstanceFormat format = InstanceFormat::stack_format();
    stack_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
  }

  {
    InstanceFormat format =
        InstanceFormat::instance_format(2, InstanceFormat::COROUTINE_MARKER);
    coroutine_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
  }

  {
    InstanceFormat format =
        InstanceFormat::instance_format(1, InstanceFormat::PORT_MARKER);
    port_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
  }

  {
    InstanceFormat format = InstanceFormat::instance_format(
        1, InstanceFormat::FOREIGN_FUNCTION_MARKER);
    foreign_function_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
  }

  {
    InstanceFormat format = InstanceFormat::instance_format(
        2, InstanceFormat::FOREIGN_MEMORY_MARKER);
    foreign_memory_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
  }

  {
    InstanceFormat format = InstanceFormat::initializer_format();
    initializer_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
  }

  {
    InstanceFormat format = InstanceFormat::instance_format(1);
    constant_list_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
  }

  {
    InstanceFormat format = InstanceFormat::instance_format(1);
    constant_byte_list_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
  }

  {
    InstanceFormat format = InstanceFormat::instance_format(2);
    constant_map_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
  }

  {
    InstanceFormat format = InstanceFormat::string_format();
    string_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
    string_class_->set_super_class(object_class_);
  }

  empty_string_ = String::cast(heap()->CreateString(string_class(), 0, true));

  {
    InstanceFormat format = InstanceFormat::function_format();
    function_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
  }

  {
    InstanceFormat format = InstanceFormat::byte_array_format();
    byte_array_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
  }

  Class* null_class;
  { // Create null class and singleton.
    null_class =
        Class::cast(heap()->CreateClass(null_format, meta_class_,
                                        null_object_));
    null_class->set_super_class(object_class_);
    null_object_->set_class(null_class);
    null_object_->set_immutable(true);
    null_object_->InitializeIdentityHashCode(random());
    null_object_->Initialize(null_format.fixed_size(),
                             null_object_);
  }

  { // Create the bool class.
    InstanceFormat format = InstanceFormat::instance_format(0);
    bool_class_ = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
    bool_class_->set_super_class(object_class_);
  }

  { // Create False class and the false object.
    InstanceFormat format =
        InstanceFormat::instance_format(0, InstanceFormat::FALSE_MARKER);
    Class* false_class = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
    false_class->set_super_class(bool_class_);
    false_class->set_methods(empty_array_);
    false_object_ = ComplexHeapObject::cast(
        heap()->CreateComplexHeapObject(false_class, null_object(), true));
  }

  { // Create True class and the true object.
    InstanceFormat format =
        InstanceFormat::instance_format(0, InstanceFormat::TRUE_MARKER);
    Class* true_class = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
    true_class->set_super_class(bool_class_);
    true_class->set_methods(empty_array_);
    true_object_ = ComplexHeapObject::cast(
        heap()->CreateComplexHeapObject(true_class, null_object(), true));
  }

  { // Create sentinel singleton.
    InstanceFormat format = InstanceFormat::instance_format(0);
    Class* sentinel_class = Class::cast(
        heap()->CreateClass(format, meta_class_, null_object_));
    sentinel_object_ = ComplexHeapObject::cast(
        heap()->CreateComplexHeapObject(sentinel_class, null_object(), true));
  }

  // Create the retry after gc failure object payload.
  raw_retry_after_gc_ =
      String::cast(CreateStringFromAscii(StringFromCharZ("Retry after GC.")));

  // Create the failure object payloads. These need to be kept in sync with the
  // constants in lib/system/system.dart.
  raw_wrong_argument_type_ =
      String::cast(
          CreateStringFromAscii(StringFromCharZ("Wrong argument type.")));

  raw_index_out_of_bounds_ =
      String::cast(
          CreateStringFromAscii(StringFromCharZ("Index out of bounds.")));

  raw_illegal_state_ =
      String::cast(CreateStringFromAscii(StringFromCharZ("Illegal state.")));

  raw_stack_overflow_ =
      String::cast(CreateStringFromAscii(StringFromCharZ("Stack overflow.")));

  native_failure_result_ = null_object_;
}

void Program::IterateRoots(PointerVisitor* visitor) {
  visitor->VisitBlock(first_root_address(), last_root_address() + 1);
  visitor->Visit(reinterpret_cast<Object**>(&entry_));
  visitor->Visit(reinterpret_cast<Object**>(&classes_));
  visitor->Visit(reinterpret_cast<Object**>(&constants_));
  visitor->Visit(reinterpret_cast<Object**>(&static_methods_));
  visitor->Visit(reinterpret_cast<Object**>(&static_fields_));
  visitor->Visit(reinterpret_cast<Object**>(&dispatch_table_));
  visitor->Visit(reinterpret_cast<Object**>(&vtable_));
  if (session_ != NULL) session_->IteratePointers(visitor);
}

void Program::ClearDispatchTableIntrinsics() {
  Array* table = dispatch_table();
  if (table == NULL) return;
  int length = table->length();
  for (int i = 0; i < length; i += 4) {
    table->set(i + 2, NULL);
  }

  table = vtable();
  if (table == NULL) return;
  length = table->length();
  for (int i = 0; i < length; i++) {
    Object* element = table->get(i);
    if (element == null_object()) continue;
    Array* entry = Array::cast(element);
    entry->set(3, NULL);
  }
}

void Program::SetupDispatchTableIntrinsics() {
  Array* table = dispatch_table();
  if (table == NULL) return;
  int length = table->length();
  int hits = 0;
  for (int i = 0; i < length; i += 4) {
    ASSERT(table->get(i + 2) == NULL);
    Object* target = table->get(i + 3);
    if (target == NULL) continue;
    hits += 4;
    Function* method = Function::cast(target);
    Object* intrinsic = reinterpret_cast<Object*>(method->ComputeIntrinsic());
    ASSERT(intrinsic->IsSmi());
    table->set(i + 2, intrinsic);
  }

  if (Flags::print_program_statistics) {
    Print::Out("Dispatch table fill: %F%% (%i of %i)\n",
               hits * 100.0 / length,
               hits,
               length);
  }

  table = vtable();
  if (table == NULL) return;
  length = table->length();
  hits = 0;

  static const Names::Id name = Names::kNoSuchMethodTrampoline;
  Function* trampoline = object_class()->LookupMethod(
        Selector::Encode(name, Selector::METHOD, 0));

  for (int i = 0; i < length; i++) {
    Object* element = table->get(i);
    if (element == null_object()) continue;
    Array* entry = Array::cast(element);
    if (entry->get(3) != NULL) continue;
    Object* target = entry->get(2);
    if (target == NULL) continue;
    if (target != trampoline) hits++;
    Function* method = Function::cast(target);
    Object* intrinsic = reinterpret_cast<Object*>(method->ComputeIntrinsic());
    ASSERT(intrinsic->IsSmi());
    entry->set(3, intrinsic);
  }

  if (Flags::print_program_statistics) {
    Print::Out("Vtable fill: %F%% (%i of %i)\n",
               hits * 100.0 / length,
               hits,
               length);
  }
}

}  // namespace fletch
