// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/program.h"

// TODO(ager): Implement a self-contained simple hash map.
#include <stdlib.h>
#include <string.h>

#include <algorithm>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <utility>

#include "src/shared/bytecodes.h"
#include "src/shared/flags.h"
#include "src/shared/globals.h"
#include "src/shared/utils.h"
#include "src/shared/selectors.h"

#include "src/vm/heap.h"
#include "src/vm/heap_validator.h"
#include "src/vm/object.h"
#include "src/vm/process.h"
#include "src/vm/port.h"
#include "src/vm/selector_row.h"
#include "src/vm/session.h"

namespace fletch {

typedef std::unordered_map<Object*, int> ObjectIndexMap;
typedef std::unordered_map<int, SelectorRow*> SelectorRowMap;
typedef std::unordered_map<int, int> SelectorOffsetMap;

static List<const char> StringFromCharZ(const char* str) {
  return List<const char>(str, strlen(str));
}

Program::Program()
    : random_(0),
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

Program::~Program() { }

static int AddToMap(ObjectIndexMap* map, Object* value) {
  ObjectIndexMap::const_iterator it = map->find(value);
  if (it != map->end()) {
    return it->second;
  } else {
    int index = map->size();
    map->insert({value, index});
    return index;
  }
}

static Array* MapToArray(ObjectIndexMap* map, Program* program) {
  Array* result = Array::cast(program->CreateArray(map->size()));
  ObjectIndexMap::const_iterator it = map->begin();
  ObjectIndexMap::const_iterator end = map->end();
  for (; it != end; ++it) result->set(it->second, it->first);
  return result;
}

class ProcessInPortFinder : public PointerVisitor {
 public:
  explicit ProcessInPortFinder(ProcessVisitor* visitor)
      : process_visitor_(visitor) {}
  virtual ~ProcessInPortFinder() {}

  virtual void VisitBlock(Object** start, Object** end) {
    for (Object** current = start; current < end; current++) {
      Object* object = *current;
      if (object->IsPort()) {
        Instance* instance = Instance::cast(object);
        Object* field = instance->GetInstanceField(0);
        if (!field->IsNull()) {
          uword address = AsForeignWord(field);
          Port* port = reinterpret_cast<Port*>(address);
          Process* process = port->process();
          if (process != NULL) {
            process_visitor_->VisitProcess(process);
          }
        }
      }
    }
  }

 private:
  ProcessVisitor* process_visitor_;
};

class LinkProcessesForGc : public ProcessVisitor {
 public:
  explicit LinkProcessesForGc(Process** all_processes)
      : all_processes_(all_processes), process_count_(0) {
    *all_processes = NULL;
  }
  virtual ~LinkProcessesForGc() {}

  virtual void VisitProcess(Process* process) {
    ASSERT(process != NULL);

    if (process->program_gc_state() == Process::kUnknown) {
      ASSERT(process->program_gc_next() == NULL)
      process->set_program_gc_state(Process::kFound);
      process->set_program_gc_next(*all_processes_);
      *all_processes_ = process;
      process_count_++;
    }
  }

  void Finish() {
    while (*all_processes_ != NULL &&
           (*all_processes_)->program_gc_state() == Process::kFound) {
      // At each iteration, start from the beginning of the all_processes
      // list and go until we find a process that we have already processed
      // or we hit the end. During the iteration we can discover more processes
      // that are added to the front of the list and picked up in the next
      // iteration.
      Process* current = *all_processes_;
      while (current != NULL &&
             current->program_gc_state() == Process::kFound) {
        current->set_program_gc_state(Process::kProcessed);

        // Traverse object pointers in the weak pointer list and in the port
        // queues. In case they contain port ojects, we call [process_visitor_]
        // with the process of the port.
        ProcessInPortFinder finder(this);
        current->heap()->VisitWeakObjectPointers(&finder);
        current->IteratePortQueuesProcesses(this);

        current = current->program_gc_next();
      }
    }
  }

  size_t process_count() { return process_count_; }

 private:
  Process** all_processes_;
  size_t process_count_;
};

class LiteralsRewriter {
 public:
  LiteralsRewriter(Space* space, Function* function)
      : function_(function) {
    ASSERT(space->in_no_allocation_failure_scope());
  }

  void AddLiteralAndRewrite(Array* table, uint8_t* bcp) {
    int index = Utils::ReadInt32(bcp + 1);
    Object* literal = table->get(index);
    int literal_index = AddToMap(&literals_index_map_, literal);
    Object** literal_address = function_->literal_address_for(literal_index);
    int offset = reinterpret_cast<uint8_t*>(literal_address) - bcp;
    *bcp = *bcp + 1;
    Utils::WriteInt32(bcp + 1, offset);
  }

  int NumberOfLiterals() { return literals_index_map_.size(); }

  void FillInLiterals(Function* function) {
    ObjectIndexMap::const_iterator it = literals_index_map_.begin();
    ObjectIndexMap::const_iterator end = literals_index_map_.end();
    for (; it != end; ++it) function->set_literal_at(it->second, it->first);
  }

 private:
  Function* function_;
  ObjectIndexMap literals_index_map_;
};

Object* Program::UnfoldFunction(Function* function,
                                Space* to,
                                void* raw_map) {
  SelectorOffsetMap* map = static_cast<SelectorOffsetMap*>(raw_map);
  LiteralsRewriter rewriter(to, function);

  uint8_t* bcp = function->bytecode_address_for(0);

  while (true) {
    Opcode opcode = static_cast<Opcode>(*bcp);

    switch (opcode) {
      case kLoadConst:
        rewriter.AddLiteralAndRewrite(constants(), bcp);
        break;
      case kInvokeStatic:
      case kInvokeFactory:
        rewriter.AddLiteralAndRewrite(static_methods(), bcp);
        break;
      case kAllocate:
      case kAllocateImmutable:
        rewriter.AddLiteralAndRewrite(classes(), bcp);
        break;

      case kInvokeEqFast:
      case kInvokeLtFast:
      case kInvokeLeFast:
      case kInvokeGtFast:
      case kInvokeGeFast:

      case kInvokeAddFast:
      case kInvokeSubFast:
      case kInvokeModFast:
      case kInvokeMulFast:
      case kInvokeTruncDivFast:

      case kInvokeBitNotFast:
      case kInvokeBitAndFast:
      case kInvokeBitOrFast:
      case kInvokeBitXorFast:
      case kInvokeBitShrFast:
      case kInvokeBitShlFast:

      case kInvokeTestFast:
      case kInvokeMethodFast: {
        int index = Utils::ReadInt32(bcp + 1);
        Array* table = dispatch_table();
        int selector = Smi::cast(table->get(index + 1))->value();
        *bcp = opcode + (kInvokeMethod - kInvokeMethodFast);
        Utils::WriteInt32(bcp + 1, selector);
        break;
      }

      case kInvokeEqVtable:
      case kInvokeLtVtable:
      case kInvokeLeVtable:
      case kInvokeGtVtable:
      case kInvokeGeVtable:

      case kInvokeAddVtable:
      case kInvokeSubVtable:
      case kInvokeModVtable:
      case kInvokeMulVtable:
      case kInvokeTruncDivVtable:

      case kInvokeBitNotVtable:
      case kInvokeBitAndVtable:
      case kInvokeBitOrVtable:
      case kInvokeBitXorVtable:
      case kInvokeBitShrVtable:
      case kInvokeBitShlVtable:

      case kInvokeTestVtable:
      case kInvokeMethodVtable: {
        int offset = Selector::IdField::decode(Utils::ReadInt32(bcp + 1));
        int selector = map->at(offset);
        *bcp = opcode + (kInvokeMethod - kInvokeMethodVtable);
        Utils::WriteInt32(bcp + 1, selector);
        break;
      }

      case kMethodEnd: {
        ASSERT(function->literals_size() == 0);
        int number_of_literals = rewriter.NumberOfLiterals();
        Object* clone = function->UnfoldInToSpace(to, number_of_literals);
        Function* result = Function::cast(clone);
        rewriter.FillInLiterals(result);
        ASSERT(result->literals_size() == number_of_literals);
        return result;
      }
      case kLoadConstUnfold:
      case kInvokeStaticUnfold:
      case kInvokeFactoryUnfold:
      case kAllocateUnfold:
      case kAllocateImmutableUnfold:
        // We should only unfold folded functions.
        UNREACHABLE();
      default:
        ASSERT(opcode < Bytecode::kNumBytecodes);
        break;
    }

    bcp += Bytecode::Size(opcode);
  }

  UNREACHABLE();
  return NULL;
}

class UnfoldingVisitor: public PointerVisitor {
 public:
  UnfoldingVisitor(Program* program,
                   Space* from,
                   Space* to,
                   SelectorOffsetMap* map)
      : program_(program),
        from_(from),
        to_(to),
        map_(map) { }

  void Visit(Object** p) { UnfoldPointer(p); }

  void VisitBlock(Object** start, Object** end) {
    // Unfold all HeapObject pointers in [start, end)
    for (Object** p = start; p < end; p++) UnfoldPointer(p);
  }

 private:
  void UnfoldPointer(Object** p) {
    Object* object = *p;
    if (!object->IsHeapObject()) return;
    if (!from_->Includes(reinterpret_cast<uword>(object))) return;
    // Check for forwarding address before checking type.
    HeapObject* f = HeapObject::cast(object)->forwarding_address();
    if (f != NULL) {
      *p = f;
    } else if (object->IsFunction()) {
      // Rewrite functions.
      *p = program_->UnfoldFunction(Function::cast(object), to_, map_);
    } else {
      *p = reinterpret_cast<HeapObject*>(object)->CloneInToSpace(to_);
    }
  }

  Program* program_;
  Space* from_;
  Space* to_;
  SelectorOffsetMap* map_;
};

void Program::Unfold() {
  // TODO(ager): Can we add an assert that there are no processes running
  // for this program. Either because we haven't enqueued any or because
  // the program is stopped?
  ASSERT(is_compact());

  // Run through the vtable and compute a map from selector offsets
  // to the original selectors. This is used when rewriting the
  // bytecodes back to the original invoke-method bytecodes.
  SelectorOffsetMap map;
  if (vtable_ != NULL) {
    Array* vtable = vtable_;
    for (int i = 0, length = vtable->length(); i < length; i++) {
      Object* element = vtable->get(i);
      if (element->IsNull()) continue;
      Array* entry = Array::cast(element);
      int offset = Smi::cast(entry->get(0))->value();
      int selector = Smi::cast(entry->get(1))->value();
      ASSERT(map.count(offset) == 0 || map[offset] == selector);
      map[offset] = selector;
    }
  }


  // List of processes that are only referenced by ports floating
  // around in the system.
  Process* all_processes = NULL;
  PrepareProgramGC(&all_processes);
  Space* to = new Space();
  UnfoldingVisitor visitor(this, heap_.space(), to, &map);
  PerformProgramGC(to, &visitor, all_processes);

  classes_ = NULL;
  constants_ = NULL;
  static_methods_ = NULL;
  dispatch_table_ = NULL;
  vtable_ = NULL;
  is_compact_ = false;

  FinishProgramGC(&all_processes);
}

class ProgramTableRewriter {
 public:
  ProgramTableRewriter() : linear_size_(0) { }

  ~ProgramTableRewriter() {
    SelectorRowMap::const_iterator it = selector_rows_.begin();
    SelectorRowMap::const_iterator end = selector_rows_.end();
    for (; it != end; ++it) delete it->second;
  }

  int ClassCount() const { return class_vector_.size(); }

  Class* LookupClass(int index) {
    return class_vector_[index];
  }

  SelectorRow* LookupSelectorRow(int selector, bool nsm) {
    SelectorRow*& entry = selector_rows_[selector];
    if (entry == NULL) {
      entry = new SelectorRow(selector);
      if (nsm) {
        linear_size_ = entry->SetLinearOffset(linear_size_);
      }
    }
    return entry;
  }

  void ProcessSelectorRows(Program* program) {
    SelectorRowMap::const_iterator it;
    SelectorRowMap::const_iterator end = selector_rows_.end();

    // Compute the sizes of the dispatch tables.
    std::vector<SelectorRow*> table_rows;
    int linear_size = 0;
    for (it = selector_rows_.begin(); it != end; ++it) {
      SelectorRow* row = it->second;
      SelectorRow::Kind kind = row->Finalize();
      if (kind == SelectorRow::LINEAR) {
        linear_size = row->SetLinearOffset(linear_size);
      } else {
        table_rows.push_back(row);
      }
    }
    linear_size_ = linear_size;

    // Sort the table rows according to size.
    if (table_rows.size() == 0) return;
    std::sort(table_rows.begin(), table_rows.end(), SelectorRow::Compare);

    // We add a fake header entry at the start of the vtable to deal
    // with noSuchMethod.
    static const int kHeaderSize = 1;

    RowFitter fitter;
    for (unsigned i = 0; i < table_rows.size(); i++) {
      SelectorRow* row = table_rows[i];
      // Sizes up to 2 cells in width can only be of one range.
      if (row->ComputeTableSize() <= 2) {
        int offset = fitter.FitRowWithSingleRange(row);
        row->set_offset(offset + kHeaderSize);
      } else {
        int offset = fitter.Fit(row);
        row->set_offset(offset + kHeaderSize);
      }
    }

    // The combined table size is header plus enough space to guarantee
    // that looking up at the highest offset with any given receiver class
    // isn't going to be out of bounds.
    int table_size = kHeaderSize +
        fitter.limit() +
        program->classes()->length();

    // Allocate the vtable and fill it in.
    Array* table = Array::cast(program->CreateArray(table_size));
    for (unsigned i = 0; i < table_rows.size(); i++) {
      table_rows[i]->FillTable(program, table);
    }

    // Simplify how we deal with noSuchMethod in the interpreter
    // by explicitly replacing all unused entries in the vtable with
    // an entry that doesn't match any invoke. Also, make sure the
    // first table entry always refers to this noSuchMethod entry.
    static const Names::Id name = Names::kNoSuchMethodTrampoline;
    Function* trampoline = program->object_class()->LookupMethod(
        Selector::Encode(name, Selector::METHOD, 0));

    Array* nsm = Array::cast(program->CreateArray(4));
    nsm->set(0, Smi::FromWord(0));
    nsm->set(1, Smi::FromWord(0));
    nsm->set(2, trampoline);
    nsm->set(3, NULL);

    ASSERT(table->get(0)->IsNull());
    for (int i = 0; i < table_size; i++) {
      if (table->get(i)->IsNull()) {
        table->set(i, nsm);
      }
    }
    ASSERT(table->get(0) == nsm);

    program->set_vtable(table);
  }

  void FinalizeSelectorRows(Program* program) {
    SelectorRowMap::const_iterator it;
    SelectorRowMap::const_iterator end = selector_rows_.end();

    // Fill in the linear dispatch table entries.
    Array* linear = Array::cast(program->CreateArray(linear_size_));
    for (it = selector_rows_.begin(); it != end; ++it) {
      SelectorRow* row = it->second;
      if (row->kind() == SelectorRow::LINEAR) {
        row->FillLinear(program, linear);
      }
    }
    program->set_dispatch_table(linear);
  }

  void AddMethodAndRewrite(uint8_t* bcp, uint8_t* new_bcp) {
    AddAndRewrite(&static_methods_, bcp, new_bcp);
  }

  int AddConstant(Object* constant) {
    return AddToMap(&constants_, constant);
  }

  void AddConstantAndRewrite(uint8_t* bcp, uint8_t* new_bcp) {
    AddAndRewrite(&constants_, bcp, new_bcp);
  }

  void AddClassAndRewrite(uint8_t* bcp, uint8_t* new_bcp) {
    Class* clazz = Class::cast(Function::ConstantForBytecode(bcp));
    unsigned index = AddAndRewrite(&class_map_, clazz, new_bcp);
    if (index >= class_vector_.size()) {
      class_vector_.push_back(clazz);
      ASSERT(class_vector_[index] == clazz);
    }
  }

  Array* CreateConstantArray(Program* program) {
    return MapToArray(&constants_, program);
  }

  Array* CreateStaticMethodArray(Program* program) {
    return MapToArray(&static_methods_, program);
  }

 private:
  int AddAndRewrite(ObjectIndexMap* map, uint8_t* bcp, uint8_t* new_bcp) {
    Object* literal = Function::ConstantForBytecode(bcp);
    return AddAndRewrite(map, literal, new_bcp);
  }

  int AddAndRewrite(ObjectIndexMap* map, Object* literal, uint8_t* new_bcp) {
    int new_index = AddToMap(map, literal);
    *new_bcp = *new_bcp - 1;
    Utils::WriteInt32(new_bcp + 1, new_index);
    return new_index;
  }

  ClassVector class_vector_;
  ObjectIndexMap class_map_;
  ObjectIndexMap constants_;
  ObjectIndexMap static_methods_;

  SelectorRowMap selector_rows_;
  int linear_size_;
};

void Program::FoldFunction(Function* old_function,
                           Function* new_function,
                           ProgramTableRewriter* rewriter) {
  uint8_t* start = old_function->bytecode_address_for(0);
  uint8_t* bcp = start;
  uint8_t* new_start = new_function->bytecode_address_for(0);

  while (true) {
    Opcode opcode = static_cast<Opcode>(*bcp);
    uint8_t* new_bcp = new_start + (bcp - start);

    switch (opcode) {
      case kLoadConstUnfold:
        rewriter->AddConstantAndRewrite(bcp, new_bcp);
        break;
      case kInvokeStaticUnfold:
      case kInvokeFactoryUnfold:
        rewriter->AddMethodAndRewrite(bcp, new_bcp);
        break;
      case kAllocateUnfold:
      case kAllocateImmutableUnfold:
        rewriter->AddClassAndRewrite(bcp, new_bcp);
        break;
      case kMethodEnd: {
        return;
      }
      case kLoadConst:
      case kInvokeStatic:
      case kInvokeFactory:
      case kAllocate:
      case kAllocateImmutable:
        // We should only fold unfolded functions.
        UNREACHABLE();
      default:
        ASSERT(opcode < Bytecode::kNumBytecodes);
        break;
    }

    bcp += Bytecode::Size(opcode);
  }

  UNREACHABLE();
}

// After folding, we have to postprocess all functions in the heap to
// adjust the bytecodes to take advantage of class ids.
class FunctionPostprocessVisitor: public HeapObjectVisitor {
 public:
  explicit FunctionPostprocessVisitor(ProgramTableRewriter* rewriter)
      : rewriter_(rewriter) { }

  virtual void Visit(HeapObject* object) {
    if (object->IsFunction()) Process(Function::cast(object));
  }

 private:
  void Process(Function* function) {
    uint8_t* bcp = function->bytecode_address_for(0);
    while (true) {
      Opcode opcode = static_cast<Opcode>(*bcp);
      switch (opcode) {
        case kAllocate:
        case kAllocateImmutable: {
          int index = Utils::ReadInt32(bcp + 1);
          Class* clazz = rewriter_->LookupClass(index);
          Utils::WriteInt32(bcp + 1, clazz->id());
          break;
        }

        case kInvokeEq:
        case kInvokeLt:
        case kInvokeLe:
        case kInvokeGt:
        case kInvokeGe:

        case kInvokeAdd:
        case kInvokeSub:
        case kInvokeMod:
        case kInvokeMul:
        case kInvokeTruncDiv:

        case kInvokeBitNot:
        case kInvokeBitAnd:
        case kInvokeBitOr:
        case kInvokeBitXor:
        case kInvokeBitShr:
        case kInvokeBitShl:

        case kInvokeTest:
        case kInvokeMethod: {
          int selector = Utils::ReadInt32(bcp + 1);
          SelectorRow* row = rewriter_->LookupSelectorRow(selector, true);
          SelectorRow::Kind kind = row->kind();
          int offset = row->offset();
          if (kind == SelectorRow::LINEAR) {
            ASSERT(offset >= 0);
            Utils::WriteInt32(bcp + 1, offset);
            *bcp = opcode + (kInvokeMethodFast - kInvokeMethod);
          } else {
            int updated = Selector::IdField::update(offset, selector);
            Utils::WriteInt32(bcp + 1, updated);
            *bcp = opcode + (kInvokeMethodVtable - kInvokeMethod);
          }
          break;
        }
        case kMethodEnd:
          return;
        default:
          ASSERT(opcode < Bytecode::kNumBytecodes);
          // Do nothing.
          break;
      }
      bcp += Bytecode::Size(opcode);
    }
    UNREACHABLE();
  }

  ProgramTableRewriter* rewriter_;
};

class FoldingVisitor: public PointerVisitor {
 public:
  FoldingVisitor(Space* from,
                 Space* to,
                 ProgramTableRewriter* rewriter,
                 Program* program)
      : from_(from),
        to_(to),
        rewriter_(rewriter),
        program_(program),
        classes_(NULL),
        class_count_(0) { }

  void Visit(Object** p) { FoldPointer(p); }

  void VisitBlock(Object** start, Object** end) {
    // Fold all HeapObject pointers in [start, end)
    for (Object** p = start; p < end; p++) FoldPointer(p);
  }

  void Finalize() {
    Object* hierarchy = ConstructClassHierarchy(classes_);
    Array* table = Array::cast(program_->CreateArray(class_count_));
    AssignClassIds(hierarchy, table, 0);
    program_->set_classes(table);

    ConstructDispatchTable(table);
    rewriter_->ProcessSelectorRows(program_);

    FunctionPostprocessVisitor visitor(rewriter_);
    program_->heap()->IterateObjects(&visitor);

    rewriter_->FinalizeSelectorRows(program_);
    program_->SetupDispatchTableIntrinsics();
  }

 private:
  void FoldPointer(Object** p) {
    Object* raw_object = *p;
    if (!raw_object->IsHeapObject()) return;
    if (!from_->Includes(reinterpret_cast<uword>(raw_object))) return;
    HeapObject* object = HeapObject::cast(raw_object);

    // Check for forwarding address before checking type.
    HeapObject* f = object->forwarding_address();
    if (f != NULL) {
      *p = f;
    } else if (object->IsFunction()) {
      // Copy over function without literals and setup forwarding
      // pointer.
      Function* old_function = Function::cast(object);
      *p = old_function->FoldInToSpace(to_);

      // Copy over the literals.
      Object** first = old_function->literal_address_for(0);
      VisitBlock(first, first + old_function->literals_size());

      // Rewrite the bytecodes of the new function.
      Function* new_function = Function::cast(*p);
      program_->FoldFunction(old_function, new_function, rewriter_);
    } else {
      // Clone the heap object in to-space, but check if the object
      // was a class before doing so. As part of the cloning, we install
      // a forwarding pointer in the object, which makes it impossible
      // to ask if it was a class.
      bool is_class = object->IsClass();
      HeapObject* clone = object->CloneInToSpace(to_);
      *p = clone;

      // Link all classes together so we can run through them after
      // the heap traversal.
      if (is_class) {
        Class* clazz = reinterpret_cast<Class*>(clone);
        clazz->set_link(classes_);
        clazz->set_child_link(NULL);
        classes_ = clazz;
        class_count_++;
      }
    }
  }

  // Turn the linked list of classes into a hierarchy where each class
  // has a linked list of its children.
  static Object* ConstructClassHierarchy(Object* classes) {
    Object* result = NULL;
    Object* current = classes;
    while (current != NULL) {
      Class* clazz = Class::cast(current);
      Object* next = clazz->link();
      if (clazz->has_super_class()) {
        Class* super_class = clazz->super_class();
        clazz->set_link(super_class->child_link());
        super_class->set_child_link(clazz);
      } else {
        clazz->set_link(result);
        result = clazz;
      }
      current = next;
    }
    return result;
  }

  // Assign class ids with a depth-first numbering so that all subclasses
  // of a given class have ids in the half-open interval [id, child-id).
  static int AssignClassIds(Object* classes, Array* table, int id) {
    Object* current = classes;
    while (current != NULL) {
      Class* clazz = Class::cast(current);
      Object* next = clazz->link();
      clazz->set_id(id++);
      table->set(clazz->id(), clazz);
      id = AssignClassIds(clazz->child_link(), table, id);
      clazz->set_child_id(id);
      current = next;
    }
    return id;
  }

  void ConstructDispatchTable(Array* table) {
    // Run through all classes in post order depth first.
    for (int i = table->length() - 1; i >= 0; i--) {
      Class* clazz = Class::cast(table->get(i));
      ASSERT(clazz->id() == i);
      DefineMethods(clazz);
    }
  }

  void DefineMethods(Class* clazz) {
    if (!clazz->has_methods()) return;
    Array* methods = clazz->methods();
    for (int i = 0, length = methods->length(); i < length; i += 2) {
      int selector = Smi::cast(methods->get(i))->value();
      Function* method = Function::cast(methods->get(i + 1));
      SelectorRow* row = rewriter_->LookupSelectorRow(selector, false);
      row->DefineMethod(clazz, method);
    }
  }

  Space* from_;
  Space* to_;
  ProgramTableRewriter* rewriter_;
  Program* program_;

  Object* classes_;
  int class_count_;
};

void Program::Fold() {
  // TODO(ager): Can we add an assert that there are no processes running
  // for this program. Either because we haven't enqueued any or because
  // the program is stopped?
  ASSERT(!is_compact());

  // List of processes that are only referenced by ports floating
  // around in the system.
  Process* all_processes = NULL;
  PrepareProgramGC(&all_processes);

  ProgramTableRewriter rewriter;
  Space* to = new Space();
  FoldingVisitor visitor(heap_.space(), to, &rewriter, this);
  PerformProgramGC(to, &visitor, all_processes);

  {
    NoAllocationFailureScope scope(to);
    visitor.Finalize();
    constants_ = rewriter.CreateConstantArray(this);
    static_methods_ = rewriter.CreateStaticMethodArray(this);
  }

  is_compact_ = true;

  FinishProgramGC(&all_processes);
}

Process* Program::SpawnProcess() {
  return new Process(this);
}

Process* Program::ProcessSpawnForMain() {
  // For testing purposes, we support unfolding the program
  // before running it.
  bool unfold = Flags::unfold_program;
  if (is_compact()) {
    if (unfold) Unfold();
  } else if (!unfold) {
    Fold();
  }
  ASSERT(is_compact() == !unfold);

  if (Flags::print_program_statistics) {
    PrintStatistics();
  }

#ifdef DEBUG
  // TODO(ager): GC for testing only.
  CollectGarbage();
#endif

  ASSERT(scheduler() != NULL);

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

Object* Program::CreateArrayWith(int capacity, Object* initial_value) {
  Object* result = heap()->CreateArray(
      array_class(), capacity, initial_value, false);
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

void Program::PrepareProgramGC(Process** all_processes) {
  LinkProcessesForGc process_linker(all_processes);

  // Discover all processes and link them.
  {
    scheduler()->VisitProcesses(this, &process_linker);
    if (session_ != NULL) session_->VisitProcesses(&process_linker);
    process_linker.Finish();
  }

  if (Flags::validate_heaps) {
    ValidateGlobalHeapsAreConsistent();
  }

  // Make sure that the number of processes we find equals to the number
  // of processes the scheduler knows about.
  //
  // WARNING: This assert assumes we execute only one program and that
  // program has been stopped.
  ASSERT(scheduler()->process_count() == process_linker.process_count());

  // Loop over all processes and cook all stacks.
  {
    Process* current = *all_processes;
    while (current != NULL) {
      ASSERT(current->program_gc_state() == Process::kProcessed);

      if (Flags::validate_heaps) {
        current->ValidateHeaps();
      }

      int number_of_stacks = current->CollectGarbageAndChainStacks();
      current->CookStacks(number_of_stacks);
      current = current->program_gc_next();
    }
  }
}

void Program::PerformProgramGC(Space* to,
                               PointerVisitor* visitor,
                               Process* all_processes) {
  {
    NoAllocationFailureScope scope(to);

    // Iterate program roots.
    IterateRoots(visitor);

    // Iterate over all process program pointers.
    {
      Process* current = all_processes;
      while (current != NULL) {
        current->IterateProgramPointers(visitor);
        current = current->program_gc_next();
      }
    }

    // Finish collection.
    ASSERT(!to->is_empty());
    to->CompleteScavenge(visitor);
  }
  heap_.ReplaceSpace(to);
}

void Program::FinishProgramGC(Process** all_processes) {
  Process* current = *all_processes;
  while (current != NULL) {
    ASSERT(current->program_gc_state() == Process::kProcessed);

    // Uncook process
    current->UncookAndUnchainStacks();
    current->UpdateBreakpoints();

    if (Flags::validate_heaps) {
      current->ValidateHeaps();
    }

    // Unlink the process.
    Process* next = current->program_gc_next();
    current->set_program_gc_state(Process::kUnknown);
    current->set_program_gc_next(NULL);
    current = next;
  }

  if (Flags::validate_heaps) {
    ValidateGlobalHeapsAreConsistent();
  }

  *all_processes = NULL;
}

void Program::ValidateGlobalHeapsAreConsistent() {
  ProgramHeapPointerValidator validator(heap());
  HeapObjectPointerVisitor visitor(&validator);
  IterateRoots(&validator);
  heap()->IterateObjects(&visitor);
}

void Program::CollectGarbage() {
  // If there is no scheduler or we fail to stop the program we just
  // bail.
  // TODO(ager): Would it make sense to make StopProgram blocking
  // until it can stop the program?
  if (scheduler() == NULL) return;
  if (!scheduler()->StopProgram(this)) return;

  Space* to = new Space();
  ScavengeVisitor scavenger(heap_.space(), to);

  Process* all_processes = NULL;
  PrepareProgramGC(&all_processes);
  PerformProgramGC(to, &scavenger, all_processes);
  FinishProgramGC(&all_processes);

  scheduler()->ResumeProgram(this);
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
  printf("Program\n");
  printf("  - size = %d bytes\n", heap_.space()->Used());
  printf("  - objects = %d\n", statistics.object_count());
  printf("  Classes\n");
  printf("    - count = %d\n", statistics.class_count());
  printf("  Arrays\n");
  printf("    - count = %d\n", statistics.array_count());
  printf("    - size = %d bytes\n", statistics.array_size());
  printf("  Strings\n");
  printf("    - count = %d\n", statistics.string_count());
  printf("    - size = %d bytes\n", statistics.string_size());
  printf("  Functions\n");
  printf("    - count = %d\n", statistics.function_count());
  printf("    - size = %d bytes\n", statistics.function_size());
  printf("    - header size = %d bytes\n", statistics.function_header_size());
  printf("    - bytecode size = %d bytes\n", statistics.bytecode_size());
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
    InstanceFormat format =
        InstanceFormat::instance_format(2, InstanceFormat::FOREIGN_MARKER);
    foreign_class_ = Class::cast(
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

bool Program::ProcessRun(Process* process) {
  scheduler()->EnqueueProcess(process);
  return scheduler()->Run();
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
    printf("Dispatch table fill: %F%% (%i of %i)\n",
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
    printf("Vtable fill: %F%% (%i of %i)\n",
           hits * 100.0 / length,
           hits,
           length);
  }
}

}  // namespace fletch
