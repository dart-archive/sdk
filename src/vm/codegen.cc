// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>

#include "include/fletch_api.h"

#include "src/shared/bytecodes.h"
#include "src/shared/flags.h"
#include "src/shared/selectors.h"

#include "src/vm/assembler.h"
#include "src/vm/codegen.h"
#include "src/vm/program_info_block.h"

namespace fletch {

class DumpVisitor : public HeapObjectVisitor {
 public:
  virtual int Visit(HeapObject* object) {
    printf("O%08x:\n", object->address());
    DumpReference(object->get_class());
    if (object->IsClass()) {
      DumpClass(Class::cast(object));
    } else if (object->IsFunction()) {
      DumpFunction(Function::cast(object));
    } else if (object->IsInstance()) {
      DumpInstance(Instance::cast(object));
    } else if (object->IsOneByteString()) {
      DumpOneByteString(OneByteString::cast(object));
    } else if (object->IsArray()) {
      DumpArray(Array::cast(object));
    } else if (object->IsLargeInteger()) {
      DumpLargeInteger(LargeInteger::cast(object));
    } else if (object->IsInitializer()) {
      DumpInitializer(Initializer::cast(object));
    } else if (object->IsDispatchTableEntry()) {
      DumpDispatchTableEntry(DispatchTableEntry::cast(object));
    } else {
      printf("\t// not handled yet %d!\n", object->format().type());
    }

    return object->Size();
  }

  void DumpReference(Object* object) {
    if (object->IsHeapObject()) {
      printf("\t.long O%08x + 1\n", HeapObject::cast(object)->address());
    } else {
      printf("\t.long 0x%08x\n", object);
    }
  }

 private:
  void DumpClass(Class* clazz) {
    int size = clazz->AllocationSize();
    for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
      DumpReference(clazz->at(offset));
    }
  }

  void DumpFunction(Function* function) {
    int size = Function::kSize;
    for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
      DumpReference(function->at(offset));
    }

    for (int o = 0; o < function->bytecode_size(); o += kPointerSize) {
      printf("\t.long 0x%08x\n", *reinterpret_cast<uword*>(function->bytecode_address_for(o)));
    }

    for (int i = 0; i < function->literals_size(); i++) {
      DumpReference(function->literal_at(i));
    }
  }

  void DumpInstance(Instance* instance) {
    int size = instance->Size();
    for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
      DumpReference(instance->at(offset));
    }
  }

  void DumpOneByteString(OneByteString* string) {
    int size = OneByteString::kSize;
    for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
      DumpReference(string->at(offset));
    }

    for (int o = size; o < string->StringSize(); o += kPointerSize) {
      printf("\t.long 0x%08x\n", *reinterpret_cast<uword*>(string->byte_address_for(o - size)));
    }
  }

  void DumpArray(Array* array) {
    int size = array->Size();
    for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
      DumpReference(array->at(offset));
    }
  }

  void DumpLargeInteger(LargeInteger* large) {
    uword* ptr = reinterpret_cast<uword*>(large->address() + LargeInteger::kValueOffset);
    printf("\t.long 0x%08x\n", ptr[0]);
    printf("\t.long 0x%08x\n", ptr[1]);
  }

  void DumpInitializer(Initializer* initializer) {
    int size = initializer->Size();
    for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
      DumpReference(initializer->at(offset));
    }
  }

  void DumpDispatchTableEntry(DispatchTableEntry* entry) {
    DumpReference(entry->target());
    printf("\t.long Function_%08x\n", entry->target());
    DumpReference(entry->offset());
    printf("\t.long 0x%08x\n", entry->selector());
  }
};

void DumpProgram(Program* program) {
  DumpVisitor visitor;

  printf("\n\n\t// Program space = %d bytes\n", program->heap()->space()->Used());
  printf("\t.section .rodata\n\n");

  printf("\t.global program_start\n");
  printf("\t.p2align 12\n");
  printf("program_start:\n");

  program->heap()->space()->IterateObjects(&visitor);

  printf("\t.global program_end\n");
  printf("\t.p2align 12\n");
  printf("program_end:\n\n\n");

  ProgramInfoBlock* block = new fletch::ProgramInfoBlock();
  block->PopulateFromProgram(program);
  printf("\t.global program_info_block\n");
  printf("program_info_block:\n");

  for (Object** r = block->roots(); r < block->end_of_roots(); r++) {
    visitor.DumpReference(*r);
  }
  printf("\t.long 0x%08x\n", block->main_arity());

  delete block;
}


class CodegenVisitor : public HeapObjectVisitor {
 public:
  CodegenVisitor(Codegen* codegen) : codegen_(codegen) { }

  virtual int Visit(HeapObject* object) {
    if (object->IsFunction()) {
      codegen_->Generate(Function::cast(object));
    }
    return object->Size();
  }

 private:
  Codegen* const codegen_;
};

static int Main(int argc, char** argv) {
  Flags::ExtractFromCommandLine(&argc, argv);

  if (argc != 3) {
    fprintf(stderr, "Usage: %s <snapshot> <output file name>\n", argv[0]);
    exit(1);
  }

  if (freopen(argv[2], "w", stdout) == NULL) {
    fprintf(stderr, "%s: Cannot open '%s' for writing.\n", argv[0], argv[2]);
    exit(1);
  }

  printf("\t.text\n\n");

  FletchSetup();
  FletchProgram api_program = FletchLoadSnapshotFromFile(argv[1]);

  Assembler assembler;
  Program* program = reinterpret_cast<Program*>(api_program);
  Codegen codegen(program, &assembler);
  CodegenVisitor visitor(&codegen);
  program->heap()->IterateObjects(&visitor);
  codegen.GenerateHelpers();

  DumpProgram(program);

  FletchDeleteProgram(api_program);
  FletchTearDown();
  return 0;
}

void Codegen::Generate(Function* function) {
  function_ = function;
  DoEntry();

  IntrinsicsTable* intrinsics = IntrinsicsTable::GetDefault();
  Intrinsic intrinsic = function_->ComputeIntrinsic(intrinsics);
  switch (intrinsic) {
    case kIntrinsicGetField: {
      uint8* bcp = function_->bytecode_address_for(2);
      DoIntrinsicGetField(*bcp);
      return;
    }

    case kIntrinsicSetField: {
      uint8* bcp = function_->bytecode_address_for(3);
      DoIntrinsicSetField(*bcp);
      return;
    }

    case kIntrinsicListLength: {
      DoIntrinsicListLength();
      return;
    }

    case kIntrinsicListIndexGet: {
      DoIntrinsicListIndexGet();
      break;
    }

    case kIntrinsicListIndexSet: {
      DoIntrinsicListIndexSet();
      break;
    }

    default: break;
  }

  DoSetupFrame();

  int bci = 0;
  while (bci < function_->bytecode_size()) {
    uint8* bcp = function_->bytecode_address_for(bci);
    Opcode opcode = static_cast<Opcode>(*bcp);
    if (opcode == kMethodEnd) {
      printf("\n");
      return;
    }

    printf("%u: // ", reinterpret_cast<uint32>(bcp));
    Bytecode::Print(bcp);
    printf("\n");

    switch (opcode) {
      case kLoadLocal0:
      case kLoadLocal1:
      case kLoadLocal2:
      case kLoadLocal3:
      case kLoadLocal4:
      case kLoadLocal5: {
        DoLoadLocal(opcode - kLoadLocal0);
        break;
      }

      case kLoadLocal: {
        DoLoadLocal(*(bcp + 1));
        break;
      }

      case kLoadLocalWide: {
        DoLoadLocal(Utils::ReadInt32(bcp + 1));
        break;
      }

      case kLoadField: {
        DoLoadField(*(bcp + 1));
        break;
      }

      case kLoadFieldWide: {
        DoLoadField(Utils::ReadInt32(bcp + 1));
        break;
      }

      case kLoadStatic: {
        DoLoadStatic(Utils::ReadInt32(bcp + 1));
        break;
      }

      case kLoadStaticInit: {
        DoLoadStaticInit(Utils::ReadInt32(bcp + 1));
        break;
      }

      case kStoreLocal: {
        DoStoreLocal(*(bcp + 1));
        break;
      }

      case kStoreField: {
        DoStoreField(*(bcp + 1));
        break;
      }

      case kStoreFieldWide: {
        DoStoreField(Utils::ReadInt32(bcp + 1));
        break;
      }

      case kStoreStatic: {
        DoStoreStatic(Utils::ReadInt32(bcp + 1));
        break;
      }

      case kLoadLiteralNull: {
        DoLoadProgramRoot(Program::kNullObjectOffset);
        break;
      }

      case kLoadLiteralTrue: {
        DoLoadProgramRoot(Program::kTrueObjectOffset);
        break;
      }

      case kLoadLiteralFalse: {
        DoLoadProgramRoot(Program::kFalseObjectOffset);
        break;
      }

      case kLoadLiteral0:
      case kLoadLiteral1: {
        DoLoadInteger(opcode - kLoadLiteral0);
        break;
      }

      case kLoadLiteral: {
        DoLoadInteger(*(bcp + 1));
        break;
      }

      case kLoadLiteralWide: {
        DoLoadInteger(Utils::ReadInt32(bcp + 1));
        break;
      }

      case kLoadConst: {
        DoLoadConstant(bci, Utils::ReadInt32(bcp + 1));
        break;
      }

      case kBranchWide: {
        DoBranch(BRANCH_ALWAYS, bci, bci + Utils::ReadInt32(bcp + 1));
        break;
      }

      case kBranchIfTrueWide: {
        DoBranch(BRANCH_IF_TRUE, bci, bci + Utils::ReadInt32(bcp + 1));
        break;
      }

      case kBranchIfFalseWide: {
        DoBranch(BRANCH_IF_FALSE, bci, bci + Utils::ReadInt32(bcp + 1));
        break;
      }

      case kBranchBack: {
        DoStackOverflowCheck(0);
        DoBranch(BRANCH_ALWAYS, bci, bci - *(bcp + 1));
        break;
      }

      case kBranchBackIfTrue: {
        DoStackOverflowCheck(0);
        DoBranch(BRANCH_IF_TRUE, bci, bci - *(bcp + 1));
        break;
      }

      case kBranchBackIfFalse: {
        DoStackOverflowCheck(0);
        DoBranch(BRANCH_IF_FALSE, bci, bci - *(bcp + 1));
        break;
      }

      case kBranchBackWide: {
        DoStackOverflowCheck(0);
        DoBranch(BRANCH_ALWAYS, bci, bci - Utils::ReadInt32(bcp + 1));
        break;
      }

      case kBranchBackIfTrueWide: {
        DoStackOverflowCheck(0);
        DoBranch(BRANCH_IF_TRUE, bci, bci - Utils::ReadInt32(bcp + 1));
        break;
      }

      case kBranchBackIfFalseWide: {
        DoStackOverflowCheck(0);
        DoBranch(BRANCH_IF_FALSE, bci, bci - Utils::ReadInt32(bcp + 1));
        break;
      }

      case kPopAndBranchWide: {
        DoDrop(*(bcp + 1));
        DoBranch(BRANCH_ALWAYS, bci, bci + Utils::ReadInt32(bcp + 2));
        break;
      }

      case kPopAndBranchBackWide: {
        DoStackOverflowCheck(0);
        DoDrop(*(bcp + 1));
        DoBranch(BRANCH_ALWAYS, bci, bci - Utils::ReadInt32(bcp + 2));
        break;
      }

      case kInvokeEq:
      case kInvokeLe:
      case kInvokeGt:
      case kInvokeGe:

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

      case kInvokeMethod: {
        int selector = Utils::ReadInt32(bcp + 1);
        int arity = Selector::ArityField::decode(selector);
        int offset = Selector::IdField::decode(selector);
        DoInvokeMethod(arity, offset);
        break;
      }

      case kInvokeTest: {
        int selector = Utils::ReadInt32(bcp + 1);
        int offset = Selector::IdField::decode(selector);
        DoInvokeTest(offset);
        break;
      }

      case kInvokeAdd: {
        int selector = Utils::ReadInt32(bcp + 1);
        int offset = Selector::IdField::decode(selector);
        ASSERT(add_offset_ == -1 || add_offset_ == offset);
        add_offset_ = offset;
        DoInvokeAdd();
        break;
      }

      case kInvokeLt: {
        DoInvokeLt();
        break;
      }

      case kInvokeStatic:
      case kInvokeFactory: {
        int offset = Utils::ReadInt32(bcp + 1);
        Function* target = Function::cast(Function::ConstantForBytecode(bcp));
        DoInvokeStatic(bci, offset, target);
        break;
      }

      case kInvokeNative: {
        int arity = *(bcp + 1);
        Native native = static_cast<Native>(*(bcp + 2));
        DoInvokeNative(native, arity);
        break;
      }

      case kPop: {
        DoDrop(1);
        break;
      }

      case kDrop: {
        DoDrop(*(bcp + 1));
        break;
      }

      case kReturn: {
        DoReturn();
        break;
      }

      case kReturnNull: {
        DoLoadProgramRoot(Program::kNullObjectOffset);
        DoReturn();
        break;
      }

      case kAllocate:
      case kAllocateImmutable: {
        Class* klass = Class::cast(Function::ConstantForBytecode(bcp));
        DoAllocate(klass);
        break;
      }

      case kNegate: {
        DoNegate();
        break;
      }

      case kIdentical: {
        DoIdenticalNonNumeric();
        break;
      }

      case kIdenticalNonNumeric: {
        DoIdenticalNonNumeric();
        break;
      }

      case kProcessYield: {
        DoProcessYield();
        break;
      }

      default: {
        printf("\tint3\n");
        break;
      }
    }

    bci += Bytecode::Size(opcode);
  }
}

}  // namespace fletch

// Forward main calls to fletch::Main.
int main(int argc, char** argv) {
  return fletch::Main(argc, argv);
}
