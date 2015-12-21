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

typedef HashMap<intptr_t, SelectorRow*> SelectorRowMap;
typedef HashMap<intptr_t, int> SelectorOffsetMap;

class ProgramRewriter {
 public:
  ~ProgramRewriter() {
    SelectorRowMap::ConstIterator it = selector_rows_.Begin();
    SelectorRowMap::ConstIterator end = selector_rows_.End();
    for (; it != end; ++it) delete it->second;
  }

  SelectorRow* LookupSelectorRow(int selector) {
    SelectorRow*& entry = selector_rows_[selector];
    if (entry == NULL) {
      entry = new SelectorRow(selector);
    }
    return entry;
  }

  void ProcessSelectorRows(Program* program, Vector<Class*>* classes) {
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
    int table_size = kHeaderSize + fitter.limit() + classes->size();

    // Allocate the dispatch table and fill it in.
    Array* table = Array::cast(program->CreateArray(table_size));
    for (unsigned i = 0; i < table_rows.size(); i++) {
      table_rows[i]->FillTable(program, classes, table);
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

 private:
  SelectorRowMap selector_rows_;
};

// To optimize, we post process all functions in the heap to
// adjust the bytecodes to take advantage of selector offsets
// and class ids.
class FunctionOptimizingVisitor : public HeapObjectVisitor {
 public:
  explicit FunctionOptimizingVisitor(ProgramRewriter* rewriter)
      : rewriter_(rewriter) {}

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

  ProgramRewriter* rewriter_;
};

// To deoptimize, we post process all functions in the heap to
// adjust the bytecodes to use selectors instead of selector offsets.
class FunctionDeoptimizingVisitor : public HeapObjectVisitor {
 public:
  explicit FunctionDeoptimizingVisitor(SelectorOffsetMap* map) : map_(map) {}

  virtual int Visit(HeapObject* object) {
    int size = object->Size();
    if (object->IsFunction()) Process(Function::cast(object));
    return size;
  }

 private:
  SelectorOffsetMap* const map_;

  void Process(Function* function) {
    uint8_t* bcp = function->bytecode_address_for(0);

    while (true) {
      Opcode opcode = static_cast<Opcode>(*bcp);

      switch (opcode) {
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
          int selector = map_->At(offset);
          *bcp = opcode + Bytecode::kUnfoldOffset;
          Utils::WriteInt32(bcp + 1, selector);
          break;
        }

        case kMethodEnd:
          return;

        default:
          ASSERT(!Bytecode::IsInvokeUnfold(opcode));
          ASSERT(opcode < Bytecode::kNumBytecodes);
          break;
      }

      ASSERT(!Bytecode::IsInvoke(static_cast<Opcode>(*bcp)));
      bcp += Bytecode::Size(opcode);
    }

    UNREACHABLE();
  }
};

class ClassLocatingVisitor : public HeapObjectVisitor {
 public:
  ClassLocatingVisitor() : classes_chain_(NULL), class_count_(0) {}

  virtual int Visit(HeapObject* object) {
    int size = object->Size();
    if (object->IsClass()) {
      Class* clazz = Class::cast(object);
      clazz->set_link(classes_chain_);
      clazz->set_child_link(NULL);
      classes_chain_ = clazz;
      class_count_++;
    }
    return size;
  }

  Class* class_chain() const { return classes_chain_; }
  int class_count() const { return class_count_; }

 private:
  Class* classes_chain_;
  int class_count_;
};

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
static int AssignClassIds(Object* classes, Vector<Class*>* table, int id) {
  Object* current = classes;
  while (current != NULL) {
    Class* clazz = Class::cast(current);
    Object* next = clazz->link();
    clazz->set_id(id++);
    ASSERT(table->size() == static_cast<size_t>(clazz->id()));
    table->PushBack(clazz);
    id = AssignClassIds(clazz->child_link(), table, id);
    clazz->set_child_id(id);
    current = next;
  }
  return id;
}

static void DefineMethods(Class* clazz, ProgramRewriter* rewriter) {
  if (!clazz->has_methods()) return;
  Array* methods = clazz->methods();
  for (int i = 0, length = methods->length(); i < length; i += 2) {
    int selector = Smi::cast(methods->get(i))->value();
    Function* method = Function::cast(methods->get(i + 1));
    SelectorRow* row = rewriter->LookupSelectorRow(selector);
    row->DefineMethod(clazz, method);
  }
}

static void ConstructDispatchTable(Vector<Class*>* table,
                                   ProgramRewriter* rewriter) {
  // Run through all classes in post order depth first.
  for (int i = table->size() - 1; i >= 0; i--) {
    Class* clazz = Class::cast(table->At(i));
    ASSERT(clazz->id() == i);
    DefineMethods(clazz, rewriter);
  }
}

void ProgramFolder::Fold() {
  // TODO(ager): Can we add an assert that there are no processes running
  // for this program. Either because we haven't enqueued any or because
  // the program is stopped?
  ASSERT(!program_->is_optimized());

  ClassLocatingVisitor class_locator;
  program_->heap()->IterateObjects(&class_locator);

  {
    NoAllocationFailureScope scope(program_->heap()->space());

    Object* hierarchy = ConstructClassHierarchy(class_locator.class_chain());
    Vector<Class*> table;
    AssignClassIds(hierarchy, &table, 0);

    ASSERT(class_locator.class_count() == (int)table.size());

    ProgramRewriter rewriter;
    ConstructDispatchTable(&table, &rewriter);
    rewriter.ProcessSelectorRows(program(), &table);

    FunctionOptimizingVisitor visitor(&rewriter);
    program()->heap()->IterateObjects(&visitor);

    program()->SetupDispatchTableIntrinsics();
  }
}

void ProgramFolder::Unfold() {
  // TODO(ager): Can we add an assert that there are no processes running
  // for this program. Either because we haven't enqueued any or because
  // the program is stopped?
  ASSERT(program_->is_optimized());

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
      ASSERT(map.Find(offset) == map.End() || map[offset] == selector);
      map[offset] = selector;
    }
  }

  FunctionDeoptimizingVisitor visitor(&map);
  program_->heap()->IterateObjects(&visitor);

  program_->set_dispatch_table(NULL);
}

void ProgramFolder::FoldProgramByDefault(Program* program) {
  // For testing purposes, we support unfolding the program
  // before running it.
  bool unfold = Flags::unfold_program;
  ProgramFolder program_folder(program);
  if (program->is_optimized()) {
    if (unfold) {
      program_folder.Unfold();
    }
  } else if (!unfold) {
    program_folder.Fold();
  }
  ASSERT(program->is_optimized() == !unfold);
}

}  // namespace fletch

#endif  // FLETCH_ENABLE_LIVE_CODING
