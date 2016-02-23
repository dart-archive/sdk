// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/codegen_llvm.h"

#include "src/shared/bytecodes.h"
#include "src/shared/flags.h"
#include "src/shared/names.h"
#include "src/shared/natives.h"
#include "src/shared/selectors.h"

#include "src/vm/process.h"
#include "src/vm/interpreter.h"
#include "src/vm/program_info_block.h"

#include <stdio.h>
#include <stdarg.h>

#include <iostream>
#include <set>

namespace dartino {

// This function calculates the stack difference of a specific bytecode
// instruction. It uses [Bytecode::StackDiff] for fixed stack-difference
// bytecodes and calculates the stack difference manually for all other
// bytecodes.
static int StackDiff(uint8* bcp) {
  Opcode opcode = static_cast<Opcode>(*bcp);
  int diff = Bytecode::StackDiff(opcode);
  if (diff != kVarDiff) return diff;

  switch (opcode) {
    case kInvokeMethod: {
      int selector = Utils::ReadInt32(bcp + 1);
      int arity = Selector::ArityField::decode(selector);
      // Arity = argument count + receiver
      arity += 1;
      return 1 - arity;
    }
    case kInvokeSelector: {
      // FIXME: Is this correct?
      int items = *(bcp + 1);
      ASSERT(items >= 0);
      return 1 - items;
    }
    case kInvokeFactory:
    case kInvokeStatic: {
      int arity = Function::cast(Function::ConstantForBytecode(bcp))->arity();
      return 1 - arity;
    }
    case kDrop: {
      int items = *(bcp + 1);
      ASSERT(items > 0);
      return -items;
    }
    case kAllocateImmutable:
    case kAllocate: {
      Class* klass = Class::cast(Function::ConstantForBytecode(bcp));
      int fields = klass->NumberOfInstanceFields();
      return 1 - fields;
    }
    case kEnterNoSuchMethod: {
      // FIXME: Figure out how to handle this!
      return 80;
    }
    case kSubroutineCall: {
      // FIXME: Figure out how to handle this!
      return 1;
    }
    case kPopAndBranchBackWide:
    case kPopAndBranchWide: {
      return -*(bcp + 1);
    }
    case kInvokeNoSuchMethod: {
      // FIXME: Figure out how to handle this!
      int selector = Utils::ReadInt32(bcp + 1);
      int arity = Selector::ArityField::decode(selector);
      return 1 - arity - 1;
    }
    default: {
      FATAL1("Missing stack diff for '%s'\n", bytecode_string(bcp));
      return 0;
    }
  }
}

// Makes external function delcarations for all native methods.
//
// The function names have the form: Native_<name-of-native>
// => The result is available via:  world.natives_[nativeIndex]
class NativesBuilder {
 public:
  NativesBuilder(World& world) : w(world) {}

  void BuildNativeDeclarations() {
    auto void_ptr = w.object_ptr_type;

    std::vector<llvm::Type*> argument_types = { void_ptr, w.object_ptr_ptr_type };
    auto function_type =
        llvm::FunctionType::get(w.object_ptr_type, argument_types, false);

#define N(e, c, n, d)                                                               \
    /* Make sure we push the native at the correct location in the array */           \
    ASSERT(w.natives_.size() == k##e);                                           \
    w.natives_.push_back(llvm::Function::Create(function_type,                   \
                                                     llvm::Function::ExternalLinkage, \
                                                     "Native_" #e,                    \
                                                     &w.module_));

    NATIVES_DO(N)
#undef N
  }

 private:
  World& w;
};

// Builds up constant objects for all [HeapObject]s it is called with.
class HeapBuilder : public HeapObjectVisitor {
 public:
  HeapBuilder(World& world) : w(world) { }

  virtual int Visit(HeapObject* object) {
    BuildConstant(object);
    return object->Size();
  }

 private:
  friend class BasicBlockBuilder;

  llvm::Constant* BuildConstant(Object* raw_object) {
    if (!raw_object->IsHeapObject()) {
      ASSERT(raw_object->IsSmi());
      Smi* smi = Smi::cast(raw_object);
      return w.CCast(w.CInt2Pointer(w.CSmi(smi->value())));
    }

    HeapObject* object = HeapObject::cast(raw_object);

    llvm::Constant* value = w.tagged_heap_objects[object];
    if (value != NULL) return value;

    auto ot = w.object_ptr_type;

    // TODO
    // Missing are:
    //    * Boxed
    //    * Double
    //    * Initializer
    //    * LargeInteger
    //    * BaseArray->ByteArray
    //    * BaseArray->TwoByteString
    //
    // We should not need these:
    //    * BaseArray->Stack
    //    * Instance->Coroutine
    if (object->IsFunction()) {
      value = BuildFunctionConstant(Function::cast(object));
    } else if (object->IsClass()) {
      value = BuildClassConstant(Class::cast(object));
    } else if (object->IsArray()) {
      value = BuildArrayConstant(Array::cast(object));
    } else if (object->IsInstance()) {
      value = BuildInstanceConstant(Instance::cast(object));
    } else if (object->IsDispatchTableEntry()) {
      value = BuildDispatchTableEntryConstant(DispatchTableEntry::cast(object));
    } else if (object->IsOneByteString()) {
      value = BuildOneByteStringConstant(OneByteString::cast(object));
    } else {
      auto null = llvm::ConstantStruct::getNullValue(ot);
      value = new llvm::GlobalVariable(w.module_, ot, true, llvm::GlobalValue::ExternalLinkage, null, name("Object_%p", object));
    }

    // Put tagging information on.
    w.heap_objects[object] = value;
    return w.tagged_heap_objects[object] = w.CTag(value);
  }

  llvm::Constant* BuildArrayConstant(Array* array) {
    auto klass = Class::cast(array->get_class());
    auto llvm_klass = BuildConstant(klass);

    auto ho = llvm::ConstantStruct::get(w.heap_object_type, {llvm_klass});
    auto length = w.CSmi(array->length());
    std::vector<llvm::Constant*> array_entries = {ho, length};
    auto llvm_array = llvm::ConstantStruct::get(w.array_header, array_entries);

    auto full_array_header = w.ObjectArrayType(array->length());
    std::vector<llvm::Constant*> entries;
    entries.push_back(llvm_array);
    for (int i = 0; i < array->length(); i++) {
      Object* value = array->get(i);
      if (value->IsHeapObject()) {
        entries.push_back(w.CCast(BuildConstant(value)));
      } else {
        entries.push_back(w.CCast(w.CInt2Pointer(w.CSmi(Smi::cast(value)->value()))));
      }
    }
    auto full_array = llvm::ConstantStruct::get(full_array_header, entries);
    return new llvm::GlobalVariable(w.module_, full_array_header, true, llvm::GlobalValue::ExternalLinkage, full_array, name("ArrayInstance_%p__%d", array, array->length()));
  }

  llvm::Constant* BuildClassConstant(Class* klass) {
    // TODO: Maybe find out a better way to handle `null`. Seems like we can't
    // make cycles in constants. Our cycles are at least these two:
    //   a)  MetaClass.class -> MetaClass
    //   b)  NullObject.class -> NullClass.superclass -> NullObject
    auto null = llvm::ConstantStruct::getNullValue(w.class_ptr_type);

    bool is_meta_class = klass->get_class() == klass;

    auto innerType = w.heap_object_type->getContainedType(0);
    auto llvm_klass = w.CCast(is_meta_class ? null : BuildConstant(klass->get_class()), innerType);
    auto ho = llvm::ConstantStruct::get(w.heap_object_type, {llvm_klass});

    bool is_root = !klass->has_super_class();
    bool has_methods = klass->has_methods();

    std::vector<llvm::Constant*> class_entries = {
      ho, // heap object
      is_root ? w.CCast(null, w.class_ptr_type)
              : BuildConstant(klass->super_class()),
      BuildInstanceFormat(klass),
      w.CSmi(klass->id()),
      w.CSmi(klass->child_id()),
      has_methods ? w.CCast(BuildConstant(klass->methods()), w.array_header_ptr)
                  : w.CCast(null, w.array_header_ptr),
    };

    auto llvm_class = llvm::ConstantStruct::get(w.class_type, class_entries);
    return new llvm::GlobalVariable(w.module_, w.class_type, true, llvm::GlobalValue::ExternalLinkage, llvm_class, name("Class_%p", klass));
  }

  llvm::Constant* BuildFunctionConstant(Function* function) {
    auto type = w.FunctionType(function->arity());
    auto llvm_function = llvm::Function::Create(type, llvm::Function::ExternalLinkage, name("Function_%p", function), &w.module_);
    w.llvm_functions[function] = llvm_function;

    auto ho = llvm::ConstantStruct::get(w.heap_object_type, {BuildConstant(function->get_class())});

    std::vector<llvm::Constant*> function_entries = {
      ho, // heap object
      w.CSmi(4), // bytecode size
      w.CSmi(0), // literals size
      w.CSmi(function->arity()),
      w.CPointer2Int(llvm_function), // [word] containing function pointer.
    };

    auto function_object = llvm::ConstantStruct::get(w.function_type, function_entries);
    return new llvm::GlobalVariable(w.module_, w.function_type, true, llvm::GlobalValue::ExternalLinkage, function_object, name("FunctionObject_%p", function));
  }

  llvm::Constant* BuildInstanceConstant(Instance* instance) {
    auto ho = llvm::ConstantStruct::get(w.heap_object_type, {BuildConstant(instance->get_class())});
    auto inst = llvm::ConstantStruct::get(w.instance_type, {ho, w.CInt(instance->FlagsBits())});

    int nof = instance->get_class()->NumberOfInstanceFields();

    auto full_inst_type = w.InstanceType(nof);
    std::vector<llvm::Constant*> instance_entries = { inst };
    for (int i = 0; i < nof; i++) {
      instance_entries.push_back(w.CCast(BuildConstant(instance->GetInstanceField(i))));
    }

    auto full_inst = llvm::ConstantStruct::get(full_inst_type, instance_entries);
    return new llvm::GlobalVariable(w.module_, full_inst_type, true, llvm::GlobalValue::ExternalLinkage, full_inst, name("InstanceObject_%p__%d", instance, nof));
  }

  llvm::Constant* BuildDispatchTableEntryConstant(DispatchTableEntry* entry) {
    auto ho = llvm::ConstantStruct::get(w.heap_object_type, {BuildConstant(entry->get_class())});

    auto target = BuildConstant(entry->target());
    std::vector<llvm::Constant*> entries = {
        ho,
        w.CCast(target),
        w.CCast(w.llvm_functions[entry->target()]),
        w.CCast(BuildConstant(entry->offset())),
        w.CInt2Pointer(w.CSmi(entry->selector())),
    };

    auto full_inst = llvm::ConstantStruct::get(w.dte_type, entries);
    return new llvm::GlobalVariable(w.module_, w.dte_type, true, llvm::GlobalValue::ExternalLinkage, full_inst, name("DispatchTableEntry_%p", entry));
  }

  llvm::Constant* BuildOneByteStringConstant(OneByteString* string) {
    auto int8_array_header = llvm::ArrayType::get(w.int8_type, string->length());

    std::vector<llvm::Constant*> bytes;
    for (int i = 0; i < string->length(); i++) {
      int byte = string->get_char_code(i);
      bytes.push_back(
          llvm::ConstantInt::getIntegerValue(w.int8_type, llvm::APInt(8, byte, false)));
    }

    auto klass = Class::cast(string->get_class());
    auto llvm_klass = BuildConstant(klass);

    auto ho = llvm::ConstantStruct::get(w.heap_object_type, {llvm_klass});
    auto length = w.CSmi(string->length());
    std::vector<llvm::Constant*> array_entries = {ho, length};
    auto array = llvm::ConstantStruct::get(w.array_header, array_entries);

    auto obs = llvm::ConstantStruct::get(w.onebytestring_type, {array, w.CSmi(string->length())});

    auto full_obs_type = w.OneByteStringType(string->length());
    std::vector<llvm::Constant*> entries;
    entries.push_back(obs);
    entries.push_back(llvm::ConstantArray::get(int8_array_header, bytes));
    auto full_array = llvm::ConstantStruct::get(full_obs_type, entries);
    return new llvm::GlobalVariable(w.module_, full_obs_type, true, llvm::GlobalValue::ExternalLinkage, full_array, name("OneByteString_%p__%d", string, string->length()));
  }

  llvm::Constant* BuildInstanceFormat(Class* klass) {
    uint32 value = static_cast<uint32>(reinterpret_cast<intptr_t>(klass->instance_format().as_smi()));
    return w.CInt(value);
  }

  World& w;
};

// Helper methods encapsulating some boilerplate code using `llvm::IRBuilder`.
class IRHelper {
 public:
  IRHelper(World& world, llvm::IRBuilder<>* builder) : w(world), b(builder) {}

  llvm::Constant* BuildCString(const char* name) {
    int len = strlen(name);
    auto int8_array_header = llvm::ArrayType::get(w.int8_type, len + 2);

    std::vector<llvm::Constant*> bytes;
    for (int i = 0; i < len; i++) {
      int byte = name[i];
      bytes.push_back(
          llvm::ConstantInt::getIntegerValue(w.int8_type, llvm::APInt(8, byte, false)));
    }
    bytes.push_back(llvm::ConstantInt::getIntegerValue(w.int8_type, llvm::APInt(8, '\n', false)));
    bytes.push_back(llvm::ConstantInt::getIntegerValue(w.int8_type, llvm::APInt(8, '\0', false)));

    auto full_array = llvm::ConstantArray::get(int8_array_header, bytes);
    auto var = new llvm::GlobalVariable(w.module_, int8_array_header, true, llvm::GlobalValue::ExternalLinkage, full_array, "DebugString");
    return w.CCast(var, w.int8_ptr_type);
  }

  llvm::Value* Cast(llvm::Value* value,
                    llvm::Type* ptr_type = NULL,
                    const char* name = "instance") {
    if (ptr_type == NULL) ptr_type = w.object_ptr_type;
    return b->CreateBitCast(value, ptr_type, name);
  }

  llvm::Value* UntagAndCast(llvm::Value* value, llvm::Type* ptr_type = NULL) {
    if (ptr_type == NULL) ptr_type = w.object_ptr_type;
    auto tagged = b->CreateBitCast(value, w.object_ptr_type);
    auto tagged_asint = b->CreatePtrToInt(tagged, w.intptr_type);
    auto untagged_asint = b->CreateSub(tagged_asint, w.CInt(1), "untagged");
    return b->CreateIntToPtr(untagged_asint, ptr_type);
  }

  llvm::Value* DecodeSmi(llvm::Value* value) {
    value = b->CreatePtrToInt(value, w.intptr_type);
    return b->CreateUDiv(value, w.CInt(2)); // use shift instead!
  }

  llvm::Value* EncodeSmi(llvm::Value* value) {
    value = b->CreateMul(value, w.CInt(2)); // use shift instead!
    return b->CreateIntToPtr(value, w.object_ptr_type);
  }

  llvm::Value* Null() {
    return llvm::ConstantStruct::getNullValue(w.object_ptr_type);
  }

 private:
  World& w;
  llvm::IRBuilder<>* b;
};

class BasicBlockBuilder {
 public:
  // bcp & fp & empty
  static const int kAuxiliarySlots = 3;

  BasicBlockBuilder(World& world,
                    Function* function,
                    llvm::Function* llvm_function,
                    llvm::IRBuilder<>& builder)
      : w(world),
        function_(function),
        llvm_function_(llvm_function),
        b(builder),
        context(w.context),
        h(w, &builder),
        stack_pos_(0),
        max_stack_height_(0) {
    // We make an extra basic block for loading arguments and jump to the basic
    // block corresponding to BCI 0, because sometimes we'll have loops going
    // back to BCI0 (which LLVM doesn't allow).
    bb_entry_ = llvm::BasicBlock::Create(context, name("entry"), llvm_function_);
  }
  ~BasicBlockBuilder() {}

  // Records that we will need a new basic block at [bci] with [stack_height].
  void AddBasicBlockAtBCI(int bci, int stack_height) {
    auto pair = bci2bb_.find(bci);
    if (pair == bci2bb_.end()) {
      bci2bb_[bci] = llvm::BasicBlock::Create(context, name("bb%d", bci), llvm_function_);
      bci2sh_[bci] = stack_height;
    } else {
      int safed = bci2sh_[bci];
      if (safed == -1) {
        bci2sh_[bci] = stack_height;
      } else if (stack_height != -1) {
        ASSERT(safed == stack_height);
      }
    }
  }

  // Sets the maximum stack height by any bytecode in the function.
  void SetMaximumStackHeight(int max_stack_height) {
    max_stack_height_ = max_stack_height;
  }

  // Start inserting at [bci]. After this method has been called Do*() methods
  // can be used for generating code for bytecodes.
  void InsertAtBCI(int bci) {
    auto pair = bci2bb_.find(bci);
    ASSERT(pair != bci2bb_.end());
    if (b.GetInsertBlock() != pair->second) {
      b.SetInsertPoint(pair->second);
      stack_pos_ = bci2sh_[bci];
    }
  }

  // Methods for generating code inside one basic block.

  void DoLoadArguments() {
    b.SetInsertPoint(bb_entry_);

    int arity = function_->arity();
    for (int i = 0; i < arity; i++) {
      // These will be set in reverse order blow.
      stack_.push_back(NULL);
    }

    for (int i = 0; i < kAuxiliarySlots; i++) {
      // These should never be read or set.
      stack_.push_back(NULL);
    }

    for (int i = 0; i < max_stack_height_; i++) {
      llvm::Value* slot = b.CreateAlloca(w.object_ptr_type, NULL, name("slot_%d", i));
      stack_.push_back(slot);
    }

    // Save [process] and set arguments in reverse order on stack slots.
    int argc = 0;
    for (llvm::Argument& arg : llvm_function_->getArgumentList()) {
      if (argc == 0) {
        llvm_process_ = &arg;
      } else {
        ASSERT((arity - argc) >= 0);

        // The bytecodes can do a 'storelocal 5' where '5' refers to a function
        // parameter (i.e. parameter slots are modifyable as well).
        llvm::Value* slot = b.CreateAlloca(w.object_ptr_type, NULL, name("arg_%d", argc));
        b.CreateStore(&arg, slot);

        stack_[arity - argc] = slot;
      }
      argc++;
    }
    ASSERT(static_cast<int>(stack_.size()) ==
           (arity + kAuxiliarySlots + max_stack_height_));

    b.CreateBr(GetBasicBlockAt(0));
  }

  void DoLoadLocal(int offset) {
    push(local(offset));
  }

  void DoLoadInteger(int i) {
    push(w.CInt2Pointer(w.CSmi(i)));
  }

  void DoLoadConstant(Object* object) {
    llvm::Value* value = NULL;
    if (object->IsHeapObject()) {
      value = h.Cast(w.tagged_heap_objects[HeapObject::cast(object)]);
      ASSERT(value != NULL);
    } else {
      // TODO
      value = llvm::ConstantStruct::getNullValue(w.object_ptr_type);
    }
    push(value);
  }

  void DoLoadField(int field) {
    auto value = pop();
    auto instance = h.UntagAndCast(value, w.InstanceTypePtr(1 + field));

    std::vector<llvm::Value*> indices = { w.CInt(0), w.CInt(1 + field) };
    auto field_address = b.CreateGEP(instance, indices);
    auto field_value = b.CreateLoad(field_address, name("field_%d", field));

    push(field_value);
  }

  void DoStoreLocal(int index) {
    SetLocal(index, local(0));
  }

  void DoDrop(int n) {
    while (n-- > 0) pop();
  }

  void DoReturn() {
    b.CreateRet(pop());
  }

  void DoReturnNull() {
    auto value = w.tagged_heap_objects[w.program_->null_object()];
    ASSERT(value != NULL);
    b.CreateRet(h.Cast(value, w.object_ptr_type));
  }

  void DoAllocate(Class* klass, bool immutable) {
    int fields = klass->NumberOfInstanceFields();
    auto llvm_klass = h.Cast(w.tagged_heap_objects[klass], w.object_ptr_type);
    ASSERT(llvm_klass != NULL);

    // TODO: Check for Failure::xxx result!
    auto instance = b.CreateCall(
        w.runtime__HandleAllocate,
        {llvm_process_, llvm_klass, w.CInt(immutable ? 1 : 0)});
    auto untagged_instance = h.UntagAndCast(instance, w.InstanceTypePtr(fields));
    for (int field = 0; field < fields; field++) {
      auto pos = b.CreateGEP(untagged_instance, {w.CInt(0), w.CInt(1 + field)});
      b.CreateStore(pop(), pos);
    }
    push(instance);
  }

  void DoEnterNSM() {
    // TODO:
    push(h.Null());
    push(h.Null());
    push(h.Null());
    push(h.Null());
    push(h.Null());
    push(h.Null());
  }

  void DoLoadStatic(int offset) {
    std::vector<llvm::Value*> statics_indices = { w.CInt(Process::kStaticsOffset  / kWordSize) };
    auto statics_tagged = b.CreateLoad(b.CreateGEP(h.Cast(llvm_process_, w.object_ptr_ptr_type), statics_indices), "statics");
    auto statics = h.UntagAndCast(statics_tagged, w.object_ptr_ptr_type);

    std::vector<llvm::Value*> statics_entry_indices = { w.CInt(Array::kSize / kWordSize + offset) };
    auto statics_entry = h.Cast(b.CreateLoad(b.CreateGEP(statics, statics_entry_indices), "statics_entry"), w.object_ptr_ptr_type);

    push(b.CreateLoad(statics_entry));
  }

  void DoStoreStatic(int offset) {
    std::vector<llvm::Value*> statics_indices = { w.CInt(Process::kStaticsOffset  / kWordSize) };
    auto statics_tagged = b.CreateLoad(b.CreateGEP(h.Cast(llvm_process_, w.object_ptr_ptr_type), statics_indices), "statics");
    auto statics = h.UntagAndCast(statics_tagged, w.object_ptr_ptr_type);

    std::vector<llvm::Value*> statics_entry_indices = { w.CInt(Array::kSize / kWordSize + offset) };
    auto statics_entry = h.Cast(b.CreateLoad(b.CreateGEP(statics, statics_entry_indices), "statics_entry"), w.object_ptr_ptr_type);

    b.CreateStore(local(0), statics_entry);
  }

  void DoLoadStaticInit(int offset) {
    // TODO:
    push(h.Null());
  }

  void DoCall(Function* target) {
    std::vector<llvm::Value*> args;
    args.push_back(llvm_process_);
    for (unsigned i = 0; i < target->arity(); i++) {
      args.push_back(pop());
    }
    llvm::Function* llvm_target = static_cast<llvm::Function*>(w.llvm_functions[target]);
    ASSERT(llvm_target != NULL);
    auto result = b.CreateCall(llvm_target, args, "result");
    push(result);
  }

  void DoInvokeNative(Native nativeId, int arity) {
    auto void_ptr = w.object_ptr_type;

    auto process = h.Cast(llvm_process_, void_ptr);
    auto array = b.CreateAlloca(w.object_ptr_type, w.CInt(arity));

    llvm::Value* array_pos = array;
    for (int i = 0; i < arity; i++) {
      auto arg = argument(i);
      b.CreateStore(arg, array_pos);
      std::vector<llvm::Value*> indices = {w.CInt(1)};
      array_pos = b.CreateGEP(array_pos, indices);
    }

    llvm::Function* native = w.natives_[nativeId];
    std::vector<llvm::Value*> args = {process, array};
    auto result = b.CreateCall(native, args, "native_call_result");
    push(result);

    // TODO: Check for Failure::xxx result!
    b.CreateRet(result);
  }

  void DoIdentical() {
    // TODO: Handle about other classes!
    auto true_obj = h.Cast(w.tagged_heap_objects[w.program_->true_object()]);
    auto false_obj = h.Cast(w.tagged_heap_objects[w.program_->false_object()]);
    push(b.CreateSelect(b.CreateICmpEQ(pop(), pop()), true_obj, false_obj, "identical_result"));
  }

  void DoAdd() {
    // TODO: Handle about other classes!
    auto argument = h.DecodeSmi(pop());
    auto receiver = h.DecodeSmi(pop());
    push(h.EncodeSmi(b.CreateAdd(receiver, argument)));
  }

  void DoSub() {
    // TODO: Handle about other classes!
    auto argument = h.DecodeSmi(pop());
    auto receiver = h.DecodeSmi(pop());
    push(h.EncodeSmi(b.CreateSub(receiver, argument)));
  }

  void DoCompare(Opcode opcode) {
    // TODO: Handle about other classes!
    auto right = h.DecodeSmi(pop());
    auto left = h.DecodeSmi(pop());

    llvm::Value* comp = NULL;
    if (opcode == kInvokeEq) {
      comp = b.CreateICmpEQ(left, right);
    } else if (opcode == kInvokeGe) {
      comp = b.CreateICmpSGE(left, right);
    } else if (opcode == kInvokeGt) {
      comp = b.CreateICmpSGT(left, right);
    } else if (opcode == kInvokeLe) {
      comp = b.CreateICmpSLE(left, right);
    } else if (opcode == kInvokeLt) {
      comp = b.CreateICmpSLT(left, right);
    } else {
      UNREACHABLE();
    }

    auto true_obj = h.Cast(w.tagged_heap_objects[w.program_->true_object()]);
    auto false_obj = h.Cast(w.tagged_heap_objects[w.program_->false_object()]);
    push(b.CreateSelect(comp, true_obj, false_obj, "compare_result"));
  }

  void DoInvokeMethod(int selector, int arity, int offset) {
    std::vector<llvm::Value*> method_args(1 + 1 + arity);

    method_args[0] = llvm_process_;

    int index = method_args.size() - 1;
    for (int i = 0; i < arity; i++) {
      method_args[index--] = pop();
    }
    ASSERT(index == 1);
    auto receiver = method_args[1] = pop();
    auto function = h.Cast(LookupEntryInDispatchTable(receiver, selector), w.FunctionPtrType(1 + arity));

    auto result = b.CreateCall(function, method_args, "method_result");
    push(result);
  }

  void DoBranch(int bci) {
    auto dst = GetBasicBlockAt(bci);
    b.CreateBr(dst);
  }

  void DoBranchIf(int bci, int next_bci) {
    auto true_object = w.tagged_heap_objects[w.program_->true_object()];
    auto pos = GetBasicBlockAt(bci);
    auto neg = GetBasicBlockAt(next_bci);
    auto cond = b.CreateICmpEQ(pop(), w.CCast(true_object));
    b.CreateCondBr(cond, pos, neg);
  }

  void DoBranchIfFlase(int bci, int next_bci) {
    auto true_object = w.tagged_heap_objects[w.program_->true_object()];
    auto neg = GetBasicBlockAt(bci);
    auto pos = GetBasicBlockAt(next_bci);
    auto cond = b.CreateICmpEQ(pop(), w.CCast(true_object));
    b.CreateCondBr(cond, pos, neg);
  }

  void DoDebugPrint(const char* message) {
    b.CreateCall(w.libc__printf, {h.BuildCString(message)});
  }

 private:
  llvm::Value* LookupEntryInDispatchTable(llvm::Value* target_object, int selector) {
    auto bb_smi = llvm::BasicBlock::Create(context, "smi", llvm_function_);;
    auto bb_nonsmi = llvm::BasicBlock::Create(context, "nonsmi", llvm_function_);;
    auto bb_lookup = llvm::BasicBlock::Create(context, "lookup", llvm_function_);;

    auto is_smi = b.CreateIsNull(b.CreateAnd(b.CreatePtrToInt(target_object, w.intptr_type), w.CInt(1)));
    b.CreateCondBr(is_smi, bb_smi, bb_nonsmi);

    b.SetInsertPoint(bb_smi);
    auto smi_klass = h.Cast(w.tagged_heap_objects[w.program_->smi_class()]);
    b.CreateBr(bb_lookup);

    b.SetInsertPoint(bb_nonsmi);
    std::vector<llvm::Value*> klass_indices = { w.CInt(HeapObject::kClassOffset / kWordSize) };
    auto custom_klass = b.CreateLoad(b.CreateGEP(h.UntagAndCast(target_object, w.object_ptr_ptr_type), klass_indices), "klass");
    b.CreateBr(bb_lookup);

    b.SetInsertPoint(bb_lookup);
    auto klass = b.CreatePHI(w.object_ptr_type, 2, "klass");
    klass->addIncoming(smi_klass, bb_smi);
    klass->addIncoming(custom_klass, bb_nonsmi);

    std::vector<llvm::Value*> classid_indices = { w.CInt(Class::kIdOrTransformationTargetOffset / kWordSize) };
    auto smi_classid = b.CreateLoad(b.CreateGEP(h.UntagAndCast(klass, w.object_ptr_ptr_type), classid_indices));
    auto smi_selector_offset = ((selector & Selector::IdField::mask()) >> Selector::IdField::shift()) << Smi::kTagSize;
    auto offset = b.CreateAdd(w.CInt(smi_selector_offset), b.CreatePtrToInt(smi_classid, w.intptr_type));

    auto dispatch = w.tagged_heap_objects[w.program_->dispatch_table()];

    // Away with the Smi tag & index into dispatch table.
    offset = b.CreateAdd(b.CreateUDiv(h.Cast(offset, w.intptr_type), w.CInt(2)), w.CInt(Array::kSize / kWordSize));
    std::vector<llvm::Value*> dentry_indices = { offset };
    auto entry = b.CreateLoad(b.CreateGEP(h.UntagAndCast(dispatch, w.object_ptr_ptr_type), dentry_indices), "dispatch_table_entry");

    std::vector<llvm::Value*> ccode_indices = { w.CInt(DispatchTableEntry::kCodeOffset / kWordSize) };
    llvm::Value* code = b.CreateLoad(b.CreateGEP(h.UntagAndCast(entry, w.object_ptr_ptr_type), ccode_indices), "target_method");

    return code;
  }

  llvm::BasicBlock* GetBasicBlockAt(int bci) {
    auto bb = bci2bb_[bci];
    ASSERT(bb != NULL);
    return bb;
  }

  void push(llvm::Value* v) {
    ASSERT(v->getType() == w.object_ptr_type);
    ASSERT(stack_pos_ <= max_stack_height_);

    int arity = function_->arity();
    stack_pos_++;
    b.CreateStore(v, stack_[arity + kAuxiliarySlots + stack_pos_ - 1]);
  }

  llvm::Value* pop() {
    ASSERT(stack_pos_ > 0);
    auto v = local(0);
    stack_pos_--;
    return v;
  }

  llvm::Value* local(int i) {
    return b.CreateLoad(stack_[GetOffset(i)]);
  }

  llvm::Value* argument(int i) {
    return local(i + kAuxiliarySlots + stack_pos_);
  }

  void SetLocal(int i, llvm::Value* value) {
    b.CreateStore(value, stack_[GetOffset(i)]);
  }

  int GetOffset(int i) {
    ASSERT(i >= 0);
    int arity = function_->arity();
    int offset = arity + kAuxiliarySlots + stack_pos_ - i - 1;
    ASSERT(offset >= 0 && offset < static_cast<int>(stack_.size()));
    if (i >= stack_pos_) {
      // Ensure we don't load any auxiliary slots.
      ASSERT(i >= (kAuxiliarySlots + stack_pos_));
    }
    return offset;
  }

  World& w;
  Function* function_;
  llvm::Function* llvm_function_;
  llvm::IRBuilder<>& b;
  llvm::LLVMContext& context;
  llvm::Value* llvm_process_;
  std::vector<llvm::Value*> stack_;
  IRHelper h;
  int stack_pos_;
  int max_stack_height_;
  llvm::BasicBlock* bb_entry_;
  std::map<int, llvm::BasicBlock*> bci2bb_;
  std::map<int, int> bci2sh_;
};

class BasicBlocksExplorer {
 public:
  BasicBlocksExplorer(World& world,
                      Function* function,
                      llvm::Function* llvm_function)
      : w(world),
        function_(function),
        llvm_function_(llvm_function),
        max_stacksize_(0) {}

  void Explore() {
    // Enqueue root & catch block entries.
    Enqueue(0, 0);
    EnqueueCatchBlocks();

    // While we have to scan roots do so.
    while (todo.size() != 0) {
      auto it = todo.begin();
      int bci = it->first;
      int stacksize = it->second;
      todo.erase(it);
      ScanBci(bci, stacksize);
    }
  }

  void Build() {
    auto llvm_function = w.llvm_functions[function_];

    llvm::IRBuilder<> builder(w.context);
    BasicBlockBuilder b(w, function_, llvm_function, builder);

    // Phase 1: Create basic blocks
    for (auto& pair : labels) {
      b.AddBasicBlockAtBCI(pair.first, pair.second);
    }
    b.SetMaximumStackHeight(max_stacksize_);

    // Phase 2: Fill basic blocks
    b.DoLoadArguments();

    for (auto& pair : labels) {
      int bci = pair.first;
      b.InsertAtBCI(bci);

      bool last_opcode_was_jump = false;
      bool stop = false;
      do {
        uint8* bcp = function_->bytecode_address_for(bci);
        Opcode opcode = static_cast<Opcode>(*bcp);
        int next_bci = bci + Bytecode::Size(opcode);

        b.DoDebugPrint(name("[trace fun: %p  bci: @%02d] %s", function_, bci, bytecode_string(bcp)));

        switch (opcode) {
          case kInvokeFactory:
          case kInvokeStatic: {
            b.DoCall(Function::cast(Function::ConstantForBytecode(bcp)));
            break;
          }

          case kLoadLocal0:
          case kLoadLocal1:
          case kLoadLocal2:
          case kLoadLocal3:
          case kLoadLocal4:
          case kLoadLocal5: {
            b.DoLoadLocal(opcode - kLoadLocal0);
            break;
          }
          case kLoadLocal: {
            b.DoLoadLocal(*(bcp + 1));
            break;
          }
          case kLoadLocalWide: {
            b.DoLoadLocal(Utils::ReadInt32(bcp + 1));
            break;
          }
          case kLoadField: {
            b.DoLoadField(*(bcp + 1));
            break;
          }

          case kLoadFieldWide: {
            b.DoLoadField(Utils::ReadInt32(bcp + 1));
            break;
          }

          case kLoadLiteral0:
          case kLoadLiteral1: {
            b.DoLoadInteger(opcode - kLoadLiteral0);
            break;
          }

          case kLoadLiteral: {
            b.DoLoadInteger(*(bcp + 1));
            break;
          }

          case kLoadLiteralWide: {
            b.DoLoadInteger(Utils::ReadInt32(bcp + 1));
            break;
          }

          case kLoadLiteralNull: {
            b.DoLoadConstant(w.program_->null_object());
            break;
          }

          case kLoadLiteralTrue: {
            b.DoLoadConstant(w.program_->true_object());
            break;
          }

          case kLoadLiteralFalse: {
            b.DoLoadConstant(w.program_->false_object());
            break;
          }

          case kLoadConst: {
            Object* constant = Function::ConstantForBytecode(function_->bytecode_address_for(bci));
            b.DoLoadConstant(constant);
            break;
          }

          case kStoreLocal: {
            int index = *(bcp + 1);
            b.DoStoreLocal(index);
            break;
          }

          case kBranchWide: {
            b.DoBranch(bci + Utils::ReadInt32(bcp + 1));
            stop = true;
            break;
          }

          case kBranchBack: {
            b.DoBranch(bci - *(bcp + 1));
            stop = true;
            break;
          }

          case kBranchBackWide: {
            b.DoBranch(bci - Utils::ReadInt32(bcp + 1));
            stop = true;
            break;
          }

          case kPopAndBranchWide: {
            b.DoDrop(*(bcp + 1));
            b.DoBranch(bci + Utils::ReadInt32(bcp + 2));
            stop = true;
            break;
          }

          case kPopAndBranchBackWide: {
            b.DoDrop(*(bcp + 1));
            b.DoBranch(bci - Utils::ReadInt32(bcp + 2));
            stop = true;
            break;
          }

          case kBranchIfTrueWide: {
            b.DoBranchIf(bci + Utils::ReadInt32(bcp + 1), next_bci);
            break;
          }

          case kBranchBackIfTrue: {
            b.DoBranchIf(bci - *(bcp + 1), next_bci);
            break;
          }

          case kBranchBackIfTrueWide: {
            b.DoBranchIf(bci - Utils::ReadInt32(bcp + 1), next_bci);
            break;
          }

          case kBranchIfFalseWide: {
            b.DoBranchIfFlase(bci + Utils::ReadInt32(bcp + 1), next_bci);
            break;
          }

          case kBranchBackIfFalse: {
            b.DoBranchIfFlase(bci - *(bcp + 1), next_bci);
            break;
          }

          case kBranchBackIfFalseWide: {
            b.DoBranchIfFlase(bci - Utils::ReadInt32(bcp + 1), next_bci);
            break;
          }

          case kPop: {
            b.DoDrop(1);
            break;
          }

          case kDrop: {
            b.DoDrop(*(bcp + 1));
            break;
          }

          case kReturn: {
            b.DoReturn();
            stop = true;
            break;
          }

          case kReturnNull: {
            b.DoReturnNull();
            stop = true;
            break;
          }

          /*
          case kLoadBoxed: {
            DoLoadBoxed(*(bcp + 1));
            break;
          }
          case kStoreBoxed: {
            int index = *(bcp + 1);
            DoStoreBoxed(index);
            break;
          }

          case kStoreLocal: {
            int index = *(bcp + 1);
            DoStoreLocal(index);
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

          case kInvokeNoSuchMethod: {
            int selector = Utils::ReadInt32(bcp + 1);
            DoInvokeNoSuchMethod(selector);
            break;
          }

          case kInvokeTest: {
            int selector = Utils::ReadInt32(bcp + 1);
            int offset = Selector::IdField::decode(selector);
            DoInvokeTest(offset);
            break;
          }

          case kInvokeTestNoSuchMethod: {
            DoDrop(1);
            DoLoadProgramRoot(Program::kFalseObjectOffset);
            break;
          }

          case kInvokeStatic:
          case kInvokeFactory: {
            int offset = Utils::ReadInt32(bcp + 1);
            Function* target = Function::cast(Function::ConstantForBytecode(bcp));
            DoInvokeStatic(bci, offset, target);
            break;
          }
          case kThrow: {
            DoThrow();
            basic_block_.Clear();
            break;
          }

          case kSubroutineCall: {
            int target = bci + Utils::ReadInt32(bcp + 1);
            DoSubroutineCall(target);
            break;
          }

          case kSubroutineReturn: {
            DoSubroutineReturn();
            break;
          }

          case kAllocateBoxed: {
            DoAllocateBoxed();
            break;
          }

          case kNegate: {
            DoNegate();
            break;
          }

          case kProcessYield: {
            DoProcessYield();
            basic_block_.Clear();
            break;
          }

          case kEnterNoSuchMethod: {
            DoNoSuchMethod();
            basic_block_.Clear();
            break;
          }

          case kCoroutineChange: {
            int selector = Selector::Encode(Names::kCoroutineStart, Selector::METHOD, 1);
            Function* start = program()->coroutine_class()->LookupMethod(selector);
            DoCoroutineChange(start == function_ && bci == 2);
            basic_block_.Clear();
            break;
          }

          case kStackOverflowCheck: {
            int size = Utils::ReadInt32(bcp + 1);
            DoStackOverflowCheck(size);
            break;
          }
          */

          case kIdentical: {
            b.DoIdentical();
            break;
          }

          case kIdenticalNonNumeric: {
            b.DoIdentical();
            break;
          }

          case kInvokeDetachableNative:
          case kInvokeNative: {
            int arity = *(bcp + 1);
            Native native = static_cast<Native>(*(bcp + 2));
            b.DoInvokeNative(native, arity);

            // FIXME: we should generate the other bytecodes handling
            // failures as well.
            stop = true;

            break;
          }

          case kAllocate:
          case kAllocateImmutable: {
            Class* klass = Class::cast(Function::ConstantForBytecode(bcp));
            b.DoAllocate(klass, opcode == kAllocateImmutable);
            break;
          }

          case kInvokeAdd: {
            b.DoAdd();
            break;
          }

          case kInvokeSub: {
            b.DoSub();
            break;
          }

          case kInvokeEq:
          case kInvokeGe:
          case kInvokeGt:
          case kInvokeLe:
          case kInvokeLt: {
            b.DoCompare(opcode);
            break;
          }

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
            b.DoInvokeMethod(selector, arity, offset);
            break;
          }

          // FIXME:
          case kEnterNoSuchMethod: {
            b.DoEnterNSM();
            break;
          }

          case kLoadStatic: {
            b.DoLoadStatic(Utils::ReadInt32(bcp + 1));
            break;
          }
          case kStoreStatic: {
            b.DoStoreStatic(Utils::ReadInt32(bcp + 1));
            break;
          }


          case kLoadStaticInit: {
            b.DoLoadStaticInit(Utils::ReadInt32(bcp + 1));
            break;
          }

          case kMethodEnd: {
            stop = true;
            break;
          }

          default: {
            b.DoDebugPrint(name("Unsupported bytecode: %s", bytecode_string(bcp)));
            b.DoReturnNull();
            Print::Error("     ---> Unsupported \"%s\"\n", bytecode_string(bcp));
            stop = true;
            break;
          }
        }
        last_opcode_was_jump = IsBranchOpcode(opcode);
        bci = next_bci;
      } while (labels.find(bci) == labels.end() && !stop);

      if (!last_opcode_was_jump && !stop) {
        b.DoBranch(bci);
      }
    }

    VerifyFunction();
  }

 private:
  // Scans [bci] until the next DoBranch occurs and records on that DoBranch
  // target(s) the stacksize.
  void ScanBci(int bci, int stacksize) {

    // FIXME/TODO:
    // This has currently a bad time complexity, we should remember [bci]s we've
    // already scanned.

    while (true) {
      uint8* bcp = function_->bytecode_address_for(bci);
      Opcode opcode = static_cast<Opcode>(*bcp);
      int next_bci = bci + Bytecode::Size(opcode);

      stacksize += StackDiff(bcp);
      if (stacksize > max_stacksize_) max_stacksize_ = stacksize;

      if (opcode == kMethodEnd) break;

      switch (opcode) {
        case kBranchIfTrueWide:
        case kBranchIfFalseWide:
          Enqueue(next_bci, stacksize);
          Enqueue(bci + Utils::ReadInt32(bcp + 1), stacksize);
          return;
        case kBranchWide:
          Enqueue(bci + Utils::ReadInt32(bcp + 1), stacksize);
          return;
        case kPopAndBranchWide:
          Enqueue(bci + Utils::ReadInt32(bcp + 2), stacksize);
          return;
        case kBranchBackIfTrue:
        case kBranchBackIfFalse:
          Enqueue(next_bci, stacksize);
          Enqueue(bci - *(bcp + 1), stacksize);
        case kBranchBack:
          Enqueue(bci - *(bcp + 1), stacksize);
          return;
        case kBranchBackIfTrueWide:
        case kBranchBackIfFalseWide:
          Enqueue(next_bci, stacksize);
          Enqueue(bci - Utils::ReadInt32(bcp + 1), stacksize);
          return;
        case kBranchBackWide:
          Enqueue(bci - Utils::ReadInt32(bcp + 1), stacksize);
          return;
        case kPopAndBranchBackWide:
          Enqueue(bci - Utils::ReadInt32(bcp + 2), stacksize);
          return;
        case kReturn:
          return;
        case kSubroutineCall:
          // TODO:
          // This is some kind of exception/catch block stuff. Need fo find out
          // if this [stadksize] is correct here.
          Enqueue(bci + Utils::ReadInt32(bcp + 1), stacksize);
          return;
        default:
          break;
      }

      bci += Bytecode::Size(opcode);
    }
  }

  // Gets all catch block [bci]s and it's [stacksize]es and enqueues them.
  void EnqueueCatchBlocks() {
    int frame_ranges_offset = -1;
    uint8* bcp = function_->bytecode_address_for(0);
    function_->FromBytecodePointer(bcp, &frame_ranges_offset);
    if (frame_ranges_offset != -1) {
      uint8* catch_block_address = function_->bytecode_address_for(frame_ranges_offset);
      int count = Utils::ReadInt32(catch_block_address);
      uint32* ptr = reinterpret_cast<uint32*>(catch_block_address + 4);
      for (int i = 0; i < count; i++) {
        uint32 start = ptr[3 * i + 0];
        uint32 stack_size = ptr[3 * i + 2];
        Enqueue(start, stack_size);
      }
    }
  }

  // Marks [bci] as a branch target (or entrypoint) with [stacksize]. It will be
  // scanned later to discover more branch targets.
  void Enqueue(int bci, int stacksize) {
    auto pair = labels.find(bci);
    bool present = pair != labels.end();
    if (!present) {
      todo[bci] = stacksize;
      labels[bci] = stacksize;
    } else {
      ASSERT(pair->second == stacksize);
    }
  }

  bool IsBranchOpcode(Opcode op) {
    return op == kBranchWide ||
           op == kBranchIfTrueWide ||
           op == kBranchIfFalseWide ||
           op == kBranchBack ||
           op == kBranchBackIfTrue ||
           op == kBranchBackIfFalse ||
           op == kBranchBackWide ||
           op == kBranchBackIfTrueWide ||
           op == kBranchBackIfFalseWide ||
           op == kPopAndBranchWide ||
           op == kPopAndBranchBackWide ||
           op == kSubroutineCall || // Some kind of exception/catch block stuff :-/
           op == kReturn;
  }

  void VerifyFunction() {
    std::string ErrorStr;
    llvm::raw_string_ostream OS(ErrorStr);
    if (llvm::verifyFunction(*llvm_function_, &OS)) {
      Print::Error("Function verification failed:\n");
      llvm_function_->dump();
      Print::Error("Errors\n");
      std::cerr << OS.str();
      FATAL("Function verification failed. Will not proceed.");
    }
  }

  World& w;
  Function* function_;
  llvm::Function* llvm_function_;
  int max_stacksize_;
  std::map<int, int> labels;
  std::map<int, int> todo;
};

class FunctionsBuilder : public HeapObjectVisitor {
 public:
  FunctionsBuilder(World& world) : w(world) { }

  virtual int Visit(HeapObject* object) {
    if (object->IsFunction()) {
      auto function = Function::cast(object);
      auto llvm_function = w.llvm_functions[function];

      BasicBlocksExplorer explorer(w, function, llvm_function);
      explorer.Explore();
      explorer.Build();
    }
    return object->Size();
  }

 private:
  World& w;
};

class RootsBuilder : public PointerVisitor {
 public:
  RootsBuilder(World& world, HeapBuilder* hbuilder)
    : w(world), hbuilder_(hbuilder) { }

  virtual void VisitBlock(Object** start, Object** end) {
    for (; start < end; start++) {
      Object* object = *start;
      if (object->IsHeapObject()) {
        // Ensure we've got a llvm constant for this root.
        hbuilder_->Visit(HeapObject::cast(object));
        roots_.push_back(w.CCast(w.tagged_heap_objects[HeapObject::cast(object)]));
      } else {
        roots_.push_back(llvm::ConstantStruct::getNullValue(w.object_ptr_type));
      }
    }
  }

  llvm::Constant* BuildRoots() {
    w.program_->IterateRootsIgnoringSession(this);
    return llvm::ConstantStruct::get(w.roots_type, roots_);
  }

 private:
  World& w;
  HeapBuilder* hbuilder_;
  std::vector<llvm::Constant*> roots_;
};

class GlobalSymbolsBuilder {
 public:
  GlobalSymbolsBuilder(World& world) : w(world) {}

  void BuildGlobalSymbols() {
    std::vector<llvm::Type*> int1(1, w.intptr_type);
    std::vector<llvm::Type*> empty;

    // program_start
    auto program_start = llvm::ConstantInt::getIntegerValue(w.intptr_type, llvm::APInt(32, 4096, false));
    auto program_size = llvm::ConstantInt::getIntegerValue(w.intptr_type, llvm::APInt(32, 1024 * 1024, false));
    new llvm::GlobalVariable(w.module_, w.intptr_type, true, llvm::GlobalValue::ExternalLinkage, program_start, "program_start");
    new llvm::GlobalVariable(w.module_, w.intptr_type, true, llvm::GlobalValue::ExternalLinkage, program_size, "program_size");
    auto entry = static_cast<llvm::Function*>(w.llvm_functions[w.program_->entry()]);
    new llvm::GlobalVariable(w.module_, entry->getType(), true, llvm::GlobalValue::ExternalLinkage, entry, "program_entry");
    new llvm::GlobalVariable(w.module_, w.roots_type, true, llvm::GlobalValue::ExternalLinkage, w.roots, "program_info_block");
  }

 private:
  World& w;
};

World::World(Program* program,
             llvm::LLVMContext& context,
             llvm::Module& module)
    : program_(program),
      context(context),
      module_(module),
      intptr_type(NULL),
      int8_type(NULL),
      int8_ptr_type(NULL),
      object_type(NULL),
      object_ptr_type(NULL),
      object_ptr_ptr_type(NULL),
      heap_object_type(NULL),
      heap_object_ptr_type(NULL),
      class_type(NULL),
      class_ptr_type(NULL),
      function_type(NULL),
      function_ptr_type(NULL),
      array_header(NULL),
      array_header_ptr(NULL),
      onebytestring_type(NULL),
      onebytestring_ptr_type(NULL),
      instance_type(NULL),
      instance_ptr_type(NULL),
      roots(NULL),
      libc__printf(NULL),
      runtime__HandleGC(NULL),
      runtime__HandleAllocate(NULL) {
  intptr_type = llvm::Type::getInt32Ty(context);
  int8_type = llvm::Type::getInt8Ty(context);
  int8_ptr_type = llvm::PointerType::get(int8_type, 0);

  object_type = llvm::StructType::create(context, "Tagged");
  object_ptr_type = llvm::PointerType::get(object_type, 0);
  object_ptr_ptr_type = llvm::PointerType::get(object_ptr_type, 0);

  heap_object_type = llvm::StructType::create(context, "HeapType");
  heap_object_ptr_type = llvm::PointerType::get(heap_object_type, 0);

  class_type = llvm::StructType::create(context, "ClassType");
  class_ptr_type = llvm::PointerType::get(class_type, 0);

  function_type = llvm::StructType::create(context, "FunctionType");
  function_ptr_type = llvm::PointerType::get(class_type, 0);

  array_header = llvm::StructType::create(context, "ArrayType");
  array_header_ptr = llvm::PointerType::get(array_header, 0);

  onebytestring_type = llvm::StructType::create(context, "OneByteString");
  onebytestring_ptr_type = llvm::PointerType::get(onebytestring_type, 0);

  instance_type = llvm::StructType::create(context, "InstanceType");
  instance_ptr_type = llvm::PointerType::get(instance_type, 0);

  dte_type = llvm::StructType::create(context, "DispatchTableEntry");
  dte_ptr_type = llvm::PointerType::get(dte_type, 0);

  roots_type = llvm::StructType::create(context, "ProgramRootsType");
  roots_ptr_type = llvm::PointerType::get(roots_type, 0);

  // [object_type]
  std::vector<llvm::Type*> empty;
  object_type->setBody(empty, true);

  // [heap_object_type]
  std::vector<llvm::Type*> heap_object_entries = {class_ptr_type};
  heap_object_type->setBody(heap_object_entries, true);

  // [class_type]
  std::vector<llvm::Type*> class_object_entries;
  class_object_entries.push_back(heap_object_type);
  class_object_entries.push_back(class_ptr_type); // superclass
  class_object_entries.push_back(intptr_type); // instance format
  class_object_entries.push_back(intptr_type); // id
  class_object_entries.push_back(intptr_type); // child id
  class_object_entries.push_back(array_header_ptr); // method array
  class_type->setBody(class_object_entries, true);

  // [function_type]
  std::vector<llvm::Type*> function_object_entries;
  function_object_entries.push_back(heap_object_type);
  function_object_entries.push_back(intptr_type); // bytecode size
  function_object_entries.push_back(intptr_type); // literals size
  function_object_entries.push_back(intptr_type); // arity
  function_object_entries.push_back(intptr_type); // custom: [word] to machine code
  function_type->setBody(function_object_entries, true);

  // [array_header]
  std::vector<llvm::Type*> array_object_entries;
  array_object_entries.push_back(heap_object_type);
  array_object_entries.push_back(intptr_type); // length
  array_header->setBody(array_object_entries, true);

  // [onebytestring_ptr_type]
  std::vector<llvm::Type*> obs_object_entries;
  obs_object_entries.push_back(array_header);
  obs_object_entries.push_back(intptr_type); // hash
  onebytestring_type->setBody(obs_object_entries, true);

  // [instance_type]
  std::vector<llvm::Type*> instance_object_entries;
  instance_object_entries.push_back(heap_object_type);
  instance_object_entries.push_back(intptr_type); // flags
  instance_type->setBody(instance_object_entries, true);

  // [dte_type]
  std::vector<llvm::Type*> dte_object_entries;
  dte_object_entries.push_back(heap_object_type);
  dte_object_entries.push_back(object_ptr_type); // target
  dte_object_entries.push_back(object_ptr_type); // (machine)code
  dte_object_entries.push_back(object_ptr_type); // offset
  dte_object_entries.push_back(object_ptr_type); // selector
  dte_type->setBody(dte_object_entries, true);

  // [roots_type]
  std::vector<llvm::Type*> root_entries;
#define ADD_ROOT(type, name, CamelName) \
  root_entries.push_back(object_ptr_type);
  ROOTS_DO(ADD_ROOT)
#undef ADD_ROOT
  root_entries.push_back(object_ptr_type); // Program::entry_
  roots_type->setBody(root_entries, true);

  // External C functions for debugging.

  auto printf_type = llvm::FunctionType::get(intptr_type, {int8_ptr_type}, true);
  libc__printf = llvm::Function::Create(printf_type, llvm::Function::ExternalLinkage, "printf", &module_);

  auto handle_gc_type = llvm::FunctionType::get(llvm::Type::getVoidTy(context), {object_ptr_type}, false);
  auto handle_allocate_type = llvm::FunctionType::get(object_ptr_type, {object_ptr_type, object_ptr_type, intptr_type}, false);

  runtime__HandleGC = llvm::Function::Create(handle_gc_type, llvm::Function::ExternalLinkage, "HandleGC", &module_);
  runtime__HandleAllocate = llvm::Function::Create(handle_allocate_type, llvm::Function::ExternalLinkage, "HandleAllocate", &module_);
}

llvm::StructType* World::ObjectArrayType(int n) {
  auto array = llvm::StructType::create(context, name("Array__%d", n));
  std::vector<llvm::Type*> types;
  types.push_back(array_header);
  for (int i = 0; i < n; i++) {
    types.push_back(object_ptr_type);
  }
  array->setBody(types, true);
  return array;
}

llvm::PointerType* World::ObjectArrayPtrType(int n) {
  return llvm::PointerType::get(ObjectArrayType(n), false);
}

llvm::StructType* World::InstanceType(int n) {
  auto inst_type = llvm::StructType::create(context, name("Instance__%d", n));
  std::vector<llvm::Type*> types;
  types.push_back(instance_type);
  for (int i = 0; i < n; i++) {
    types.push_back(object_ptr_type);
  }
  inst_type->setBody(types, true);
  return inst_type;
}

llvm::PointerType* World::InstanceTypePtr(int n) {
  return llvm::PointerType::get(InstanceType(n), 0);
}

llvm::StructType* World::OneByteStringType(int n) {
  auto obs_type = llvm::StructType::create(context, name("OneByteString__%d", n));
  std::vector<llvm::Type*> types = {
    onebytestring_type,
    llvm::ArrayType::get(int8_type, n),
  };
  obs_type->setBody(types, true);
  return obs_type;
}

llvm::FunctionType* World::FunctionType(int arity) {
  std::vector<llvm::Type*> args(1 /* process */ + arity, object_ptr_type);
  return llvm::FunctionType::get(object_ptr_type, args, false);
}

llvm::PointerType* World::FunctionPtrType(int arity) {
  return llvm::PointerType::get(FunctionType(arity), false);
}

llvm::Constant* World::CTag(llvm::Constant* constant, llvm::Type* ptr_type) {
  if (ptr_type == NULL) ptr_type = constant->getType();
  auto as_int = llvm::ConstantExpr::getPtrToInt(constant, intptr_type);
  auto tagged = llvm::ConstantExpr::getAdd(as_int, CInt(1));
  return llvm::ConstantExpr::getIntToPtr(tagged, ptr_type);
}

llvm::Constant* World::CUnTag(llvm::Constant* constant, llvm::Type* ptr_type) {
  if (ptr_type == NULL) ptr_type = constant->getType();
  auto as_int = llvm::ConstantExpr::getPtrToInt(constant, intptr_type);
  auto untagged = llvm::ConstantExpr::getSub(as_int, CInt(1));
  return llvm::ConstantExpr::getIntToPtr(untagged, ptr_type, "untagged");
}

llvm::Constant* World::CInt(uint32 value) {
  uint64 value64 = value;
  return llvm::ConstantInt::getIntegerValue(intptr_type, llvm::APInt(32, value64, false));
}

llvm::Constant* World::CSmi(uint32 integer) {
  return CInt(static_cast<uint32>(reinterpret_cast<intptr_t>(Smi::FromWord(integer))));
}

llvm::Constant* World::CPointer2Int(llvm::Constant* constant) {
  return llvm::ConstantExpr::getPtrToInt(constant, intptr_type);
}

llvm::Constant* World::CInt2Pointer(llvm::Constant* constant, llvm::Type* ptr_type) {
  if (ptr_type == NULL) ptr_type = object_ptr_type;
  return llvm::ConstantExpr::getIntToPtr(constant, ptr_type);
}

llvm::Constant* World::CCast(llvm::Constant* constant, llvm::Type* ptr_type) {
  if (ptr_type == NULL) ptr_type = object_ptr_type;
  return llvm::ConstantExpr::getPointerCast(constant, ptr_type);
}

void LLVMCodegen::Generate(const char* filename, bool optimize, bool verify_module) {
  llvm::LLVMContext& context(llvm::getGlobalContext());
  llvm::Module module("dart_code", context);

  World world(program_, context, module);

  HeapBuilder builder(world);
  program_->heap()->IterateObjects(&builder);

  RootsBuilder rbuilder(world, &builder);
  world.roots = rbuilder.BuildRoots();

  NativesBuilder nbuilder(world);
  nbuilder.BuildNativeDeclarations();

  FunctionsBuilder fbuilder(world);
  program_->heap()->IterateObjects(&fbuilder);

  GlobalSymbolsBuilder sbuilder(world);
  sbuilder.BuildGlobalSymbols();

  if (verify_module) {
    // Please note that this is pretty time consuming!
    VerifyModule(module);
  }

  if (optimize) {
    OptimizeModule(module);
  }

  SaveModule(module, filename);
}

void LLVMCodegen::VerifyModule(llvm::Module& module) {
  std::string ErrorStr;
  llvm::raw_string_ostream OS(ErrorStr);
  Print::Error("Module verification started ...");
  if (llvm::verifyModule(module, &OS)) {
    Print::Error("Module verification failed:");
    std::cerr << OS.str();
    FATAL("Modul verification failed. Cannot proceed.");
  }
  Print::Error("Module verification passed.");
}

void LLVMCodegen::OptimizeModule(llvm::Module& module) {
  llvm::legacy::FunctionPassManager fpm(&module);

  // TODO: We should find out what other optimization passes would makes sense.
  fpm.add(llvm::createPromoteMemoryToRegisterPass());
  fpm.add(llvm::createCFGSimplificationPass());
  fpm.add(llvm::createConstantPropagationPass());

  for (auto& f : module) fpm.run(f);
}

void LLVMCodegen::SaveModule(llvm::Module& module, const char* filename) {
  // This would dump the LLVM IR in text format to stdout.
  // module.dump();

  std::error_code ec;
  llvm::raw_fd_ostream stream(filename, ec, llvm::sys::fs::F_RW);
  if (ec) FATAL("Could not open output file");
  llvm::WriteBitcodeToFile(&module, stream);
}

// ************ Utilities *******************

// Buffers used for implementing [name].
static int _bit = 0;
static char _buffer[2][1024];

// This function supports vsnprintf() without memory allocation by using two
// static buffers (switching between them, so the result of one call can be used
// as input to another without overriding the result):
char *name(const char* format, ...) {
  _bit++;
  _bit %= 2;

  va_list vargs;
  va_start(vargs, format);
  vsnprintf(&_buffer[_bit][0], 1024, format, vargs);
  va_end(vargs);

  return &_buffer[_bit][0];
}

// Will return a nice string representation of a bytecode.
char *bytecode_string(uint8* bcp) {
  const char* bytecode_formats[Bytecode::kNumBytecodes] = {
#define EACH(name, branching, format, size, stack_diff, print) format,
      BYTECODES_DO(EACH)
#undef EACH
  };
  const char* print_formats[Bytecode::kNumBytecodes] = {
#define EACH(name, branching, format, size, stack_diff, print) print,
      BYTECODES_DO(EACH)
#undef EACH
  };

  Opcode opcode = static_cast<Opcode>(*bcp);
  const char* bytecode_format = bytecode_formats[opcode];
  const char* print_format = print_formats[opcode];

  if (strcmp(bytecode_format, "") == 0) {
    return name(print_format);
  } else if (strcmp(bytecode_format, "B") == 0) {
    return name(print_format, bcp[1]);
  } else if (strcmp(bytecode_format, "I") == 0) {
    return name(print_format, Utils::ReadInt32(bcp + 1));
  } else if (strcmp(bytecode_format, "BB") == 0) {
    return name(print_format, bcp[1], bcp[2]);
  } else if (strcmp(bytecode_format, "IB") == 0) {
    return name(print_format, Utils::ReadInt32(bcp + 1), bcp[5]);
  } else if (strcmp(bytecode_format, "BI") == 0) {
    return name(print_format, bcp[1], Utils::ReadInt32(bcp + 2));
  } else if (strcmp(bytecode_format, "II") == 0) {
    return name(print_format, Utils::ReadInt32(bcp + 1),
               Utils::ReadInt32(bcp + 5));
  }

  return name("Unknown bytecode format %s", bytecode_format);
}

}  // namespace dartino
