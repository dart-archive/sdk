// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifdef FLETCH_ENABLE_LIVE_CODING

#include "src/vm/program_folder.h"

#include "src/shared/bytecodes.h"
#include "src/shared/flags.h"
#include "src/shared/names.h"
#include "src/shared/selectors.h"

#include "src/vm/hash_map.h"
#include "src/vm/heap.h"
#include "src/vm/program.h"
#include "src/vm/selector_row.h"
#include "src/vm/vector.h"

namespace fletch {

typedef HashMap<Object*, int> ObjectIndexMap;
typedef HashMap<intptr_t, SelectorRow*> SelectorRowMap;
typedef HashMap<intptr_t, int> SelectorOffsetMap;

static int AddToMap(ObjectIndexMap* map, Object* value) {
  ObjectIndexMap::ConstIterator it = map->Find(value);
  if (it != map->End()) {
    return it->second;
  } else {
    int index = map->size();
    map->Insert({value, index});
    return index;
  }
}

static Array* MapToArray(ObjectIndexMap* map, Program* program) {
  Array* result = Array::cast(program->CreateArray(map->size()));
  ObjectIndexMap::ConstIterator it = map->Begin();
  ObjectIndexMap::ConstIterator end = map->End();
  for (; it != end; ++it) result->set(it->second, it->first);
  return result;
}

class ProgramTableRewriter {
 public:
  ~ProgramTableRewriter() {
    SelectorRowMap::ConstIterator it = selector_rows_.Begin();
    SelectorRowMap::ConstIterator end = selector_rows_.End();
    for (; it != end; ++it) delete it->second;
  }

  int ClassCount() const { return class_vector_.size(); }

  Class* LookupClass(int index) {
    return class_vector_[index];
  }

  SelectorRow* LookupSelectorRow(int selector) {
    SelectorRow*& entry = selector_rows_[selector];
    if (entry == NULL) {
      entry = new SelectorRow(selector);
    }
    return entry;
  }

  void ProcessSelectorRows(Program* program) {
    SelectorRowMap::ConstIterator it;
    SelectorRowMap::ConstIterator end = selector_rows_.End();

    // Compute the sizes of the dispatch tables.
    Vector<SelectorRow*> table_rows;
    for (it = selector_rows_.Begin(); it != end; ++it) {
      SelectorRow* row = it->second;
      if (row->IsMatched()) {
        row->Finalize();
        table_rows.PushBack(row);
      }
    }

    // Sort the table rows according to size.
    if (table_rows.size() == 0) return;
    table_rows.Sort(SelectorRow::Compare);

    // We add a fake header entry at the start of the dispatch table to deal
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

    // Allocate the dispatch table and fill it in.
    Array* table = Array::cast(program->CreateArray(table_size));
    for (unsigned i = 0; i < table_rows.size(); i++) {
      table_rows[i]->FillTable(program, table);
    }

    // Simplify how we deal with noSuchMethod in the interpreter
    // by explicitly replacing all unused entries in the dispatch table with
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

    program->set_dispatch_table(table);
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
      class_vector_.PushBack(clazz);
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
    *new_bcp = *new_bcp - Bytecode::kUnfoldOffset;
    Utils::WriteInt32(new_bcp + 1, new_index);
    return new_index;
  }

  ClassVector class_vector_;
  ObjectIndexMap class_map_;
  ObjectIndexMap constants_;
  ObjectIndexMap static_methods_;

  SelectorRowMap selector_rows_;
};

// After folding, we have to postprocess all functions in the heap to
// adjust the bytecodes to take advantage of class ids.
class FunctionPostprocessVisitor: public HeapObjectVisitor {
 public:
  explicit FunctionPostprocessVisitor(ProgramTableRewriter* rewriter)
      : rewriter_(rewriter) { }

  virtual int Visit(HeapObject* object) {
    int size = object->Size();
    if (object->IsFunction()) Process(Function::cast(object));
    return size;
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

        case kInvokeEqUnfold:
        case kInvokeLtUnfold:
        case kInvokeLeUnfold:
        case kInvokeGtUnfold:
        case kInvokeGeUnfold:

        case kInvokeAddUnfold:
        case kInvokeSubUnfold:
        case kInvokeModUnfold:
        case kInvokeMulUnfold:
        case kInvokeTruncDivUnfold:

        case kInvokeBitNotUnfold:
        case kInvokeBitAndUnfold:
        case kInvokeBitOrUnfold:
        case kInvokeBitXorUnfold:
        case kInvokeBitShrUnfold:
        case kInvokeBitShlUnfold:

        case kInvokeTestUnfold:
        case kInvokeMethodUnfold: {
          int selector = Utils::ReadInt32(bcp + 1);
          SelectorRow* row = rewriter_->LookupSelectorRow(selector);
          if (row->IsMatched()) {
            int offset = row->offset();
            int updated = Selector::IdField::update(offset, selector);
            Utils::WriteInt32(bcp + 1, updated);
            *bcp = opcode - Bytecode::kUnfoldOffset;
          } else if (opcode == kInvokeTestUnfold) {
            *bcp = kInvokeTestNoSuchMethod;
          } else {
            ASSERT(opcode == kInvokeMethodUnfold);
            *bcp = kInvokeNoSuchMethod;
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
                 ProgramFolder* program_folder)
      : from_(from),
        to_(to),
        rewriter_(rewriter),
        program_folder_(program_folder),
        classes_(NULL),
        class_count_(0) { }

  void Visit(Object** p) { FoldPointer(p); }

  void VisitBlock(Object** start, Object** end) {
    // Fold all HeapObject pointers in [start, end)
    for (Object** p = start; p < end; p++) FoldPointer(p);
  }

  void Finalize() {
    Object* hierarchy = ConstructClassHierarchy(classes_);
    Array* table = Array::cast(program()->CreateArray(class_count_));
    AssignClassIds(hierarchy, table, 0);
    program()->set_classes(table);

    ConstructDispatchTable(table);
    rewriter_->ProcessSelectorRows(program());

    FunctionPostprocessVisitor visitor(rewriter_);
    program()->heap()->IterateObjects(&visitor);

    program()->SetupDispatchTableIntrinsics();
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
      program_folder_->FoldFunction(old_function, new_function, rewriter_);
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
      SelectorRow* row = rewriter_->LookupSelectorRow(selector);
      row->DefineMethod(clazz, method);
    }
  }

  Program* program() const { return program_folder_->program(); }

  Space* from_;
  Space* to_;
  ProgramTableRewriter* rewriter_;
  ProgramFolder* program_folder_;

  Object* classes_;
  int class_count_;
};


void ProgramFolder::Fold(bool disable_heap_validation_before_gc) {
  // TODO(ager): Can we add an assert that there are no processes running
  // for this program. Either because we haven't enqueued any or because
  // the program is stopped?
  ASSERT(!program_->is_compact());

  program_->PrepareProgramGC(disable_heap_validation_before_gc);

  ProgramTableRewriter rewriter;
  Space* to = new Space();
  FoldingVisitor visitor(program_->heap()->space(), to, &rewriter, this);
  program_->PerformProgramGC(to, &visitor);

  {
    NoAllocationFailureScope scope(to);
    visitor.Finalize();
    program_->set_constants(rewriter.CreateConstantArray(program_));
    program_->set_static_methods(rewriter.CreateStaticMethodArray(program_));
  }

  program_->set_is_compact(true);

  program_->FinishProgramGC();
}

void ProgramFolder::FoldFunction(Function* old_function,
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
        ASSERT(!Bytecode::IsInvoke(opcode));
        ASSERT(opcode < Bytecode::kNumBytecodes);
        break;
    }

    bcp += Bytecode::Size(opcode);
  }

  UNREACHABLE();
}

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
    *bcp = *bcp + Bytecode::kUnfoldOffset;
    Utils::WriteInt32(bcp + 1, offset);
  }

  int NumberOfLiterals() { return literals_index_map_.size(); }

  void FillInLiterals(Function* function) {
    ObjectIndexMap::ConstIterator it = literals_index_map_.Begin();
    ObjectIndexMap::ConstIterator end = literals_index_map_.End();
    for (; it != end; ++it) function->set_literal_at(it->second, it->first);
  }

 private:
  Function* function_;
  ObjectIndexMap literals_index_map_;
};

Object* ProgramFolder::UnfoldFunction(Function* function,
                                      Space* to,
                                      void* raw_map) {
  SelectorOffsetMap* map = static_cast<SelectorOffsetMap*>(raw_map);
  LiteralsRewriter rewriter(to, function);

  uint8_t* bcp = function->bytecode_address_for(0);

  while (true) {
    Opcode opcode = static_cast<Opcode>(*bcp);

    switch (opcode) {
      case kLoadConst:
        rewriter.AddLiteralAndRewrite(program_->constants(), bcp);
        break;
      case kInvokeStatic:
      case kInvokeFactory:
        rewriter.AddLiteralAndRewrite(program_->static_methods(), bcp);
        break;
      case kAllocate:
      case kAllocateImmutable:
        rewriter.AddLiteralAndRewrite(program_->classes(), bcp);
        break;

      case kInvokeNoSuchMethod:
        *bcp = kInvokeMethodUnfold;
        break;

      case kInvokeTestNoSuchMethod:
        *bcp = kInvokeTestUnfold;
        break;

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
        int offset = Selector::IdField::decode(Utils::ReadInt32(bcp + 1));
        int selector = map->At(offset);
        *bcp = opcode + Bytecode::kUnfoldOffset;
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
        ASSERT(!Bytecode::IsInvokeUnfold(opcode));
        ASSERT(opcode < Bytecode::kNumBytecodes);
        break;
    }

    ASSERT(!Bytecode::IsInvoke(static_cast<Opcode>(*bcp)));
    bcp += Bytecode::Size(opcode);
  }

  UNREACHABLE();
  return NULL;
}

class UnfoldingVisitor: public PointerVisitor {
 public:
  UnfoldingVisitor(ProgramFolder* program_folder,
                   Space* from,
                   Space* to,
                   SelectorOffsetMap* map)
      : program_folder_(program_folder),
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
      *p = program_folder_->UnfoldFunction(Function::cast(object), to_, map_);
    } else {
      *p = reinterpret_cast<HeapObject*>(object)->CloneInToSpace(to_);
    }
  }

  ProgramFolder* program_folder_;
  Space* from_;
  Space* to_;
  SelectorOffsetMap* map_;
};

void ProgramFolder::Unfold() {
  // TODO(ager): Can we add an assert that there are no processes running
  // for this program. Either because we haven't enqueued any or because
  // the program is stopped?
  ASSERT(program_->is_compact());

  // Run through the dispatch table and compute a map from selector offsets
  // to the original selectors. This is used when rewriting the
  // bytecodes back to the original invoke-method bytecodes.
  SelectorOffsetMap map;
  Array* dispatch_table = program_->dispatch_table();
  if (dispatch_table != NULL) {
    for (int i = 0, length = dispatch_table->length(); i < length; i++) {
      Object* element = dispatch_table->get(i);
      if (element->IsNull()) continue;
      Array* entry = Array::cast(element);
      int offset = Smi::cast(entry->get(0))->value();
      int selector = Smi::cast(entry->get(1))->value();
      ASSERT(map.Count(offset) == 0 || map[offset] == selector);
      map[offset] = selector;
    }
  }


  program_->PrepareProgramGC();
  Space* to = new Space();
  UnfoldingVisitor visitor(this, program_->heap()->space(), to, &map);
  program_->PerformProgramGC(to, &visitor);

  program_->set_classes(NULL);
  program_->set_constants(NULL);
  program_->set_static_methods(NULL);
  program_->set_dispatch_table(NULL);
  program_->set_is_compact(false);

  program_->FinishProgramGC();
}

void ProgramFolder::FoldProgramByDefault(Program* program) {
  // For testing purposes, we support unfolding the program
  // before running it.
  bool unfold = Flags::unfold_program;
  ProgramFolder program_folder(program);
  if (program->is_compact()) {
    if (unfold) {
      program_folder.Unfold();
    }
  } else if (!unfold) {
    program_folder.Fold();
  }
  ASSERT(program->is_compact() == !unfold);
}

}  // namespace fletch

#endif  // FLETCH_ENABLE_LIVE_CODING
