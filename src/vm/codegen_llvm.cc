// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/codegen_llvm.h"

#include <stdio.h>
#include <stdarg.h>

#include <algorithm>
#include <iostream>
#include <set>
#include <string>
#include <utility>

#include "src/shared/bytecodes.h"
#include "src/shared/flags.h"
#include "src/shared/names.h"
#include "src/shared/natives.h"
#include "src/shared/selectors.h"

#include "src/vm/interpreter.h"
#include "src/vm/llvm_eh.h"
#include "src/vm/process.h"
#include "src/vm/program_info_block.h"

namespace dartino {

class BasicBlockBuilder;
class IRHelper;

// Natives written in a Forth dialect:

void ForthByteCode::Init() {
  if (!initialized && source) {
    char last = source[strlen(source) - 1];
    switch (last) {
      case '!':
        instruction = F_ASSIGN;
        break;
      case '@':
        instruction = F_READ;
        break;
      case ':':
        instruction = F_LABEL;
        label1 = source;
        break;
      case ')':
        ASSERT(strlen(source) > 2);
        ASSERT(source[strlen(source) - 2] == '(');
        instruction = F_EXPAND_MACRO;
        break;
      default:
        // Strings in in this Forth dialect should end in a special character
        // that determines their function.
        UNREACHABLE();
    }
    initialized = true;
  }
}

class ForthFunction {
 public:
  ForthFunction(const char* name, std::vector<const char*> vars,
                std::vector<ForthByteCode> codes)
      : name_(name), variable_names_(vars), codes_(codes) {}

  void Init() {
    if (!initialized_) Init(&codes_);
    initialized_ = true;
  }

  void Init(std::vector<ForthByteCode>* codes) {
    for (ForthByteCode& bc : *codes) {
      bc.Init();
      if (bc.instruction == F_LABEL) {
        labels_.push_back(bc.label1);
      }
    }
  }

  void Codegen(World* w, BasicBlockBuilder* b, IRHelper* h) {
    std::vector<llvm::Value*> empty_stack;
    Codegen(w, b, h, &empty_stack);
  }

  void Codegen(World* w, BasicBlockBuilder* b, IRHelper* h,
               std::vector<llvm::Value*>* forth_stack);

 private:
  const char* name_;
  std::vector<const char*> variable_names_;
  std::vector<ForthByteCode> codes_;
  std::vector<const char*> labels_;
  bool initialized_ = false;
};

static void Push(std::vector<llvm::Value*>* forth_stack, llvm::Value* x) {
  forth_stack->push_back(x);
}

static llvm::Value* Pop(std::vector<llvm::Value*>* forth_stack) {
  ASSERT(forth_stack->size() != 0);
  auto x = forth_stack->back();
  forth_stack->pop_back();
  return x;
}

// Snippets of code used to implement Dartino byte codes (add, sub, etc.)

// On input stack has argument (top of stack) and receiver.  On exit stack has
// no-overflow flag (top of stack) and result (invalid on overflow).
static ForthFunction kInvokeAddMacro("InvokeAdd", {}, {
    F_SADD_OVERFLOW, F_NOT
});

static ForthFunction kInvokeSubMacro("InvokeSub", {}, {
    F_SSUB_OVERFLOW, F_NOT
});

// If we mul two 0-tagged integers together we get an answer that is 2x too
// big, so shift one of them down first.
static ForthFunction kInvokeMulMacro("InvokeMul", {}, {
    1, F_ASHR, F_SMUL_OVERFLOW, F_NOT
});

static ForthFunction kInvokeShrMacro("InvokeShr", {"int shift",
                                                   "int result",
                                                   "bool no_overflow"}, {
    "shift!",
  // Negative shift gives a bounds error.
    "shift@", (uword)0, F_SLT, { F_IF_ELSE, "oob", "not_negative"},
  // Check shift is max 63 (126 tagged). TODO(erikcorry): Fix for 32 bit
  // platform.
  "not_negative:", "shift@", 126, F_UGE, { F_IF_ELSE, "too_large", "ok"},
  "too_large:", 126, "shift!", { F_GOTO, "ok" },
  // The receiver stays on the Forth stack until here, where we use it.
  // Untag the shift distance by shifting once before using it.
  "ok:", "shift@", 1, F_ASHR, F_ASHR,
    1, F_NOT, F_AND, "result!", F_BIT_TRUE, "no_overflow!",
    { F_GOTO, "done" },
  "oob:", (uword)0, "result!", F_BIT_FALSE, "no_overflow!",
    { F_GOTO, "done" },
  "done:",
    "result@", "no_overflow@"
});

// Snippets of code used to implement natives.

static ForthFunction kSmiNegateMacro("SmiNegate", {}, {
    F_STACK0, 0x8000000000000000ul, F_TO_PTR, F_EQ,
        { F_IF_ELSE, "error", "ok" },
  "ok:", F_STACK0, F_TO_INT, F_NEG, F_TO_PTR, F_RETURN,
  "error:", Failure::kTaggedIndexOutOfBounds, F_TO_PTR, F_PUSH
});

static ForthFunction kSmiMulMacro("SmiMul", {}, {
    F_STACK1, F_SMI_CHECK, { F_IF_ELSE, "smis", "wat" },
  "smis:", F_STACK0, F_TO_INT, F_STACK1, F_UNTAG, F_SMUL_OVERFLOW,
    {F_IF_ELSE, "wat", "ok"},
  // The 'if' popped one of the values that the SMUL pushed (the overflow
  // flag), but the actual answer is still there, and gets popped by the next
  // line.  It's somewhat dodgy to have a value on the stack across a branch...
  "ok:", F_TO_PTR, F_RETURN,
  "wat:", Failure::kTaggedWrongArgumentType, F_TO_PTR, F_PUSH
});

static ForthFunction kSmiShrMacro("SmiShr", {"int shift", "result"}, {
    F_STACK1, F_SMI_CHECK, { F_IF_ELSE, "smis", "wat" },
  "smis:", F_STACK1, F_UNTAG, "shift!",
    "shift@", (uword)0, F_SLT, { F_IF_ELSE, "oob", "not_negative"},
  "not_negative:", "shift@", 63, F_UGE, { F_IF_ELSE, "too_large", "ok"},
  "too_large:", 63, "shift!", { F_GOTO, "ok" },
  "ok:", F_STACK0, F_TO_INT, "shift@", F_ASHR,
    1, F_NOT, F_AND, F_TO_PTR, F_RETURN,
  "oob:", Failure::kTaggedIndexOutOfBounds, F_TO_PTR, "result!",
    {F_GOTO, "handle_error"},
  "wat:", Failure::kTaggedWrongArgumentType, F_TO_PTR, "result!",
    {F_GOTO, "handle_error"},
  "handle_error:", "result@", F_PUSH
});

static ForthFunction kStringLengthMacro("StringLength", {}, {
    F_STACK0, BaseArray::kLengthOffset, F_LOAD, F_RETURN,
  "error:", (uword)0, F_TO_PTR, F_PUSH
});

// arrayLoad: Takes BaseArray and index n the array (in words).  Adds the
// header size of BaseArray in words, and then performs tagged load.
// TODO(erikcorry): We should shift by 2, not 3 for 32 bit target.
static ForthFunction kArrayLoadMacro("arrayLoad", {}, {
  BaseArray::kSize / kWordSize, F_ADD, 3, F_SHL, F_LOAD
});

static ForthFunction kListLengthNative("ListLength",
  {"list", "length"}, {
    F_STACK0, Instance::kSize, F_LOAD, "list!",
    "list@", BaseArray::kLengthOffset, F_LOAD, "length!",
    "length@", F_RETURN,
  "error:", "length@", F_PUSH
});

static ForthFunction kListIndexGetNative("ListIndexGet",
  {"list", "length", "index", "result"}, {
    F_STACK0, Instance::kSize, F_LOAD, "list!",
    "list@", BaseArray::kLengthOffset, F_LOAD, "length!",
    "length@", F_SMI_CHECK, {F_IF_ELSE, "smi_index", "wat"},
  "smi_index:",
    F_STACK1, "index!",
    "index@", "length@", F_UGE, {F_IF_ELSE, "oob", "load"},
  "load:",
    "list@", "index@", F_UNTAG, "arrayLoad()", F_RETURN,
  "wat:",
    Failure::kTaggedWrongArgumentType, F_TO_PTR, "result!",
    {F_GOTO, "error"},
  "oob:",
    Failure::kTaggedIndexOutOfBounds, F_TO_PTR, "result!",
    {F_GOTO, "error"},
  "error:", "result@", F_PUSH
});

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
      return 0;
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
  explicit NativesBuilder(World* world) : w(world) {}

  void BuildNativeDeclarations() {
    std::vector<llvm::Type*> argument_types = {w->process_ptr_type,
                                               w->arguments_ptr_type};
    auto function_type =
        llvm::FunctionType::get(w->object_ptr_type, argument_types, false);

#define N(e, c, n, d)                                                        \
  /* Make sure we push the native at the correct location in the array */    \
  ASSERT(w->natives_.size() == k##e);                                        \
  w->natives_.push_back(                                                     \
      llvm::Function::Create(function_type, llvm::Function::ExternalLinkage, \
                             "Native_" #e, w->module_));

    NATIVES_DO(N)
#undef N
  }

 private:
  World* w;
};

class DartinoGC : public llvm::GCStrategy {
 public:
  DartinoGC() {
    UseStatepoints = true;
    // These options are all gc.root specific, we specify them so that the
    // gc.root lowering code doesn't run.
    InitRoots = false;
    NeededSafePoints = 0;
    UsesMetadata = false;
    CustomRoots = false;
  }
  llvm::Optional<bool> isGCManagedPointer(const llvm::Type* Ty) const override {
    // Method is only valid on pointer typed values.
    const llvm::PointerType* PT = llvm::cast<llvm::PointerType>(Ty);
    // We arbitrarily pick addrspace(1) as our
    // GC managed heap.  We know that a pointer into this heap needs to be
    // updated and that no other pointer does.  Note that addrspace(1) is used
    // only as an example, it has no special meaning, and is not reserved for
    // GC usage.
    return (1 == PT->getAddressSpace());
  }
};

static llvm::GCRegistry::Add<DartinoGC> A("dartino", "Dartino GC strategy");

// Builds up constant objects for all [HeapObject]s it is called with.
class HeapBuilder : public HeapObjectVisitor {
 public:
  explicit HeapBuilder(World* world) : w(world) {}

  virtual int Visit(HeapObject* object) {
    BuildConstant(object);
    return object->Size();
  }

 private:
  friend class BasicBlockBuilder;

  // Returns untagged space-zero.
  llvm::Constant* BuildConstant(Object* raw_object) {
    if (!raw_object->IsHeapObject()) {
      Smi* smi = Smi::cast(raw_object);
      if (Smi::IsValidAsPortable(smi->value())) {
        return w->CInt2Pointer(w->CSmi(smi->value()),
                               w->object_ptr_aspace0_type);
      } else {
        return BuildLargeInteger(smi->value());
      }
    }

    HeapObject* object = HeapObject::cast(raw_object);

    llvm::Constant* value = w->tagged_aspace0[object];
    if (value != NULL) return value;

    auto ot = w->object_ptr_type;

    // TODO(llvm):
    // Missing are:
    //    * BaseArray->ByteArray
    //    * BaseArray->TwoByteString
    //
    // We should not need these:
    //    * Boxed
    //    * BaseArray->Stack
    //    * Instance->Coroutine
    if (object->IsFunction()) {
      value = BuildFunctionConstant(Function::cast(object));
    } else if (object->IsClass()) {
      value = BuildClassConstant(Class::cast(object));
    } else if (object->IsArray()) {
      value = BuildArrayConstant(Array::cast(object));
    } else if (object->IsByteArray()) {
      value = BuildByteArrayConstant(ByteArray::cast(object));
    } else if (object->IsInstance()) {
      value = BuildInstanceConstant(Instance::cast(object));
    } else if (object->IsDispatchTableEntry()) {
      value = BuildDispatchTableEntryConstant(DispatchTableEntry::cast(object));
    } else if (object->IsOneByteString()) {
      value = BuildOneByteStringConstant(OneByteString::cast(object));
    } else if (object->IsInitializer()) {
      value = BuildInitializerConstant(Initializer::cast(object));
    } else if (object->IsLargeInteger()) {
      value = BuildLargeInteger(LargeInteger::cast(object)->value());
    } else if (object->IsDouble()) {
      value = BuildDoubleConstant(Double::cast(object)->value());
    } else {
      UNREACHABLE();
      auto null = llvm::ConstantStruct::getNullValue(ot);
      value = new llvm::GlobalVariable(*w->module_, ot, true,
                                       llvm::GlobalValue::ExternalLinkage, null,
                                       name("Object_%p", object));
    }

    // Put tagging information on.
    w->untagged_aspace0[object] = value;
    w->tagged_aspace1[object] = w->CTag(value, w->object_ptr_type);
    ASSERT(llvm::dyn_cast<llvm::PointerType>(value->getType())
               ->getAddressSpace() != kGCNameSpace);
    value = w->CTagAddressSpaceZero(value, value->getType());
    w->tagged_aspace0[object] = value;
    return value;
  }

  llvm::Constant* BuildArrayConstant(Array* array) {
    auto klass = Class::cast(array->get_class());
    auto llvm_klass = BuildConstant(klass);

    auto ho = llvm::ConstantStruct::get(w->heap_object_type, {llvm_klass});
    auto length = w->CSmi(array->length());
    std::vector<llvm::Constant*> array_entries = {ho, length};
    auto llvm_array = llvm::ConstantStruct::get(w->array_header, array_entries);

    auto full_array_header = w->ObjectArrayType(
        array->length(), w->object_ptr_aspace0_type, "Array");
    std::vector<llvm::Constant*> entries;
    entries.push_back(llvm_array);
    for (int i = 0; i < array->length(); i++) {
      Object* value = array->get(i);
      if (value->IsHeapObject()) {
        entries.push_back(w->CCast(BuildConstant(value)));
      } else {
        entries.push_back(w->CCast(w->CInt2Pointer(
            w->CSmi(Smi::cast(value)->value()), w->object_ptr_aspace0_type)));
      }
    }
    auto full_array = llvm::ConstantStruct::get(full_array_header, entries);
    return new llvm::GlobalVariable(
        *w->module_, full_array_header, true,
        llvm::GlobalValue::ExternalLinkage, full_array,
        name("ArrayInstance_%p__%d", array, array->length()));
  }

  llvm::Constant* BuildByteArrayConstant(ByteArray* array) {
    auto klass = Class::cast(array->get_class());
    auto llvm_klass = BuildConstant(klass);

    auto ho = llvm::ConstantStruct::get(w->heap_object_type, {llvm_klass});
    auto length = w->CSmi(array->length());
    std::vector<llvm::Constant*> array_entries = {ho, length};
    auto llvm_array = llvm::ConstantStruct::get(w->array_header, array_entries);

    auto full_array_header =
        w->ObjectArrayType(array->length(), w->int8_type, "ByteArray");
    std::vector<llvm::Constant*> entries;
    entries.push_back(llvm_array);
    for (int i = 0; i < array->length(); i++) {
      entries.push_back(w->CInt8(array->get(i)));
    }
    auto full_array = llvm::ConstantStruct::get(full_array_header, entries);
    return new llvm::GlobalVariable(
        *w->module_, full_array_header, true,
        llvm::GlobalValue::ExternalLinkage, full_array,
        name("ByteArrayInstance_%p__%d", array, array->length()));
  }

  llvm::Constant* BuildClassConstant(Class* klass) {
    // TODO(llvm): Maybe find out a better way to handle `null`. Seems like we
    // can't
    // make cycles in constants. Our cycles are at least these two:
    //   a)  MetaClass.class -> MetaClass
    //   b)  NullObject.class -> NullClass.superclass -> NullObject
    auto null = llvm::ConstantStruct::getNullValue(w->class_ptr_type);

    bool is_meta_class = klass->get_class() == klass;

    auto innerType = w->heap_object_type->getContainedType(0);
    auto llvm_klass = w->CCast(
        is_meta_class ? null : BuildConstant(klass->get_class()), innerType);
    auto heap_object =
        llvm::ConstantStruct::get(w->heap_object_type, {llvm_klass});

    bool is_root = !klass->has_super_class();
    bool has_methods = klass->has_methods();

    std::vector<llvm::Constant*> class_entries = {
        heap_object, is_root ? w->CCast(null, w->class_ptr_type)
                             : BuildConstant(klass->super_class()),
        BuildInstanceFormat(klass), w->CWord(klass->id()),
        w->CSmi(klass->child_id()),
        has_methods
            ? w->CCast(BuildConstant(klass->methods()), w->array_header_ptr)
            : w->CCast(null, w->array_header_ptr),
    };

    auto llvm_class = llvm::ConstantStruct::get(w->class_type, class_entries);
    auto global_variable = new llvm::GlobalVariable(
        *w->module_, w->class_type, true, llvm::GlobalValue::ExternalLinkage,
        llvm_class, name("Class_%p", klass), nullptr);
    return global_variable;
  }

  llvm::Constant* BuildFunctionConstant(Function* function) {
    auto type = w->FunctionType(function->arity());
    auto llvm_function =
        llvm::Function::Create(type, llvm::Function::ExternalLinkage,
                               name("Function_%p", function), w->module_);
    llvm_function->setGC("statepoint-example");
    w->llvm_functions[function] = llvm_function;

    llvm::AttributeSet attr_set = llvm_function->getAttributes();
    int first_argument_index = 1;
    attr_set = attr_set.addDereferenceableAttr(
        *w->context, first_argument_index, sizeof(Process));
    llvm_function->setAttributes(attr_set);

    auto klass = llvm::ConstantStruct::get(
        w->heap_object_type, {BuildConstant(function->get_class())});

    std::vector<llvm::Constant*> function_entries = {
        klass,
        w->CSmi(4),  // bytecode size
        w->CSmi(0),  // literals size
        w->CSmi(function->arity()),
        w->CPointer2Int(llvm_function),  // [word] containing function pointer.
    };

    auto function_object =
        llvm::ConstantStruct::get(w->function_type, function_entries);

    w->GiveIdToFunction(llvm_function);

    return new llvm::GlobalVariable(
        *w->module_, w->function_type, true, llvm::GlobalValue::ExternalLinkage,
        function_object, name("FunctionObject_%p", function));
  }

  llvm::Constant* BuildInstanceConstant(Instance* instance) {
    auto ho = llvm::ConstantStruct::get(w->heap_object_type,
                                        {BuildConstant(instance->get_class())});
    auto inst = llvm::ConstantStruct::get(
        w->instance_type, {ho, w->CWord(instance->FlagsBits())});

    int nof = instance->get_class()->NumberOfInstanceFields();

    auto full_inst_type = w->InstanceType(nof);
    std::vector<llvm::Constant*> instance_entries = {inst};
    for (int i = 0; i < nof; i++) {
      instance_entries.push_back(
          w->CCast(BuildConstant(instance->GetInstanceField(i))));
    }

    auto full_inst =
        llvm::ConstantStruct::get(full_inst_type, instance_entries);
    const char* instance_name = NULL;
    if (instance->IsTrue()) {
      instance_name = name("true__", instance);
    } else if (instance->IsFalse()) {
      instance_name = name("false__", instance);
    } else if (instance->IsNull()) {
      instance_name = name("null__", instance);
    } else {
      instance_name = name("InstanceObject_%p__%d", instance, nof);
    }
    return new llvm::GlobalVariable(*w->module_, full_inst_type, true,
                                    llvm::GlobalValue::ExternalLinkage,
                                    full_inst, instance_name);
  }

  llvm::Constant* BuildDispatchTableEntryConstant(DispatchTableEntry* entry) {
    auto ho = llvm::ConstantStruct::get(w->heap_object_type,
                                        {BuildConstant(entry->get_class())});

    auto target = BuildConstant(entry->target());
    std::vector<llvm::Constant*> entries = {
        ho,
        w->CCast(target),
        w->CCast(w->llvm_functions[entry->target()]),
        w->CCast(BuildConstant(entry->offset())),
        w->CInt2Pointer(w->CSmi(entry->selector()), w->object_ptr_aspace0_type),
    };

    auto full_inst = llvm::ConstantStruct::get(w->dte_type, entries);
    return new llvm::GlobalVariable(
        *w->module_, w->dte_type, true, llvm::GlobalValue::ExternalLinkage,
        full_inst, name("DispatchTableEntry_%p", entry));
  }

  llvm::Constant* BuildOneByteStringConstant(OneByteString* string) {
    auto int8_array_header =
        llvm::ArrayType::get(w->int8_type, string->length());

    std::vector<llvm::Constant*> bytes;
    for (int i = 0; i < string->length(); i++) {
      int byte = string->get_char_code(i);
      bytes.push_back(llvm::ConstantInt::getIntegerValue(
          w->int8_type, llvm::APInt(8, byte, false)));
    }

    auto klass = Class::cast(string->get_class());
    auto llvm_klass = BuildConstant(klass);

    auto ho = llvm::ConstantStruct::get(w->heap_object_type, {llvm_klass});
    auto length = w->CSmi(string->length());
    std::vector<llvm::Constant*> array_entries = {ho, length};
    auto array = llvm::ConstantStruct::get(w->array_header, array_entries);

    auto obs = llvm::ConstantStruct::get(w->onebytestring_type,
                                         {array, w->CSmi(string->length())});

    auto full_obs_type = w->OneByteStringType(string->length());
    std::vector<llvm::Constant*> entries;
    entries.push_back(obs);
    entries.push_back(llvm::ConstantArray::get(int8_array_header, bytes));
    auto full_array = llvm::ConstantStruct::get(full_obs_type, entries);
    return new llvm::GlobalVariable(
        *w->module_, full_obs_type, true, llvm::GlobalValue::ExternalLinkage,
        full_array, name("OneByteString_%p__%d", string, string->length()));
  }

  llvm::Constant* BuildInitializerConstant(Initializer* initializer) {
    // Ensure we've the initializer function built:
    BuildConstant(initializer->function());

    auto ho = llvm::ConstantStruct::get(
        w->heap_object_type, {BuildConstant(initializer->get_class())});
    std::vector<llvm::Constant*> entries = {
        ho,                                                    // heap object
        w->CCast(w->llvm_functions[initializer->function()]),  // machine code
    };
    auto initializer_object =
        llvm::ConstantStruct::get(w->initializer_type, entries);
    return new llvm::GlobalVariable(*w->module_, w->initializer_type, true,
                                    llvm::GlobalValue::ExternalLinkage,
                                    initializer_object,
                                    name("InitializerObject_%p", initializer));
  }

  llvm::Constant* BuildLargeInteger(int64 value) {
    auto large_integer_klass =
        BuildConstant(w->program_->large_integer_class());

    auto ho =
        llvm::ConstantStruct::get(w->heap_object_type, {large_integer_klass});
    std::vector<llvm::Constant*> entries = {
        ho,                // heap object
        w->CInt64(value),  // 64-bit int
    };
    auto large_integer =
        llvm::ConstantStruct::get(w->largeinteger_type, entries);
    return new llvm::GlobalVariable(*w->module_, w->largeinteger_type, true,
                                    llvm::GlobalValue::ExternalLinkage,
                                    large_integer,
                                    name("LargeIntegerObject_%p", value));
  }

  llvm::Constant* BuildDoubleConstant(double value) {
    auto double_klass = BuildConstant(w->program_->double_class());

    auto ho = llvm::ConstantStruct::get(w->heap_object_type, {double_klass});
    std::vector<llvm::Constant*> entries = {
        ho,                 // heap object
        w->CDouble(value),  // 64-bit double
    };
    auto double_object = llvm::ConstantStruct::get(w->double_type, entries);
    return new llvm::GlobalVariable(*w->module_, w->double_type, true,
                                    llvm::GlobalValue::ExternalLinkage,
                                    double_object, "DoubleObject");
  }

  llvm::Constant* BuildInstanceFormat(Class* klass) {
    uintptr_t value =
        reinterpret_cast<uintptr_t>(klass->instance_format().as_smi());
    return w->CWord(value);
  }

  World* w;
};

// Helper methods encapsulating some boilerplate code using `llvm::IRBuilder`.
class IRHelper {
 public:
  IRHelper(World* world, llvm::IRBuilder<>* builder) : w(world), b(builder) {}

  llvm::Constant* BuildCString(const char* name) {
    int len = strlen(name);
    auto int8_array_header = llvm::ArrayType::get(w->int8_type, len + 2);

    std::vector<llvm::Constant*> bytes;
    for (int i = 0; i < len; i++) {
      int byte = name[i];
      bytes.push_back(llvm::ConstantInt::getIntegerValue(
          w->int8_type, llvm::APInt(8, byte, false)));
    }
    bytes.push_back(llvm::ConstantInt::getIntegerValue(
        w->int8_type, llvm::APInt(8, '\n', false)));
    bytes.push_back(llvm::ConstantInt::getIntegerValue(
        w->int8_type, llvm::APInt(8, '\0', false)));

    auto full_array = llvm::ConstantArray::get(int8_array_header, bytes);
    auto var = new llvm::GlobalVariable(*w->module_, int8_array_header, true,
                                        llvm::GlobalValue::ExternalLinkage,
                                        full_array, "DebugString");
    return w->CCast(var, w->int8_ptr_type);
  }

  llvm::Value* Cast(llvm::Value* value, llvm::Type* ptr_type = NULL,
                    const char* name = "instance") {
    if (ptr_type == NULL) ptr_type = w->object_ptr_type;
    return b->CreateBitCast(value, ptr_type, name);
  }

  llvm::Value* CastToNonGC(llvm::Value* value, llvm::Type* ptr_type,
                           const char* name = "instance") {
    return b->CreatePointerBitCastOrAddrSpaceCast(value, ptr_type, name);
  }

  llvm::Function* TaggedRead() {
    return llvm::Intrinsic::getDeclaration(w->module_, llvm::Intrinsic::tagread,
                                           {w->object_ptr_ptr_type});
  }

  llvm::Function* TaggedWrite() {
    return llvm::Intrinsic::getDeclaration(
        w->module_, llvm::Intrinsic::tagwrite,
        {w->object_ptr_type, w->object_ptr_type, w->object_ptr_ptr_type});
  }

  llvm::Value* RememberedSetBiasGEP(llvm::Value* process) {
    std::vector<llvm::Value*> bias_index = {
        w->CInt(Process::kRememberedSetBiasOffset / kWordSize)};
    return b->CreateGEP(process, bias_index, "bias_gep");
  }

  void WriteFieldNoWriteBarrier(llvm::Value* tagged_cell, llvm::Value* value) {
    auto pointer =
        b->CreatePointerBitCastOrAddrSpaceCast(tagged_cell, w->int8_ptr_type);
    auto gep = b->CreateGEP(pointer, {w->CInt(-1)});
    gep = b->CreatePointerCast(gep, w->object_ptr_ptr_unsafe_type);
    auto store = b->CreateStore(value, gep);
    store->setMetadata(llvm::LLVMContext::MD_tbaa,
                       w->regular_field_alias_analysis_node);
  }

  llvm::Function* SmiToInt() {
    auto intrinsic = w->bits_per_word == 64 ? llvm::Intrinsic::smitoint64
                                            : llvm::Intrinsic::smitoint;
    return llvm::Intrinsic::getDeclaration(w->module_, intrinsic,
                                           {w->object_ptr_type});
  }

  llvm::Function* IntToSmi() {
    auto intrinsic = w->bits_per_word == 64 ? llvm::Intrinsic::inttosmi64
                                            : llvm::Intrinsic::inttosmi;
    return llvm::Intrinsic::getDeclaration(w->module_, intrinsic,
                                           {w->intptr_type});
  }

  llvm::Value* DecodeSmi(llvm::Value* value,
                         const char* name = "untagged_smi") {
    return b->CreateCall(SmiToInt(), {value}, name);
  }

  llvm::Value* EncodeSmi(llvm::Value* value, const char* name = "smi") {
    return b->CreateCall(IntToSmi(), {value}, name);
  }

  llvm::Value* GetArrayPointer(llvm::Value* array, int index) {
    std::vector<llvm::Value*> indices = {
        w->CInt(Array::kSize / kWordSize + index)};
    auto receiver = b->CreateBitCast(array, w->object_ptr_ptr_type);
    // Creates a tagged, GC-address-space inner pointer into the array.
    auto gep = b->CreateGEP(receiver, indices, "tagged_array_gep");
    return gep;
  }

  llvm::Value* GetArrayPointer(llvm::Value* array, llvm::Value* index) {
    std::vector<llvm::Value*> indices = {
        b->CreateAdd(index, w->CWord(Array::kSize / kWordSize))};
    auto receiver = b->CreateBitCast(array, w->object_ptr_ptr_type);
    // Creates a tagged, GC-address-space inner pointer into the array.
    auto gep = b->CreateGEP(receiver, indices, "tagged_array_gep");
    return gep;
  }

  // We don't have a read barrier, so we don't need an intrinsic to hide the
  // load. This makes the load available for the optimizer.
  llvm::Value* LoadField(llvm::Value* gep, const char* name = "field",
                         bool invariant = false, int size = 0) {
    ASSERT(gep->getType() == w->object_ptr_ptr_type);
    // Untag before loading, but leave address-space-1 on the pointer, so it is
    // GC marked.  The GC should still be able to distinguish this pointer from
    // a Smi because it gets base-derived pairs, and the base will still be
    // tagged.
    auto byte_gep = b->CreatePointerCast(gep, w->int8_ptr_aspace1_type);
    auto field_address = b->CreateGEP(byte_gep, {w->CInt(-1)});
    auto answer = b->CreateLoad(
        b->CreatePointerCast(field_address, w->object_ptr_ptr_type, name));
    if (invariant) {
      answer->setMetadata(llvm::LLVMContext::MD_invariant_load,
                          llvm::MDNode::get(*w->context, llvm::None));
      if (size) {
        answer->setMetadata(
            llvm::LLVMContext::MD_dereferenceable,
            llvm::MDNode::get(*w->context, llvm::ConstantAsMetadata::get(
                                               w->CInt64(Class::kSize))));
      }
    }
    answer->setMetadata(llvm::LLVMContext::MD_tbaa,
                        w->regular_field_alias_analysis_node);
    return answer;
  }

  llvm::Value* LoadField(llvm::Value* arg, int offset,
                         const char* name = "field", bool invariant = false,
                         int size = 0) {
    auto receiver =
        b->CreatePointerBitCastOrAddrSpaceCast(arg, w->int8_ptr_aspace1_type);
    // Untag before loading, but leave address-space-1 on the pointer, so it is
    // GC marked.  The GC should still be able to distinguish this pointer from
    // a Smi because it gets base-derived pairs, and the base will still be
    // tagged.
    std::vector<llvm::Value*> indices = {
        w->CInt((w->bits_per_word * offset / (kWordSize * 8)) - 1)};
    auto gep = b->CreateGEP(receiver, indices, "untagged_gep");
    auto answer =
        b->CreateLoad(b->CreatePointerCast(gep, w->object_ptr_ptr_type), name);
    if (invariant) {
      answer->setMetadata(llvm::LLVMContext::MD_invariant_load,
                          llvm::MDNode::get(*w->context, llvm::None));
      if (size) {
        answer->setMetadata(
            llvm::LLVMContext::MD_dereferenceable,
            llvm::MDNode::get(*w->context, llvm::ConstantAsMetadata::get(
                                               w->CInt64(Class::kSize))));
      }
    }
    answer->setMetadata(llvm::LLVMContext::MD_tbaa,
                        w->regular_field_alias_analysis_node);
    return answer;
  }

  void StoreField(int offset, llvm::Value* receiver, llvm::Value* value) {
    auto slot_type_receiver = b->CreatePointerBitCastOrAddrSpaceCast(
        receiver, w->object_ptr_ptr_type);
    std::vector<llvm::Value*> indices = {w->CInt(offset / kWordSize)};
    // Creates a tagged, GC-address-space inner pointer into the object.
    auto slot = b->CreateGEP(slot_type_receiver, indices, "tagged_gep");
    b->CreateCall(TaggedWrite(), {receiver, value, slot});
  }

  // Both the object pointer and the result are guaranteed to be constants and
  // so don't need to be tracked by the GC. The input pointer is tagged though.
  llvm::Value* LoadFieldAddressSpaceZero(llvm::Value* object, int offset,
                                         const char* name) {
    auto receiver_as_byte_pointer =
        b->CreatePointerBitCastOrAddrSpaceCast(object, w->int8_ptr_type);
    auto slot = b->CreateGEP(receiver_as_byte_pointer, {w->CInt(offset - 1)});
    auto value =
        b->CreateLoad(Cast(slot, w->object_ptr_aspace0_ptr_aspace0_type), name);
    value->setMetadata(llvm::LLVMContext::MD_invariant_load,
                       llvm::MDNode::get(*w->context, llvm::None));
    // TODO(erikcorry): Use llvm::LLVMContext::MD_never_faults when we have the
    // right LLVM version everywhere.
    value->setMetadata("never.faults",
                       llvm::MDNode::get(*w->context, llvm::None));
    return value;
  }

  llvm::Value* LoadClass(llvm::Value* heap_object) {
    auto gc_pointer = LoadField(heap_object, HeapObject::kClassOffset, "class",
                                true, Class::kSize);
    return b->CreatePointerBitCastOrAddrSpaceCast(gc_pointer,
                                                  w->class_ptr_type);
  }

  llvm::Value* LoadArrayEntry(llvm::Value* array, llvm::Value* offset) {
    return b->CreateCall(TaggedRead(), {GetArrayPointer(array, offset)});
  }

  // Loads instance format as an integer. This is an untagged int at LLVM
  // runtime.
  llvm::Value* LoadInstanceFormat(llvm::Value* klass) {
    auto smi_address_space0 = LoadFieldAddressSpaceZero(
        klass, Class::kInstanceFormatOffset, "instance_format");
    return b->CreatePtrToInt(smi_address_space0, w->intptr_type);
  }

  llvm::Value* LoadClassId(llvm::Value* klass) {
    auto smi_address_space0 = LoadFieldAddressSpaceZero(
        klass, Class::kIdOrTransformationTargetOffset, "class_id");
    return b->CreatePtrToInt(smi_address_space0, w->intptr_type);
  }

  // Loads the statics array, which is an on-heap (but in the
  // read-only-constants part of the heap) array pointed to by the off-heap
  // Process object.  The pointer is already tagged.
  llvm::Value* LoadStaticsArray(llvm::Value* process) {
    std::vector<llvm::Value*> statics_indices = {
        w->CInt(Process::kStaticsOffset / kWordSize)};
    auto gep = b->CreateGEP(Cast(process, w->object_ptr_ptr_unsafe_type),
                            statics_indices, "statics_entry");
    return b->CreateLoad(gep);
  }

  llvm::Value* LoadInitializerCode(llvm::Value* initializer, int arity) {
    auto entry =
        LoadField(initializer, Initializer::kFunctionOffset, "function");
    return b->CreatePointerBitCastOrAddrSpaceCast(entry,
                                                  w->FunctionPtrType(arity));
  }

  llvm::Value* CreateSmiCheck(llvm::Value* object) {
    return b->CreateIsNull(
        b->CreateAnd(b->CreatePtrToInt(object, w->intptr_type), w->CWord(1)));
  }

  llvm::Value* CreateFailureCheck(llvm::Value* object) {
    return b->CreateICmpEQ(
        b->CreateAnd(b->CreatePtrToInt(object, w->intptr_type),
                     w->CWord(Failure::kTagMask)),
        w->CWord(Failure::kTag));
  }

  // Assumes we have a failure of some sort, and checks for a retry-after-gc
  // failure.
  llvm::Value* CreateRetryAfterGCCheck(llvm::Value* object) {
    return b->CreateIsNull(
        b->CreateAnd(b->CreatePtrToInt(object, w->intptr_type),
                     w->CWord(Failure::kTypeMask)));
  }

  llvm::Value* Null() {
    return llvm::ConstantStruct::getNullValue(w->object_ptr_type);
  }

 private:
  World* w;
  llvm::IRBuilder<>* b;
};

class BasicBlockBuilder {
 public:
  // bcp & fp & empty
  static const int kAuxiliarySlots = 3;

  struct SubroutineEntry {
    SubroutineEntry() {}

    SubroutineEntry(int counter, llvm::Value* marker)
        : counter(counter), marker(marker) {}

    int counter;          // Number of exits this subroutine has.
    llvm::Value* marker;  // Slot that contains the exit number.
    llvm::Instruction*
        end;  // End of subroutine, a place to attach new exit points.
  };

  BasicBlockBuilder(World* world, Function* function,
                    llvm::Function* llvm_function, llvm::IRBuilder<>* builder,
                    const std::vector<std::pair<int, int>>& ranges)
      : w(world),
        function_(function),
        llvm_function_(llvm_function),
        b(builder),
        context(w->context),
        llvm_process_(NULL),
        h(w, builder),
        stack_pos_(0),
        max_stack_height_(0),
        catch_ranges_(ranges) {
    // We make an extra basic block for loading arguments and jump to the basic
    // block corresponding to BCI 0, because sometimes we'll have loops going
    // back to BCI0 (which LLVM doesn't allow).
    bb_entry_ =
        llvm::BasicBlock::Create(*context, name("entry"), llvm_function_);
    for (auto p : ranges) {
      catch_block_bodies[p.second] =
          llvm::BasicBlock::Create(*context, name("excont"), llvm_function_);
    }
  }
  ~BasicBlockBuilder() {}

  // Records that we will need a new basic block at [bci] with [stack_height].
  void AddBasicBlockAtBCI(int bci, int stack_height) {
    auto pair = bci2bb_.find(bci);
    if (pair == bci2bb_.end()) {
      bci2bb_[bci] =
          llvm::BasicBlock::Create(*context, name("bb%d", bci), llvm_function_);
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
    if (b->GetInsertBlock() != pair->second) {
      b->SetInsertPoint(pair->second);
      stack_pos_ = bci2sh_[bci];
    }
  }

  void SetProcess(llvm::Value* process) {
    ASSERT(llvm_process_ == NULL);
    llvm_process_ = process;
  }

  // Methods for generating code inside one basic block.
  //
  int stack_pos() { return stack_pos_; }
  void set_stack_pos(int pos) { stack_pos_ = pos; }

  void DoPrologue() { b->SetInsertPoint(bb_entry_); }
  void TerminateEntryBlock() {
    // Now that all locals have been added to the entry block, append a branch
    // to the actual start of the function.
    b->SetInsertPoint(bb_entry_);
    b->CreateBr(GetBasicBlockAt(0));
  }

  void ScanForUseLLVM() {
    int bci = 0;
    while (true) {
      uint8* bcp = function_->bytecode_address_for(bci);
      Opcode opcode = static_cast<Opcode>(*bcp);
      switch (opcode) {
        case kLoadConst: {
          Object* constant = Function::ConstantForBytecode(
              function_->bytecode_address_for(bci));
          if (constant->IsOneByteString()) {
            OneByteString* str = OneByteString::cast(constant);
            if (str->length() == 8 && str->get_char_code(0) == 'u' &&
                str->get_char_code(1) == 's' && str->get_char_code(2) == 'e' &&
                str->get_char_code(3) == ' ' && str->get_char_code(4) == 'l' &&
                str->get_char_code(5) == 'l' && str->get_char_code(6) == 'v' &&
                str->get_char_code(7) == 'm') {
              use_llvm_ = true;
              return;
            }
          }
          break;
        }

        case kMethodEnd:
          return;

        default:
          break;
      }
      bci = bci + Bytecode::Size(opcode);
    }
  }

  void DoLoadArguments() {
    DoPrologue();
    int arity = function_->arity();
    for (int i = 0; i < arity; i++) {
      // These will be set in reverse order below.
      stack_.push_back(NULL);
    }

    for (int i = 0; i < kAuxiliarySlots; i++) {
      // These should never be read or set.
      stack_.push_back(NULL);
    }

    for (int i = 0; i < max_stack_height_; i++) {
      llvm::Value* slot =
          b->CreateAlloca(w->object_ptr_type, NULL, name("slot_%d", i));
      stack_.push_back(slot);
    }

    // Save [process] and set arguments in reverse order on stack slots.
    int argc = 0;
    for (llvm::Argument& arg : llvm_function_->getArgumentList()) {
      if (argc == 0) {
        SetProcess(&arg);
      } else {
        ASSERT((arity - argc) >= 0);

        // The bytecodes can do a 'storelocal 5' where '5' refers to a function
        // parameter (i.e. parameter slots are modifyable as well).
        llvm::Value* slot =
            b->CreateAlloca(w->object_ptr_type, NULL, name("arg_%d", argc));
        b->CreateStore(&arg, slot);
        stack_[argc - 1] = slot;
      }
      argc++;
    }
    ASSERT(static_cast<int>(stack_.size()) ==
           (arity + kAuxiliarySlots + max_stack_height_));
  }

  void DoLoadLocal(int offset) { push(local(offset)); }

  void DoLoadInteger(int i) { push(w->CInt2Pointer(w->CSmi(i))); }

  void DoLoadConstant(Object* object) {
    llvm::Value* value = NULL;
    // We cast the constants to GC types even though they are constants and
    // thus off-heap, because they can be combined with GC types by Phis etc.
    // and the GC knows to ignore them.
    if (object->IsHeapObject()) {
      value = w->tagged_aspace1[HeapObject::cast(object)];
      ASSERT(value != NULL);
    } else {
      // TODO(llvm): Support LargeIntegers for non-portable Smis.
      value = w->CCast(w->CInt2Pointer(w->CSmi(Smi::cast(object)->value())),
                       w->object_ptr_type);
    }
    push(value);
  }

  void DoLoadField(int field) {
    auto object = pop();
    auto field_value = h.LoadField(object, Instance::kSize + field * kWordSize,
                                   "instance_field");
    push(field_value);
  }

  void DoLoadBoxed(int index) {
    auto boxed = local(index);
    auto value = h.LoadField(boxed, Boxed::kValueOffset, "boxed_value");
    push(value);
  }

  void DoStoreField(int field) {
    auto rhs = pop();
    auto object = pop();
    h.StoreField(Instance::kSize + field * kWordSize, object, rhs);
    push(rhs);
  }

  void DoStoreLocal(int index) { SetLocal(index, local(0)); }

  void DoStoreBoxed(int index) {
    auto value = local(0);
    h.StoreField(Boxed::kValueOffset, local(index), value);
  }

  void DoDrop(int n) {
    while (n-- > 0) pop();
  }

  void DoReturn() { b->CreateRet(pop()); }

  void DoReturnNull() {
    auto value = w->tagged_aspace1[w->program_->null_object()];
    ASSERT(value != NULL);
    b->CreateRet(h.Cast(value, w->object_ptr_type));
  }

  llvm::Value* CreateInvokeOrCall(int bci, llvm::Value* callee,
                                  llvm::ArrayRef<llvm::Value*> args,
                                  const std::string& label = "") {
    for (auto p : catch_ranges_) {
      int start = p.first;
      int end = p.second;
      if (bci >= start && bci < end) {
        llvm::BasicBlock* exceptional = bci2bb_[p.second];
        llvm::BasicBlock* normal = llvm::BasicBlock::Create(
            *context, name("bb%d", bci), llvm_function_);
        llvm::Value* val =
            b->CreateInvoke(callee, normal, exceptional, args, label);
        b->SetInsertPoint(normal);
        return val;
      }
    }
    return b->CreateCall(callee, args, label);
  }

  void DoThrow(int bci) {
    auto ex = pop();
    CreateInvokeOrCall(bci, w->raise_exception, {llvm_process_, ex});
    b->CreateUnreachable();
  }

  void DoCatchBlockEntry(int bci) {
    llvm_function_->setPersonalityFn(w->dart_personality);
    llvm::LandingPadInst* caughtResult =
        b->CreateLandingPad(w->caught_result_type, 1, "landingPad");
    caughtResult->addClause(llvm::Constant::getNullValue(b->getInt8PtrTy()));
    llvm::Value* exception =
        b->CreateCall(w->current_exception, {llvm_process_});
    // Save exception to local 0 where Dartino exception handling expects it to
    // be
    SetLocal(0, exception);
    auto body = catch_block_bodies[bci];
    b->CreateBr(body);
    b->SetInsertPoint(body);
  }

  void SetNoGC(llvm::CallInst* call) {
    llvm::AttributeSet attr_set = call->getAttributes();
    attr_set = attr_set.addAttribute(
        *context, llvm::AttributeSet::FunctionIndex, "gc-leaf-function", "1");
    call->setAttributes(attr_set);
  }

  void DoAllocate(Class* klass, bool immutable) {
    auto bb_retry = llvm::BasicBlock::Create(*w->context, "bb_allocation_retry",
                                             llvm_function_);

    int fields = klass->NumberOfInstanceFields();
    auto llvm_klass = w->tagged_aspace1[klass];
    ASSERT(llvm_klass != NULL);
    b->CreateBr(bb_retry);

    b->SetInsertPoint(bb_retry);
    auto instance =
        b->CreateCall(w->runtime__HandleAllocate,
                      {llvm_process_, llvm_klass, w->CWord(immutable ? 1 : 0)});

    // Strangely, the HandleAllocate call can't cause a GC (it just returns a
    // failure indicating that GC is needed).
    SetNoGC(instance);

    auto is_failure = h.CreateFailureCheck(instance);
    auto bb_success = llvm::BasicBlock::Create(
        *w->context, "bb_allocation_success", llvm_function_);
    auto bb_failure = llvm::BasicBlock::Create(
        *w->context, "bb_allocation_failure", llvm_function_);
    llvm::MDBuilder md_builder(*context);
    llvm::MDNode* assume_no_fail = md_builder.createBranchWeights(0, 1000);
    b->CreateCondBr(is_failure, bb_failure, bb_success, assume_no_fail);

    b->SetInsertPoint(bb_failure);
    b->CreateCall(w->dartino_gc_trampoline, {llvm_process_});
    b->CreateBr(bb_retry);

    b->SetInsertPoint(bb_success);
    for (int field = 0; field < fields; field++) {
      h.StoreField(Instance::kSize + (fields - 1 - field) * kWordSize, instance,
                   pop());
    }
    push(instance);
  }

  void DoAllocateBoxed() {
    auto value = pop();

    // TODO(llvm): Check for Failure::xxx result!
    auto boxed =
        b->CreateCall(w->runtime__HandleAllocateBoxed, {llvm_process_, value});

    push(boxed);
  }

  void DoEnterNSM() {
    // TODO(llvm):
    push(h.Null());
    push(h.Null());
    push(h.Null());
    push(h.Null());
    push(h.Null());
    push(h.Null());
  }

  void DoLoadStatic(int offset, bool check_for_initializer) {
    auto statics = h.LoadStaticsArray(llvm_process_);
    auto statics_entry_ptr = h.GetArrayPointer(statics, offset);
    auto statics_entry = h.LoadField(statics_entry_ptr, "static_var");

    llvm::Value* value;
    if (check_for_initializer) {
      auto bb_main = b->GetInsertBlock();
      auto bb_initializer = llvm::BasicBlock::Create(
          *w->context, "bb_initializer", llvm_function_);
      auto bb_join =
          llvm::BasicBlock::Create(*w->context, "join", llvm_function_);

      // Check for smi.
      auto bb_not_smi = llvm::BasicBlock::Create(
          *w->context, "bb_static_check_not_smi", llvm_function_);
      auto is_smi = h.CreateSmiCheck(statics_entry);
      b->CreateCondBr(is_smi, bb_join, bb_not_smi);

      b->SetInsertPoint(bb_not_smi);
      auto klass = h.LoadClass(statics_entry);
      auto instance_format = h.LoadInstanceFormat(klass);
      auto tmp = b->CreateAnd(instance_format,
                              w->CWord(InstanceFormat::TypeField::mask()),
                              "instance_type");
      auto is_initializer =
          b->CreateICmpEQ(tmp, w->CWord(InstanceFormat::TypeField::encode(
                                   InstanceFormat::INITIALIZER_TYPE)),
                          "is_initializer");
      b->CreateCondBr(is_initializer, bb_initializer, bb_join);

      b->SetInsertPoint(bb_initializer);
      auto function = h.LoadInitializerCode(statics_entry, 0);
      auto initializer_result = b->CreateCall(function, {llvm_process_});
      h.WriteFieldNoWriteBarrier(statics_entry_ptr, initializer_result);
      b->CreateBr(bb_join);

      b->SetInsertPoint(bb_join);
      auto phi = b->CreatePHI(w->object_ptr_type, 2);
      phi->addIncoming(initializer_result, bb_initializer);
      phi->addIncoming(statics_entry, bb_not_smi);
      phi->addIncoming(statics_entry, bb_main);
      value = phi;
    } else {
      value = statics_entry;
    }
    push(value);
  }

  void DoStoreStatic(int offset) {
    auto statics = h.LoadStaticsArray(llvm_process_);
    auto statics_entry_ptr = h.GetArrayPointer(statics, offset);
    h.WriteFieldNoWriteBarrier(statics_entry_ptr, local(0));
  }

  void DoCall(int bci, Function* target) {
    int arity = target->arity();
    std::vector<llvm::Value*> args(1 + arity, NULL);
    for (int i = 0; i < arity; i++) {
      args[arity - i] = pop();
    }
    args[0] = llvm_process_;
    llvm::Function* llvm_target =
        static_cast<llvm::Function*>(w->llvm_functions[target]);
    ASSERT(llvm_target != NULL);
    auto result = CreateInvokeOrCall(bci, llvm_target, args, "result");
    push(result);
  }

  void DoInvokeNative(Native nativeId, int arity) {
    if (nativeId == kListLength) {
      kListLengthNative.Codegen(w, this, &h);
      return;
    } else if (nativeId == kListIndexGet) {
      kListIndexGetNative.Codegen(w, this, &h);
      return;
    } else if (nativeId == kStringLength) {
      kStringLengthMacro.Codegen(w, this, &h);
      return;
    } else if (nativeId == kSmiNegate) {
      kSmiNegateMacro.Codegen(w, this, &h);
      return;
    } else if (nativeId == kSmiMul) {
      kSmiMulMacro.Codegen(w, this, &h);
      return;
    } else if (nativeId == kSmiBitShr) {
      kSmiShrMacro.Codegen(w, this, &h);
      return;
    }
    std::vector<llvm::Value*> args(1 + arity, NULL);
    for (int i = 0; i < arity; i++) {
      args[arity - i] = b->CreateLoad(stack_[arity - i - 1]);
    }
    args[0] = llvm_process_;
    llvm::Function* trampoline = w->NativeTrampoline(nativeId, arity);
    auto native_result = b->CreateCall(trampoline, args, "native_result");

    auto bb_failure =
        llvm::BasicBlock::Create(*context, "failure", llvm_function_);
    auto bb_no_failure =
        llvm::BasicBlock::Create(*context, "no_failure", llvm_function_);
    b->CreateCondBr(h.CreateFailureCheck(native_result), bb_failure,
                    bb_no_failure);

    b->SetInsertPoint(bb_no_failure);
    b->CreateRet(native_result);

    // We convert the failure id into a failure object and let the rest of the
    // bytecodes do their work.
    b->SetInsertPoint(bb_failure);
    auto failure_object = b->CreateCall(w->runtime__HandleObjectFromFailure,
                                        {llvm_process_, native_result});
    push(failure_object);
  }

  llvm::Value* DoIdentical(bool make_bools_primitive) {
    // TODO(llvm): Handle about other classes!
    auto comp = b->CreateICmpEQ(pop(), pop());
    if (make_bools_primitive) return comp;
    auto true_obj = w->tagged_aspace1[w->program_->true_object()];
    auto false_obj = w->tagged_aspace1[w->program_->false_object()];
    push(b->CreateSelect(comp, true_obj, false_obj, "identical_result"));
    return nullptr;
  }

  void CheatSmiOperation(Opcode opcode, int selector, int if_true_bci,
                         int if_false_bci) {
    auto tagged_argument = pop();
    auto tagged_receiver = pop();

    auto argument = b->CreatePtrToInt(tagged_argument, w->intptr_type);
    auto receiver = b->CreatePtrToInt(tagged_receiver, w->intptr_type);

    llvm::Value* result = nullptr;
    bool boolify = false;
    if (opcode == kInvokeAdd) {
      result = b->CreateAdd(receiver, argument);
    } else if (opcode == kInvokeSub) {
      result = b->CreateSub(receiver, argument);
    } else if (opcode == kInvokeBitAnd) {
      result = b->CreateAnd(receiver, argument, "bitwise_smi_and");
    } else if (opcode == kInvokeBitOr) {
      result = b->CreateOr(receiver, argument, "bitwise_smi_or");
    } else if (opcode == kInvokeBitXor) {
      result = b->CreateXor(receiver, argument, "bitwise_smi_xor");
    } else if (opcode == kInvokeEq) {
      result = b->CreateICmpEQ(receiver, argument);
      boolify = true;
    } else if (opcode == kInvokeGe) {
      result = b->CreateICmpSGE(receiver, argument);
      boolify = true;
    } else if (opcode == kInvokeGt) {
      result = b->CreateICmpSGT(receiver, argument);
      boolify = true;
    } else if (opcode == kInvokeLe) {
      result = b->CreateICmpSLE(receiver, argument);
      boolify = true;
    } else if (opcode == kInvokeLt) {
      result = b->CreateICmpSLT(receiver, argument);
      boolify = true;
    } else {
      UNREACHABLE();
    }

    if (if_true_bci == -1) {
      if (boolify) {
        auto true_obj = w->tagged_aspace1[w->program_->true_object()];
        auto false_obj = w->tagged_aspace1[w->program_->false_object()];
        push(b->CreateSelect(result, true_obj, false_obj, "compare_result"));
      } else {
        push(b->CreateIntToPtr(result, w->object_ptr_type));
      }
    } else {
      auto pos = GetBasicBlockAt(if_true_bci);
      auto neg = GetBasicBlockAt(if_false_bci);
      b->CreateCondBr(result, pos, neg);
    }
  }

  llvm::Value* DoInvokeSmiOperation(Opcode opcode, int selector,
                                    bool make_bools_primitive) {
    auto bb_smi_receiver =
        llvm::BasicBlock::Create(*context, "smi_receiver", llvm_function_);
    auto bb_smis = llvm::BasicBlock::Create(*context, "smis", llvm_function_);
    auto bb_nonsmi =
        llvm::BasicBlock::Create(*context, "nonsmi", llvm_function_);
    auto bb_join = llvm::BasicBlock::Create(*context, "join", llvm_function_);

    auto tagged_argument = pop();
    auto tagged_receiver = pop();

    llvm::MDBuilder md_builder(*context);
    llvm::MDNode* assume_true = md_builder.createBranchWeights(1000, 0);

    b->CreateCondBr(h.CreateSmiCheck(tagged_receiver), bb_smi_receiver,
                    bb_nonsmi, assume_true);
    b->SetInsertPoint(bb_smi_receiver);
    b->CreateCondBr(h.CreateSmiCheck(tagged_argument), bb_smis, bb_nonsmi,
                    assume_true);
    b->SetInsertPoint(bb_smis);

    auto argument = b->CreatePtrToInt(tagged_argument, w->intptr_type);
    auto receiver = b->CreatePtrToInt(tagged_receiver, w->intptr_type);

    bool boolify = false;
    llvm::Value* no_overflow = NULL;
    llvm::Value* result = NULL;
    if (opcode == kInvokeBitShr ||
        (!Flags::wrap_smis && (opcode == kInvokeAdd ||
                               opcode == kInvokeSub ||
                               opcode == kInvokeMul))) {
      std::vector<llvm::Value*> stack;
      Push(&stack, receiver);
      Push(&stack, argument);
      if (opcode == kInvokeAdd) kInvokeAddMacro.Codegen(w, this, &h, &stack);
      if (opcode == kInvokeSub) kInvokeSubMacro.Codegen(w, this, &h, &stack);
      if (opcode == kInvokeMul) kInvokeMulMacro.Codegen(w, this, &h, &stack);
      if (opcode == kInvokeBitShr) kInvokeShrMacro.Codegen(w, this, &h, &stack);
      no_overflow = Pop(&stack);
      result = Pop(&stack);
    } else if (opcode == kInvokeAdd) {
      result = b->CreateAdd(receiver, argument);
    } else if (opcode == kInvokeSub) {
      result = b->CreateSub(receiver, argument);
    } else if (opcode == kInvokeMul) {
      result = b->CreateMul(b->CreateAShr(receiver, w->CWord(1)), argument);
    } else if (opcode == kInvokeBitAnd) {
      result = b->CreateAnd(receiver, argument, "bitwise_smi_and");
    } else if (opcode == kInvokeBitOr) {
      result = b->CreateOr(receiver, argument, "bitwise_smi_or");
    } else if (opcode == kInvokeBitXor) {
      result = b->CreateXor(receiver, argument, "bitwise_smi_xor");
    } else if (opcode == kInvokeEq) {
      result = b->CreateICmpEQ(receiver, argument);
      boolify = true;
    } else if (opcode == kInvokeGe) {
      result = b->CreateICmpSGE(receiver, argument);
      boolify = true;
    } else if (opcode == kInvokeGt) {
      result = b->CreateICmpSGT(receiver, argument);
      boolify = true;
    } else if (opcode == kInvokeLe) {
      result = b->CreateICmpSLE(receiver, argument);
      boolify = true;
    } else if (opcode == kInvokeLt) {
      result = b->CreateICmpSLT(receiver, argument);
      boolify = true;
    } else {
      UNREACHABLE();
    }

    bb_smis = b->GetInsertBlock();

    llvm::Value* smi_result = NULL;
    if (!make_bools_primitive) {
      if (boolify) {
        auto true_obj = w->tagged_aspace1[w->program_->true_object()];
        auto false_obj = w->tagged_aspace1[w->program_->false_object()];
        smi_result =
            b->CreateSelect(result, true_obj, false_obj, "compare_result");
      } else {
        smi_result = b->CreateIntToPtr(result, w->object_ptr_type);
      }
    } else {
      smi_result = result;
    }
    if (no_overflow == NULL) {
      b->CreateBr(bb_join);
    } else {
      b->CreateCondBr(no_overflow, bb_join, bb_nonsmi, assume_true);
    }

    b->SetInsertPoint(bb_nonsmi);
    auto slow_case = w->GetSmiSlowCase(selector);
    llvm::Value* nonsmi_result = b->CreateCall(
        slow_case, {llvm_process_, tagged_receiver, tagged_argument},
        "slow_case");

    if (make_bools_primitive) {
      auto true_object = w->tagged_aspace1[w->program_->true_object()];
      nonsmi_result = b->CreateICmpEQ(nonsmi_result, true_object);
    }
    bb_nonsmi = b->GetInsertBlock();  // The basic block can be changed by
                                      // [DoInvokeMethod]!
    b->CreateBr(bb_join);

    b->SetInsertPoint(bb_join);
    if (!make_bools_primitive) {
      auto phi = b->CreatePHI(w->object_ptr_type, 2);
      phi->addIncoming(smi_result, bb_smis);
      phi->addIncoming(nonsmi_result, bb_nonsmi);
      push(phi);
      return nullptr;
    } else {
      auto phi = b->CreatePHI(smi_result->getType(), 2);
      phi->addIncoming(smi_result, bb_smis);
      phi->addIncoming(nonsmi_result, bb_nonsmi);
      return phi;
    }
  }

  llvm::Value* DoNegate(bool make_bools_primitive,
                        llvm::Value* numeric_bool_tos) {
    if (numeric_bool_tos && make_bools_primitive) {
      return b->CreateNot(numeric_bool_tos, "negate");
    }

    auto true_obj = w->tagged_aspace1[w->program_->true_object()];
    auto false_obj = w->tagged_aspace1[w->program_->false_object()];

    if (numeric_bool_tos) {
      push(b->CreateSelect(numeric_bool_tos, false_obj, true_obj, "negate"));
      return nullptr;
    }

    auto comp = b->CreateICmpEQ(pop(), true_obj);

    if (make_bools_primitive) {
      return b->CreateNot(comp, "negate");
    } else {
      push(b->CreateSelect(comp, false_obj, true_obj, "negate"));
      return nullptr;
    }
  }

  void DoInvokeMethod(int bci, int selector, int arity) {
    std::vector<llvm::Value*> method_args(1 + 1 + arity);

    method_args[0] = llvm_process_;

    int index = 1 + arity;
    for (int i = 0; i < arity + 1; i++) {
      method_args[index--] = pop();
    }
    ASSERT(index == 0);

    Function* fn;
    if (Flags::assume_no_nsm && (fn = OnlyOneMethodMatches(selector))) {
      // There's only one method of this name (selector), so since there are
      // assumed to be no NoSuchMethod events, just call it (or inline it).
      auto code = w->llvm_functions[fn];
      auto result = CreateInvokeOrCall(bci, code, method_args, "method_result");
      push(result);
    } else {
      auto result = InvokeMethodHelper(bci, selector, method_args);
      push(result);
    }
  }

  llvm::Value* GetDispatchTableEntry(llvm::Value* offset) {
    auto untyped = w->untagged_aspace0[w->program_->dispatch_table()];
    auto typed = b->CreatePointerCast(untyped, w->dte_ptr_ptr_type);
    auto gep = b->CreateGEP(
        typed, b->CreateAdd(offset, w->CWord(Array::kSize / kPointerSize)));
    auto dte = b->CreateLoad(gep);
    dte->setMetadata(llvm::LLVMContext::MD_invariant_load,
                     llvm::MDNode::get(*w->context, llvm::None));
    dte->setMetadata("never.faults",
                     llvm::MDNode::get(*w->context, llvm::None));
    dte->setMetadata(
        llvm::LLVMContext::MD_dereferenceable,
        llvm::MDNode::get(*w->context, llvm::ConstantAsMetadata::get(w->CInt64(
                                           DispatchTableEntry::kSize))));
    return dte;
  }

  bool SmiMatchesSelector(int selector) {
    return SmiMatchesSelectorId(Selector::IdField::decode(selector));
  }

  bool SmiMatchesSelectorId(int selector_id) {
    Array* dispatch_table = w->program_->dispatch_table();
    Class* smi_klass = w->program_->smi_class();
    int class_id = smi_klass->id();
    Object* e = dispatch_table->get(class_id + selector_id);
    auto entry = DispatchTableEntry::cast(e);
    return entry->offset()->value() == selector_id;
  }

  Function* OnlyOneMethodMatches(int selector) {
    Function* fn = nullptr;
    Array* dispatch_table = w->program_->dispatch_table();
    for (int i = 0; i < dispatch_table->length(); i++) {
      Object* e = dispatch_table->get(i);
      auto entry = DispatchTableEntry::cast(e);
      if (entry->offset()->value() == Selector::IdField::decode(selector)) {
        if (fn == nullptr) {
          fn = entry->target();
        } else if (fn != entry->target()) {
          return nullptr;
        }
      }
    }
    return fn;
  }

  llvm::Value* InvokeMethodHelper(int bci, int selector,
                                  std::vector<llvm::Value*> args) {
    int arity = args.size() - 2;
    auto receiver = args[1];
    auto offset = LookupDispatchTableOffset(receiver, selector);
    if (Flags::assume_no_nsm) {
      auto gep = b->CreateGEP(w->vtable, offset);
      auto code = b->CreateLoad(gep);
      code->setMetadata(llvm::LLVMContext::MD_invariant_load,
                        llvm::MDNode::get(*w->context, llvm::None));
      code->setMetadata("never.faults",
                         llvm::MDNode::get(*w->context, llvm::None));
      auto function_type = w->FunctionPtrType(1 + arity);
      auto typed_code = b->CreatePointerCast(code, function_type);
      return CreateInvokeOrCall(bci, typed_code, args, "method_result");
    }

    auto entry = GetDispatchTableEntry(offset);
    auto expected_offset = b->CreatePtrToInt(
        LookupDispatchTableOffsetFromEntry(entry), w->intptr_type);
    auto smi_selector_offset = Selector::IdField::decode(selector)
                               << Smi::kTagSize;
    auto actual_offset = w->CWord(smi_selector_offset);

    auto bb_lookup_failure = llvm::BasicBlock::Create(
        *w->context, "bb_lookup_failure", llvm_function_);
    auto bb_lookup_success = llvm::BasicBlock::Create(
        *w->context, "bb_lookup_success", llvm_function_);
    auto bb_start = b->GetInsertBlock();
    b->CreateCondBr(b->CreateICmpEQ(actual_offset, expected_offset),
                    bb_lookup_success, bb_lookup_failure);

    b->SetInsertPoint(bb_lookup_failure);
    // NSM is 0th element in dispatch table.
    auto nsm_entry = GetDispatchTableEntry(w->CWord(0));
    b->CreateBr(bb_lookup_success);

    b->SetInsertPoint(bb_lookup_success);
    auto phi = b->CreatePHI(w->dte_ptr_type, 2);
    phi->addIncoming(entry, bb_start);
    phi->addIncoming(nsm_entry, bb_lookup_failure);
    entry = phi;

    auto code = h.CastToNonGC(LookupDispatchTableCodeFromEntry(entry),
                              w->FunctionPtrType(1 + arity));
    return CreateInvokeOrCall(bci, code, args, "method_result");
  }

  llvm::Value* DoInvokeTest(int selector, bool make_bools_primitive) {
    auto receiver = pop();
    auto smi_selector_offset = Selector::IdField::decode(selector)
                               << Smi::kTagSize;

    auto actual_offset = w->CWord(smi_selector_offset);
    auto offset = LookupDispatchTableOffset(receiver, selector);
    auto entry = GetDispatchTableEntry(offset);
    auto expected_offset = b->CreatePtrToInt(
        LookupDispatchTableOffsetFromEntry(entry), w->intptr_type);

    auto comp = b->CreateICmpEQ(actual_offset, expected_offset);
    if (make_bools_primitive) return comp;
    auto true_obj = w->tagged_aspace1[w->program_->true_object()];
    auto false_obj = w->tagged_aspace1[w->program_->false_object()];
    push(b->CreateSelect(comp, true_obj, false_obj, "invoke_compare_result"));
    return nullptr;
  }

  void DoBranch(int bci) {
    auto dst = GetBasicBlockAt(bci);
    b->CreateBr(dst);
  }

  void DoBranchIf(int bci, int next_bci) {
    auto true_object = w->tagged_aspace1[w->program_->true_object()];
    auto pos = GetBasicBlockAt(bci);
    auto neg = GetBasicBlockAt(next_bci);
    auto cond = b->CreateICmpEQ(pop(), true_object);
    b->CreateCondBr(cond, pos, neg);
  }

  void DoBranchIfFalse(int bci, int next_bci) { DoBranchIf(next_bci, bci); }

  void DoBranchIfZero(llvm::Value* boolean, int bci, int next_bci) {
    auto zero = w->CBit(0);
    auto pos = GetBasicBlockAt(bci);
    auto neg = GetBasicBlockAt(next_bci);
    auto cond = b->CreateICmpEQ(boolean, zero);
    b->CreateCondBr(cond, pos, neg);
  }

  void DoBranchIfNonZero(llvm::Value* boolean, int bci, int next_bci) {
    DoBranchIfZero(boolean, next_bci, bci);
  }

  void DoProcessYield() { b->CreateCall(w->libc__exit, {w->CInt(0)}); }

  void DoDebugPrint(const char* message) {
    b->CreateCall(w->libc__puts, {h.BuildCString(message)});
  }

  void DoExitFatal(const char* message) {
    DoDebugPrint(message);
    b->CreateCall(w->libc__exit, {w->CInt(1)});
  }

  bool DoSubroutineCall(int target) {
    llvm::BasicBlock* block = bci2bb_[target];
    llvm::Instruction* inst;
    llvm::Value* marker;
    // Check if already used subroutine body at least once.
    if (subroutines_.find(target) == subroutines_.end()) {
      llvm::IRBuilder<> b2(&*bb_entry_->begin());
      marker = b2.CreateAlloca(w->int32_type, nullptr, "marker");
      subroutines_[target] = SubroutineEntry(1, marker);
      inst = FindSubroutineExit(block);
    } else {
      SubroutineEntry e = subroutines_[target];
      marker = e.marker;
      inst = e.end;
      subroutines_[target].counter++;
    }
    // "inst is null" means subroutine is unconditionally exited via
    // other control-flow.
    if (inst == nullptr) {
      subroutines_[target].end = nullptr;
      b->CreateBr(block);
      return true;
    } else {
      b->CreateStore(w->CInt(subroutines_[target].counter), marker);
      b->CreateBr(block);
      llvm::BasicBlock* continuation =
          llvm::BasicBlock::Create(*context, "contSub", llvm_function_);
      llvm::BasicBlock* endOfSub =
          llvm::BasicBlock::Create(*context, "endSub", llvm_function_);
      b->SetInsertPoint(inst);
      llvm::Value* val = b->CreateLoad(marker);
      val = b->CreateICmpEQ(val, w->CInt(subroutines_[target].counter));
      auto continuationInst = b->CreateCondBr(val, continuation, endOfSub);
      inst->replaceAllUsesWith(continuationInst);
      inst->eraseFromParent();
      b->SetInsertPoint(endOfSub);
      subroutines_[target].end = b->CreateUnreachable();
      b->SetInsertPoint(continuation);
      return false;
    }
  }

  void DoSubroutineReturn() {
    llvm::Instruction* inst = b->CreateUnreachable();
    llvm::MDNode* n = llvm::MDNode::get(
        *w->context, llvm::MDString::get(*w->context, "subroutine"));
    inst->setMetadata("dartino.exit_type", n);
  }

  bool SubroutineGenerated(int bci) {
    if (subroutines_.count(bci)) {
      return true;
    }
    llvm::BasicBlock* start = bci2bb_[bci];
    return start->getTerminator() != nullptr;
  }

  bool use_llvm() { return use_llvm_; }
  llvm::Function* llvm_function() { return llvm_function_; }

 private:
  llvm::Instruction* FindSubroutineExit(llvm::BasicBlock* start) {
    std::set<llvm::BasicBlock*> visited;
    return FindSubroutineExitImpl(start, &visited);
  }

  llvm::Instruction* FindSubroutineExitImpl(
      llvm::BasicBlock* start, std::set<llvm::BasicBlock*>* visited) {
    visited->insert(start);
    auto terminator = start->getTerminator();
    if (!terminator) return nullptr;
    if (terminator->getMetadata("dartino.exit_type")) return terminator;
    for (size_t i = 0; i < terminator->getNumSuccessors(); i++) {
      auto next = terminator->getSuccessor(i);
      if (visited->find(next) == visited->end()) {
        auto inst = FindSubroutineExitImpl(next, visited);
        if (inst) return inst;
      }
    }
    return nullptr;
  }

  llvm::Value* LookupDispatchTableCodeFromEntry(llvm::Value* entry) {
    return h.LoadFieldAddressSpaceZero(entry, DispatchTableEntry::kCodeOffset,
                                       "code");
  }

  llvm::Value* LookupDispatchTableOffsetFromEntry(llvm::Value* entry) {
    llvm::Value* offset = h.LoadField(entry, DispatchTableEntry::kOffsetOffset,
                                      "offset", true, 0);

    return offset;
  }

  llvm::Value* LookupDispatchTableOffset(llvm::Value* receiver, int selector) {
    llvm::Value* klass;
    bool smi_matches = SmiMatchesSelector(selector);
    if (!Flags::assume_no_nsm || smi_matches) {
      auto bb_smi = llvm::BasicBlock::Create(*context, "smi", llvm_function_);
      auto bb_nonsmi =
          llvm::BasicBlock::Create(*context, "nonsmi", llvm_function_);
      auto bb_lookup =
          llvm::BasicBlock::Create(*context, "lookup", llvm_function_);

      auto is_smi = h.CreateSmiCheck(receiver);
      b->CreateCondBr(is_smi, bb_smi, bb_nonsmi);

      b->SetInsertPoint(bb_smi);
      auto smi_klass = w->tagged_aspace0[w->program_->smi_class()];
      b->CreateBr(bb_lookup);

      b->SetInsertPoint(bb_nonsmi);
      auto custom_klass = h.LoadClass(receiver);
      b->CreateBr(bb_lookup);

      b->SetInsertPoint(bb_lookup);
      auto phi = b->CreatePHI(w->class_ptr_type, 2, "klass");
      phi->addIncoming(smi_klass, bb_smi);
      phi->addIncoming(custom_klass, bb_nonsmi);
      klass = phi;
    } else {
      // Since we assume no NoSuchMethod and Smi does not have this
      // method, there is no need to check for Smis.
      klass = h.LoadClass(receiver);
    }

    auto classid = b->CreatePtrToInt(
        h.LoadField(klass, Class::kIdOrTransformationTargetOffset,
                    "class_id_uncast", true, 0),
        w->intptr_type, "id_or_transformation_target");
    auto selector_offset = w->CWord(Selector::IdField::decode(selector));
    auto offset = b->CreateAdd(selector_offset, classid);
    return offset;
  }

  llvm::BasicBlock* GetBasicBlockAt(int bci) {
    if (catch_block_bodies.find(bci) != catch_block_bodies.end()) {
      return catch_block_bodies[bci];
    }
    auto bb = bci2bb_[bci];
    ASSERT(bb != NULL);
    return bb;
  }

  void push(llvm::Value* v) {
    ASSERT(v->getType() == w->object_ptr_type);
    ASSERT(stack_pos_ <= max_stack_height_);

    int arity = function_->arity();
    stack_pos_++;
    b->CreateStore(v, stack_[arity + kAuxiliarySlots + stack_pos_ - 1]);
  }

  llvm::Value* pop() {
    ASSERT(stack_pos_ > 0);
    auto v = local(0);
    stack_pos_--;
    return v;
  }

  llvm::Value* local(int i) { return b->CreateLoad(stack_[GetOffset(i)]); }

  void SetLocal(int i, llvm::Value* value) {
    b->CreateStore(value, stack_[GetOffset(i)]);
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

  World* w;
  Function* function_;
  llvm::Function* llvm_function_;
  llvm::IRBuilder<>* b;
  llvm::LLVMContext* context;
  llvm::Value* llvm_process_;
  std::vector<llvm::Value*> stack_;
  IRHelper h;
  int stack_pos_;
  int max_stack_height_;
  llvm::BasicBlock* bb_entry_;
  std::map<int, llvm::BasicBlock*> bci2bb_;
  std::map<int, int> bci2sh_;
  const std::vector<std::pair<int, int>>& catch_ranges_;
  std::map<int, llvm::BasicBlock*> catch_block_bodies;
  std::map<int, SubroutineEntry> subroutines_;
  // Make optimistic and illegal assumptions to simulate a Strong Mode world
  // where types are generally known.  Most operators only work on Smis in this
  // mode.
  bool use_llvm_ = false;

  friend class ForthFunction;
};

class BasicBlocksExplorer {
 public:
  BasicBlocksExplorer(World* world, Function* function,
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
    auto llvm_function = w->llvm_functions[function_];

    llvm::IRBuilder<> builder(*w->context);
    BasicBlockBuilder b(w, function_, llvm_function, &builder, catch_ranges_);

    b.ScanForUseLLVM();

    if (b.use_llvm()) w->use_llvm_function = llvm_function;

    // Phase 1: Create basic blocks
    for (auto& pair : labels) {
      b.AddBasicBlockAtBCI(pair.first, pair.second);
    }
    b.SetMaximumStackHeight(max_stacksize_);

    // Phase 2: Fill basic blocks
    b.DoLoadArguments();

    // Delay basic block that depend on ungenerated subroutine calls.
    std::vector<int> current;
    for (auto& pair : labels) {
      if (HasUngeneratedSubroutineCall(&b, pair.first)) {
        current.push_back(pair.first);
      } else {
        BuildBlock(&b, pair.first);
      }
    }
    // Proceed in multi-pass style untill all subroutines
    // and their dependants are generated.
    std::vector<int> delayed;
    while (current.size() > 0) {
      for (int bci : current) {
        if (HasUngeneratedSubroutineCall(&b, bci)) {
          delayed.push_back(bci);
        } else {
          BuildBlock(&b, bci);
        }
      }
      current = delayed;
      delayed.clear();
    }
    b.TerminateEntryBlock();
    VerifyFunction();
  }

 private:
  bool HasUngeneratedSubroutineCall(BasicBlockBuilder* b, int bci) {
    bool stop = false;
    do {
      uint8* bcp = function_->bytecode_address_for(bci);
      Opcode opcode = static_cast<Opcode>(*bcp);
      int next_bci = bci + Bytecode::Size(opcode);

      switch (opcode) {
        case kThrow: {
          stop = true;
          break;
        }

        case kSubroutineCall: {
          int target = bci + Utils::ReadInt32(bcp + 1);
          if (!b->SubroutineGenerated(target)) return true;
          break;
        }

        case kMethodEnd: {
          stop = true;
          break;
        }
        default:
          break;
      }
      bci = next_bci;
    } while (labels.find(bci) == labels.end() && !stop);

    return false;
  }

  bool NextInsnTakesABool(int next_bci) {
    if (labels.find(next_bci) == labels.end()) {
      uint8* next_bcp = function_->bytecode_address_for(next_bci);
      Opcode next_opcode = static_cast<Opcode>(*next_bcp);
      if (next_opcode == kBranchIfTrueWide ||
          next_opcode == kBranchIfFalseWide || next_opcode == kNegate) {
        return true;
      }
    }
    return false;
  }

  void BuildBlock(BasicBlockBuilder* b, int bci) {
    b->InsertAtBCI(bci);
    if (catch_blocks_.find(bci) != catch_blocks_.end()) {
      b->DoCatchBlockEntry(bci);
    }

    llvm::Value* numeric_bool_tos = nullptr;
    bool last_opcode_was_jump = false;
    bool stop = false;
    do {
      uint8* bcp = function_->bytecode_address_for(bci);
      Opcode opcode = static_cast<Opcode>(*bcp);
      int next_bci = bci + Bytecode::Size(opcode);

      // b->DoDebugPrint(name("[trace fun: %p  bci: @%02d] %s", function_, bci,
      // bytecode_string(bcp)));

      switch (opcode) {
        case kInvokeFactory:
        case kInvokeStatic: {
          b->DoCall(bci, Function::cast(Function::ConstantForBytecode(bcp)));
          break;
        }

        case kLoadLocal0:
        case kLoadLocal1:
        case kLoadLocal2:
        case kLoadLocal3:
        case kLoadLocal4:
        case kLoadLocal5: {
          b->DoLoadLocal(opcode - kLoadLocal0);
          break;
        }
        case kLoadLocal: {
          b->DoLoadLocal(*(bcp + 1));
          break;
        }
        case kLoadLocalWide: {
          b->DoLoadLocal(Utils::ReadInt32(bcp + 1));
          break;
        }
        case kLoadField: {
          b->DoLoadField(*(bcp + 1));
          break;
        }

        case kLoadFieldWide: {
          b->DoLoadField(Utils::ReadInt32(bcp + 1));
          break;
        }

        case kLoadLiteral0:
        case kLoadLiteral1: {
          b->DoLoadInteger(opcode - kLoadLiteral0);
          break;
        }

        case kLoadLiteral: {
          b->DoLoadInteger(*(bcp + 1));
          break;
        }

        case kLoadLiteralWide: {
          b->DoLoadInteger(Utils::ReadInt32(bcp + 1));
          break;
        }

        case kLoadLiteralNull: {
          b->DoLoadConstant(w->program_->null_object());
          break;
        }

        case kLoadLiteralTrue: {
          b->DoLoadConstant(w->program_->true_object());
          break;
        }

        case kLoadLiteralFalse: {
          b->DoLoadConstant(w->program_->false_object());
          break;
        }

        case kLoadConst: {
          Object* constant = Function::ConstantForBytecode(
              function_->bytecode_address_for(bci));
          b->DoLoadConstant(constant);
          break;
        }

        case kLoadBoxed: {
          b->DoLoadBoxed(*(bcp + 1));
          break;
        }

        case kStoreLocal: {
          int index = *(bcp + 1);
          b->DoStoreLocal(index);
          break;
        }
        case kStoreField: {
          b->DoStoreField(*(bcp + 1));
          break;
        }
        case kStoreFieldWide: {
          b->DoStoreField(Utils::ReadInt32(bcp + 1));
          break;
        }

        case kStoreBoxed: {
          b->DoStoreBoxed(*(bcp + 1));
          break;
        }

        case kBranchWide: {
          b->DoBranch(bci + Utils::ReadInt32(bcp + 1));
          stop = true;
          break;
        }

        case kBranchBack: {
          b->DoBranch(bci - *(bcp + 1));
          stop = true;
          break;
        }

        case kBranchBackWide: {
          b->DoBranch(bci - Utils::ReadInt32(bcp + 1));
          stop = true;
          break;
        }

        case kPopAndBranchWide: {
          b->DoDrop(*(bcp + 1));
          b->DoBranch(bci + Utils::ReadInt32(bcp + 2));
          stop = true;
          break;
        }

        case kPopAndBranchBackWide: {
          b->DoDrop(*(bcp + 1));
          b->DoBranch(bci - Utils::ReadInt32(bcp + 2));
          stop = true;
          break;
        }

        case kBranchIfTrueWide: {
          if (numeric_bool_tos) {
            b->DoBranchIfNonZero(numeric_bool_tos,
                                 bci + Utils::ReadInt32(bcp + 1), next_bci);
            numeric_bool_tos = nullptr;
          } else {
            b->DoBranchIf(bci + Utils::ReadInt32(bcp + 1), next_bci);
          }
          break;
        }

        case kBranchBackIfTrue: {
          b->DoBranchIf(bci - *(bcp + 1), next_bci);
          break;
        }

        case kBranchBackIfTrueWide: {
          b->DoBranchIf(bci - Utils::ReadInt32(bcp + 1), next_bci);
          break;
        }

        case kBranchIfFalseWide: {
          if (numeric_bool_tos) {
            b->DoBranchIfZero(numeric_bool_tos, bci + Utils::ReadInt32(bcp + 1),
                              next_bci);
            numeric_bool_tos = nullptr;
          } else {
            b->DoBranchIfFalse(bci + Utils::ReadInt32(bcp + 1), next_bci);
          }
          break;
        }

        case kBranchBackIfFalse: {
          b->DoBranchIfFalse(bci - *(bcp + 1), next_bci);
          break;
        }

        case kBranchBackIfFalseWide: {
          b->DoBranchIfFalse(bci - Utils::ReadInt32(bcp + 1), next_bci);
          break;
        }

        case kPop: {
          b->DoDrop(1);
          break;
        }

        case kDrop: {
          b->DoDrop(*(bcp + 1));
          break;
        }

        case kReturn: {
          b->DoReturn();
          stop = true;
          break;
        }

        case kReturnNull: {
          b->DoReturnNull();
          stop = true;
          break;
        }

        case kThrow: {
          b->DoThrow(bci);
          stop = true;
          break;
        }

        case kSubroutineCall: {
          int target = bci + Utils::ReadInt32(bcp + 1);
          // If unconditional control flow in subroutine - stop.
          if (b->DoSubroutineCall(target)) {
            stop = true;
          }
          break;
        }

        case kSubroutineReturn: {
          b->DoSubroutineReturn();
          stop = true;
          break;
        }

        /*
        case kInvokeNoSuchMethod: {
          int selector = Utils::ReadInt32(bcp + 1);
          DoInvokeNoSuchMethod(selector);
          break;
        }

        case kEnterNoSuchMethod: {
          DoNoSuchMethod();
          basic_block_.Clear();
          break;
        }

        case kCoroutineChange: {
          int selector = Selector::Encode(Names::kCoroutineStart,
        Selector::METHOD, 1);
          Function* start =
        program()->coroutine_class()->LookupMethod(selector);
          DoCoroutineChange(start == function_ && bci == 2);
          basic_block_.Clear();
          break;
        }
        */

        case kStackOverflowCheck: {
          // Do nothing.
          break;
        }

        case kIdenticalNonNumeric:
        case kIdentical: {
          numeric_bool_tos = b->DoIdentical(NextInsnTakesABool(next_bci));
          break;
        }

        case kInvokeDetachableNative:
        case kInvokeNative: {
          int arity = *(bcp + 1);
          Native native = static_cast<Native>(*(bcp + 2));
          b->DoInvokeNative(native, arity);
          break;
        }

        case kAllocate:
        case kAllocateImmutable: {
          Class* klass = Class::cast(Function::ConstantForBytecode(bcp));
          b->DoAllocate(klass, opcode == kAllocateImmutable);
          break;
        }

        case kAllocateBoxed: {
          b->DoAllocateBoxed();
          break;
        }

        case kNegate: {
          numeric_bool_tos =
              b->DoNegate(NextInsnTakesABool(next_bci), numeric_bool_tos);
          break;
        }

        case kInvokeEq:
        case kInvokeGe:
        case kInvokeGt:
        case kInvokeLe:
        case kInvokeLt: {
          int selector = Utils::ReadInt32(bcp + 1);
          numeric_bool_tos = b->DoInvokeSmiOperation(
              opcode, selector, NextInsnTakesABool(next_bci));
          break;
        }

        case kInvokeBitShr:
        case kInvokeMul:
        case kInvokeBitAnd:
        case kInvokeBitOr:
        case kInvokeBitXor:
        case kInvokeAdd:
        case kInvokeSub: {
          int selector = Utils::ReadInt32(bcp + 1);
          b->DoInvokeSmiOperation(opcode, selector, false);
          break;
        }

        case kInvokeBitShl:
        case kInvokeBitNot:
        case kInvokeMod:
        case kInvokeTruncDiv:

        case kInvokeMethod: {
          int selector = Utils::ReadInt32(bcp + 1);
          int arity = Selector::ArityField::decode(selector);
          b->DoInvokeMethod(bci, selector, arity);
          break;
        }

        case kInvokeTest: {
          int selector = Utils::ReadInt32(bcp + 1);
          numeric_bool_tos =
              b->DoInvokeTest(selector, NextInsnTakesABool(next_bci));
          break;
        }

        case kInvokeTestNoSuchMethod: {
          b->DoDrop(1);
          b->DoLoadConstant(w->program_->false_object());
          break;
        }

        // FIXME:
        case kEnterNoSuchMethod: {
          b->DoEnterNSM();
          break;
        }

        case kLoadStaticInit: {
          b->DoLoadStatic(Utils::ReadInt32(bcp + 1), true);
          break;
        }
        case kLoadStatic: {
          b->DoLoadStatic(Utils::ReadInt32(bcp + 1), false);
          break;
        }
        case kStoreStatic: {
          b->DoStoreStatic(Utils::ReadInt32(bcp + 1));
          break;
        }

        case kProcessYield: {
          b->DoProcessYield();
          break;
        }

        case kMethodEnd: {
          stop = true;
          break;
        }

        default: {
          b->DoExitFatal(
              name("Unsupported bytecode: %s. Exiting due to fatal error.",
                   bytecode_string(bcp)));
          b->DoReturnNull();
          Print::Error("     ---> Unsupported \"%s\"\n", bytecode_string(bcp));
          stop = true;
          break;
        }
      }
      last_opcode_was_jump = IsBranchOpcode(opcode);
      bci = next_bci;
    } while (labels.find(bci) == labels.end() && !stop);

    if (!last_opcode_was_jump && !stop) {
      b->DoBranch(bci);
    }
  }

  // Scans [bci] until the next DoBranch occurs and records on that DoBranch
  // target(s) the stacksize.
  void ScanBci(int bci, int stacksize) {
    // FIXME/TODO(llvm):
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
          // Subroutines are executed with return address delta on a stack.
          Enqueue(bci + Utils::ReadInt32(bcp + 1), stacksize + 1);
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
      uint8* catch_block_address =
          function_->bytecode_address_for(frame_ranges_offset);
      int count = Utils::ReadInt32(catch_block_address);
      CatchBlock* blocks =
          reinterpret_cast<CatchBlock*>(catch_block_address + 4);
      for (int i = 0; i < count; i++) {
        catch_blocks_.insert(blocks[i].end);
        catch_ranges_.push_back(std::make_pair(blocks[i].start, blocks[i].end));
        Enqueue(blocks[i].end, blocks[i].frame_size);
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
      ASSERT(stacksize == labels[bci]);
    }
  }

  bool IsBranchOpcode(Opcode op) {
    return op == kBranchWide || op == kBranchIfTrueWide ||
           op == kBranchIfFalseWide || op == kBranchBack ||
           op == kBranchBackIfTrue || op == kBranchBackIfFalse ||
           op == kBranchBackWide || op == kBranchBackIfTrueWide ||
           op == kBranchBackIfFalseWide || op == kPopAndBranchWide ||
           op == kPopAndBranchBackWide || op == kThrow || op == kReturn;
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

  World* w;
  Function* function_;
  llvm::Function* llvm_function_;
  int max_stacksize_;
  std::map<int, int> labels;
  std::map<int, int> todo;
  std::set<int> catch_blocks_;
  std::vector<std::pair<int, int>> catch_ranges_;
};

class FunctionsBuilder : public HeapObjectVisitor {
 public:
  explicit FunctionsBuilder(World* world) : w(world) {}

  virtual int Visit(HeapObject* object) {
    if (object->IsFunction()) {
      auto function = Function::cast(object);
      auto llvm_function = w->llvm_functions[function];

      BasicBlocksExplorer explorer(w, function, llvm_function);
      explorer.Explore();
      explorer.Build();
    }
    return object->Size();
  }

 private:
  World* w;
};

class FunctionTableBuilder {
 public:
  explicit FunctionTableBuilder(World* world) : w(world) {}

  void Build() {
    int count = w->next_function_id;
    std::vector<llvm::Function*> functions(count);
    {
      size_t i = 0;
      for (auto function_and_id : w->function_to_statepoint_id) {
        functions[i++] = function_and_id.first;
      }
    }
    sort(functions.begin(), functions.end(), [this](llvm::Function* a,
                                                    llvm::Function* b) {
      return w->function_to_statepoint_id[a] < w->function_to_statepoint_id[b];
    });
    std::vector<llvm::Constant*> entries;
    for (llvm::Constant* fn : functions) {
      entries.push_back(w->CCast(fn, w->int8_ptr_type));
    }
    auto array_type = llvm::ArrayType::get(w->int8_ptr_type, count);
    auto array_constant = llvm::ConstantArray::get(array_type, entries);
    new llvm::GlobalVariable(*w->module_, array_type, true,
                             llvm::GlobalValue::ExternalLinkage, array_constant,
                             name("dartino_function_table"));
  }

 private:
  World* w;
};

class RootsBuilder : public PointerVisitor {
 public:
  RootsBuilder(World* world, HeapBuilder* hbuilder)
      : w(world), hbuilder_(hbuilder) {}

  virtual void VisitBlock(Object** start, Object** end) {
    for (; start < end; start++) {
      Object* object = *start;
      if (object->IsHeapObject()) {
        // Ensure we've got a llvm constant for this root.
        hbuilder_->Visit(HeapObject::cast(object));
        // The type of the roots may be more specific than heap_object_type, so
        // cast.
        roots_.push_back(w->CCast(w->tagged_aspace0[HeapObject::cast(object)],
                                  w->object_ptr_aspace0_type));
      } else {
        roots_.push_back(w->CInt2Pointer(w->CSmi(Smi::cast(object)->value()),
                                         w->object_ptr_aspace0_type));
      }
    }
  }

  llvm::Constant* BuildRoots() {
    w->program_->IterateRootsIgnoringSession(this);
    return llvm::ConstantStruct::get(w->roots_type, roots_);
  }

 private:
  World* w;
  HeapBuilder* hbuilder_;
  std::vector<llvm::Constant*> roots_;
};

class GlobalSymbolsBuilder {
 public:
  explicit GlobalSymbolsBuilder(World* world) : w(world) {}

  void BuildGlobalSymbols() {
    std::vector<llvm::Type*> int1(1, w->intptr_type);
    std::vector<llvm::Type*> empty;

    // program_start
    auto program_start = llvm::ConstantInt::getIntegerValue(
        w->intptr_type, llvm::APInt(w->bits_per_word, 4096, false));
    auto program_size = llvm::ConstantInt::getIntegerValue(
        w->intptr_type, llvm::APInt(w->bits_per_word, 1024 * 1024, false));
    new llvm::GlobalVariable(*w->module_, w->intptr_type, true,
                             llvm::GlobalValue::ExternalLinkage, program_start,
                             "program_start");
    new llvm::GlobalVariable(*w->module_, w->intptr_type, true,
                             llvm::GlobalValue::ExternalLinkage, program_size,
                             "program_size");
    auto entry =
        static_cast<llvm::Function*>(w->llvm_functions[w->program_->entry()]);
    new llvm::GlobalVariable(*w->module_, entry->getType(), true,
                             llvm::GlobalValue::ExternalLinkage, entry,
                             "program_entry");
    new llvm::GlobalVariable(*w->module_, w->roots_type, true,
                             llvm::GlobalValue::ExternalLinkage, w->roots,
                             "program_info_block");
  }

 private:
  World* w;
};

World::World(Program* program, llvm::LLVMContext* context, llvm::Module* module)
    : program_(program),
      context(context),
      module_(module),
      bits_per_word(0),
      intptr_type(NULL),
      int1_type(NULL),
      int8_type(NULL),
      int8_ptr_type(NULL),
      int8_ptr_aspace1_type(NULL),
      int32_type(NULL),
      int64_type(NULL),
      float_type(NULL),
      object_ptr_type(NULL),
      object_ptr_ptr_type(NULL),
      object_ptr_aspace0_type(NULL),
      object_ptr_aspace0_ptr_aspace0_type(NULL),
      object_ptr_ptr_unsafe_type(NULL),
      arguments_ptr_type(NULL),
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
      initializer_type(NULL),
      initializer_ptr_type(NULL),
      instance_type(NULL),
      instance_ptr_type(NULL),
      largeinteger_type(NULL),
      largeinteger_ptr_type(NULL),
      double_type(NULL),
      double_ptr_type(NULL),
      process_ptr_type(NULL),
      roots(NULL),
      libc__exit(NULL),
      libc__printf(NULL),
      libc__puts(NULL),
      runtime__HandleGC(NULL),
      runtime__HandleAllocate(NULL),
      runtime__HandleAllocateBoxed(NULL),
      runtime__HandleObjectFromFailure(NULL) {
  llvm::MDBuilder md_builder(*context);

  int1_type = llvm::Type::getInt1Ty(*context);
  int8_type = llvm::Type::getInt8Ty(*context);
  int8_ptr_type = llvm::PointerType::get(int8_type, 0);
  int8_ptr_aspace1_type = llvm::PointerType::get(int8_type, 1);
  int8_ptr_ptr_type = llvm::PointerType::get(int8_ptr_type, 0);
  int32_type = llvm::Type::getInt32Ty(*context);
  int64_type = llvm::Type::getInt64Ty(*context);

  if (Flags::codegen_64) {
    intptr_type = int64_type;
    bits_per_word = 64;
  } else {
    intptr_type = int32_type;
    bits_per_word = 32;
  }

  // NOTE: Our target dart double's are assumed to be 64-bit C double!
  float_type = llvm::Type::getDoubleTy(*context);

  // The object_ptr_type corresponds to the tagged Object* pointer. It is in
  // address space 1, which is the GCed space. It may not be that important
  // what the width of the underlying type is, since we can't dereference these
  // pointers without intrinsics.
  object_ptr_type = llvm::PointerType::get(int8_type, 1);
  object_ptr_aspace0_type = llvm::PointerType::get(int8_type, 0);

  // Used for accessing fields with inner pointers, this is also a tagged GCed
  // pointer. This assumes that the GC understands inner pointers, at least on
  // the stack.
  object_ptr_ptr_type = llvm::PointerType::get(object_ptr_type, 1);
  object_ptr_aspace0_ptr_aspace0_type =
      llvm::PointerType::get(object_ptr_aspace0_type, 0);
  object_ptr_ptr_unsafe_type = llvm::PointerType::get(object_ptr_type, 0);

  // Used for the alloca'ed array of arguments to natives. This is not a
  // GCed pointer itself (because it points at the stack), but the contents
  // of the array is GCed pointers.
  arguments_ptr_type = llvm::PointerType::get(object_ptr_type, 0);

  heap_object_type = llvm::StructType::create(*context, "HeapType");
  heap_object_ptr_type = llvm::PointerType::get(heap_object_type, 0);

  class_type = llvm::StructType::create(*context, "ClassType");
  class_ptr_type = llvm::PointerType::get(class_type, 0);

  function_type = llvm::StructType::create(*context, "FunctionType");
  function_ptr_type = llvm::PointerType::get(class_type, 0);

  array_header = llvm::StructType::create(*context, "ArrayType");
  array_header_ptr = llvm::PointerType::get(array_header, 0);

  onebytestring_type = llvm::StructType::create(*context, "OneByteString");
  onebytestring_ptr_type = llvm::PointerType::get(onebytestring_type, 0);

  initializer_type = llvm::StructType::create(*context, "InitializerType");
  initializer_ptr_type = llvm::PointerType::get(initializer_type, 0);

  instance_type = llvm::StructType::create(*context, "InstanceType");
  instance_ptr_type = llvm::PointerType::get(instance_type, 0);

  largeinteger_type = llvm::StructType::create(*context, "LargeIntegerType");
  largeinteger_ptr_type = llvm::PointerType::get(largeinteger_type, 0);

  double_type = llvm::StructType::create(*context, "DoubleType");
  double_ptr_type = llvm::PointerType::get(double_type, 0);

  // This pointer just needs to be in the right address space for the
  // compilation to work.
  process_ptr_type = int8_ptr_ptr_type;

  dte_type = llvm::StructType::create(*context, "DispatchTableEntry");
  dte_ptr_type = llvm::PointerType::get(dte_type, 0);
  dte_ptr_ptr_type = llvm::PointerType::get(dte_ptr_type, 0);

  roots_type = llvm::StructType::create(*context, "ProgramRootsType");
  roots_ptr_type = llvm::PointerType::get(roots_type, 0);

  // [heap_object_type]
  std::vector<llvm::Type*> heap_object_entries = {class_ptr_type};
  heap_object_type->setBody(heap_object_entries, true);

  // [class_type]
  std::vector<llvm::Type*> class_object_entries;
  class_object_entries.push_back(heap_object_type);
  class_object_entries.push_back(class_ptr_type);    // superclass
  class_object_entries.push_back(intptr_type);       // instance format
  class_object_entries.push_back(intptr_type);       // id
  class_object_entries.push_back(intptr_type);       // child id
  class_object_entries.push_back(array_header_ptr);  // method array
  class_type->setBody(class_object_entries, true);

  // [function_type]
  std::vector<llvm::Type*> function_object_entries;
  function_object_entries.push_back(heap_object_type);
  function_object_entries.push_back(intptr_type);  // bytecode size
  function_object_entries.push_back(intptr_type);  // literals size
  function_object_entries.push_back(intptr_type);  // arity
  function_object_entries.push_back(
      intptr_type);  // custom: [word] to machine code
  function_type->setBody(function_object_entries, true);

  // [array_header]
  std::vector<llvm::Type*> array_object_entries;
  array_object_entries.push_back(heap_object_type);
  array_object_entries.push_back(intptr_type);  // length
  array_header->setBody(array_object_entries, true);

  // [onebytestring_ptr_type]
  std::vector<llvm::Type*> obs_object_entries;
  obs_object_entries.push_back(array_header);
  obs_object_entries.push_back(intptr_type);  // hash
  onebytestring_type->setBody(obs_object_entries, true);

  // [initializer_type]
  std::vector<llvm::Type*> initializer_entries;
  initializer_entries.push_back(heap_object_type);
  initializer_entries.push_back(
      object_ptr_aspace0_type);  // machine code (normally function object)
  initializer_type->setBody(initializer_entries);

  // [instance_type]
  std::vector<llvm::Type*> instance_object_entries;
  instance_object_entries.push_back(heap_object_type);
  instance_object_entries.push_back(intptr_type);  // flags
  instance_type->setBody(instance_object_entries, true);

  // [largeinteger_type]
  std::vector<llvm::Type*> largeint_entries;
  largeint_entries.push_back(heap_object_type);
  largeint_entries.push_back(int64_type);
  largeinteger_type->setBody(largeint_entries, true);

  // [double_type]
  std::vector<llvm::Type*> double_entries;
  double_entries.push_back(heap_object_type);
  double_entries.push_back(float_type);
  double_type->setBody(double_entries, true);

  // [dte_type]
  std::vector<llvm::Type*> dte_object_entries;
  dte_object_entries.push_back(heap_object_type);
  dte_object_entries.push_back(object_ptr_aspace0_type);  // target
  dte_object_entries.push_back(object_ptr_aspace0_type);  // (machine)code
  dte_object_entries.push_back(object_ptr_aspace0_type);  // offset
  dte_object_entries.push_back(object_ptr_aspace0_type);  // selector
  dte_type->setBody(dte_object_entries, true);

  // [roots_type]
  std::vector<llvm::Type*> root_entries;
#define ADD_ROOT(type, name, CamelName) \
  root_entries.push_back(object_ptr_aspace0_type);
  ROOTS_DO(ADD_ROOT)
#undef ADD_ROOT
  root_entries.push_back(object_ptr_aspace0_type);  // Program::entry_
  roots_type->setBody(root_entries, true);

  // External C functions for debugging.

  auto exit_type = llvm::FunctionType::get(intptr_type, {int32_type}, false);
  libc__exit = llvm::Function::Create(
      exit_type, llvm::Function::ExternalLinkage, "exit", module_);

  auto printf_type =
      llvm::FunctionType::get(intptr_type, {int8_ptr_type}, true);
  libc__printf = llvm::Function::Create(
      printf_type, llvm::Function::ExternalLinkage, "printf", module_);

  auto puts_type = llvm::FunctionType::get(intptr_type, {int8_ptr_type}, false);
  libc__puts = llvm::Function::Create(
      puts_type, llvm::Function::ExternalLinkage, "puts", module_);

  auto handle_gc_type =
      llvm::FunctionType::get(llvm::Type::getVoidTy(*context),
                              {process_ptr_type, int8_ptr_type}, false);
  auto gc_trampoline_type = llvm::FunctionType::get(
      llvm::Type::getVoidTy(*context), {process_ptr_type}, false);
  auto handle_allocate_type = llvm::FunctionType::get(
      object_ptr_type, {process_ptr_type, object_ptr_type, intptr_type}, false);
  auto handle_allocate_boxed_type = llvm::FunctionType::get(
      object_ptr_type, {process_ptr_type, object_ptr_type}, false);
  auto handle_object_from_failure_type = llvm::FunctionType::get(
      object_ptr_type, {process_ptr_type, object_ptr_type}, false);

  runtime__HandleGC =
      llvm::Function::Create(handle_gc_type, llvm::Function::ExternalLinkage,
                             "HandleGCWithFP", module_);
  dartino_gc_trampoline = llvm::Function::Create(
      gc_trampoline_type, llvm::Function::ExternalLinkage,
      "dartino_gc_trampoline", module_);
  llvm::AttributeSet attr_set = dartino_gc_trampoline->getAttributes();
  attr_set = attr_set.addAttribute(*context, llvm::AttributeSet::FunctionIndex,
                                   llvm::Attribute::NoInline);
  dartino_gc_trampoline->setAttributes(attr_set);
  CreateGCTrampoline();

  runtime__HandleAllocate = llvm::Function::Create(
      handle_allocate_type, llvm::Function::ExternalLinkage, "HandleAllocate",
      module_);
  runtime__HandleAllocateBoxed = llvm::Function::Create(
      handle_allocate_boxed_type, llvm::Function::ExternalLinkage,
      "HandleAllocateBoxed", module_);
  runtime__HandleObjectFromFailure = llvm::Function::Create(
      handle_object_from_failure_type, llvm::Function::ExternalLinkage,
      "HandleObjectFromFailure", module_);

  // Exception handling types and functions.

  auto raise_exception_type =
      llvm::FunctionType::get(llvm::Type::getVoidTy(*context),
                              {process_ptr_type, object_ptr_type}, false);
  raise_exception = llvm::Function::Create(raise_exception_type,
                                           llvm::Function::ExternalLinkage,
                                           "ThrowException", module_);
  raise_exception->setDoesNotReturn();

  auto current_exception_type =
      llvm::FunctionType::get(object_ptr_type, {process_ptr_type}, false);
  current_exception = llvm::Function::Create(current_exception_type,
                                             llvm::Function::ExternalLinkage,
                                             "CurrentException", module_);

  std::vector<llvm::Type*> dart_personality_type_args = {
      int32_type, int32_type, int64_type, int8_ptr_type, int8_ptr_type};
  auto dart_personality_type =
      llvm::FunctionType::get(int32_type, dart_personality_type_args, false);
  dart_personality = llvm::Function::Create(dart_personality_type,
                                            llvm::Function::ExternalLinkage,
                                            "DartPersonality", module_);
  caught_result_type = llvm::Type::getTokenTy(*context);

  llvm::MDNode* root = md_builder.createAnonymousTBAARoot();
  remembered_set_alias_analysis_node =
      md_builder.createTBAANode("remembered_set", root);
  regular_field_alias_analysis_node =
      md_builder.createTBAANode("dart_field", root);
  invariant_alias_analysis_node =
      md_builder.createTBAANode("invariant", root, true);
}

llvm::StructType* World::ObjectArrayType(int n, llvm::Type* entry_type,
                                         const char* name_) {
  auto array = llvm::StructType::create(*context, name("%s__%d", name_, n));
  std::vector<llvm::Type*> types;
  types.push_back(array_header);
  for (int i = 0; i < n; i++) {
    types.push_back(entry_type);
  }
  array->setBody(types, true);
  return array;
}

llvm::StructType* World::InstanceType(int n) {
  auto inst_type = llvm::StructType::create(*context, name("Instance__%d", n));
  std::vector<llvm::Type*> types;
  types.push_back(instance_type);
  for (int i = 0; i < n; i++) {
    types.push_back(object_ptr_aspace0_type);
  }
  inst_type->setBody(types, true);
  return inst_type;
}

llvm::PointerType* World::InstanceTypePtr(int n) {
  return llvm::PointerType::get(InstanceType(n), 0);
}

llvm::StructType* World::OneByteStringType(int n) {
  auto obs_type =
      llvm::StructType::create(*context, name("OneByteString__%d", n));
  std::vector<llvm::Type*> types = {
      onebytestring_type, llvm::ArrayType::get(int8_type, n),
  };
  obs_type->setBody(types, true);
  return obs_type;
}

llvm::FunctionType* World::FunctionType(int arity) {
  std::vector<llvm::Type*> args(1 /* process */ + arity, object_ptr_type);
  args[0] = process_ptr_type;
  return llvm::FunctionType::get(object_ptr_type, args, false);
}

llvm::PointerType* World::FunctionPtrType(int arity) {
  return llvm::PointerType::get(FunctionType(arity), false);
}

llvm::Constant* World::CTag(llvm::Constant* constant, llvm::Type* ptr_type) {
  if (ptr_type == NULL) ptr_type = object_ptr_type;
  ASSERT(constant->getType()->isPointerTy());
  ASSERT(constant->getType()->getPointerAddressSpace() == 0);
  ASSERT(ptr_type->getPointerAddressSpace() == 1);
  std::vector<llvm::Value*> indices = {CInt(1)};
  auto tagged = llvm::ConstantExpr::getGetElementPtr(
      int8_type, llvm::ConstantExpr::getBitCast(constant, int8_ptr_type),
      indices, "tagged");
  return llvm::ConstantExpr::getAddrSpaceCast(tagged, ptr_type);
}

llvm::Constant* World::CTagAddressSpaceZero(llvm::Constant* constant,
                                            llvm::Type* ptr_type) {
  if (ptr_type == NULL) ptr_type = object_ptr_aspace0_type;
  ASSERT(constant->getType()->isPointerTy());
  ASSERT(constant->getType()->getPointerAddressSpace() == 0);
  ASSERT(ptr_type->getPointerAddressSpace() == 0);
  std::vector<llvm::Value*> indices = {CInt(1)};
  auto tagged = llvm::ConstantExpr::getGetElementPtr(
      int8_type, llvm::ConstantExpr::getBitCast(constant, int8_ptr_type),
      indices, "tagged_as0_");
  return llvm::ConstantExpr::getBitCast(tagged, ptr_type);
}

llvm::Constant* World::CBit(int8 value) {
  uint64 value64 = value;
  return llvm::ConstantInt::getIntegerValue(intptr_type,
                                            llvm::APInt(1, value64, false));
}

llvm::Constant* World::CWord(intptr_t value) {
  int64 value64 = value;
  return llvm::ConstantInt::getIntegerValue(
      intptr_type, llvm::APInt(bits_per_word, value64, true));
}

llvm::Constant* World::CInt(int32 value) {
  int64 value64 = value;
  return llvm::ConstantInt::getIntegerValue(intptr_type,
                                            llvm::APInt(32, value64, true));
}

llvm::Constant* World::CInt8(uint8 integer) {
  uint64 value64 = integer;
  return llvm::ConstantInt::getIntegerValue(intptr_type,
                                            llvm::APInt(8, value64, true));
}

llvm::Constant* World::CInt64(int64 value) {
  return llvm::ConstantInt::getIntegerValue(intptr_type,
                                            llvm::APInt(64, value, true));
}

llvm::Constant* World::CDouble(double value) {
  return llvm::ConstantFP::get(float_type, value);
}

llvm::Constant* World::CSmi(word integer) {
  return CWord(reinterpret_cast<intptr_t>(Smi::FromWord(integer)));
}

llvm::Constant* World::CPointer2Int(llvm::Constant* constant) {
  return llvm::ConstantExpr::getPtrToInt(constant, intptr_type);
}

llvm::Constant* World::CInt2Pointer(llvm::Constant* constant,
                                    llvm::Type* ptr_type) {
  if (ptr_type == NULL) ptr_type = object_ptr_type;
  return llvm::ConstantExpr::getIntToPtr(constant, ptr_type);
}

llvm::Constant* World::CCast(llvm::Constant* constant, llvm::Type* ptr_type) {
  if (ptr_type == NULL) ptr_type = object_ptr_aspace0_type;
  return llvm::ConstantExpr::getPointerCast(constant, ptr_type);
}

void World::CreateGCTrampoline() {
  llvm::IRBuilder<> builder(*context);
  BasicBlockBuilder b(this, NULL, dartino_gc_trampoline, &builder, {});
  b.DoPrologue();

  auto get_fp = llvm::Intrinsic::getDeclaration(
      module_, llvm::Intrinsic::frameaddress, {int32_type});
  // Get frame pointer of 0th function on the stack (ie this one).
  auto fp = builder.CreateCall(get_fp, {CInt(0)}, "fp");

  std::vector<llvm::Value*> args(2);
  int index = 0;
  for (llvm::Argument& arg : dartino_gc_trampoline->getArgumentList()) {
    args[index++] = &arg;
  }
  args[index++] = fp;

  builder.CreateCall(runtime__HandleGC, args);
  builder.CreateRetVoid();
}

// Makes external function delcarations for a natural native method (native
// with a natural calling convention, rather than an arguments array).  Also
// creates the trampoline.  The purpose of the trampoline is to check whether
// the native failed because a GC is needed.  If necessary the GC can be
// performed and the native retried.  Putting it in this trampoline reduces
// code bloat.  TODO(erikcorry): Measure whether this matters.
//
// The function names have the form: Native<name-of-native>
// => The result is available via:  world.natural_natives_[nativeIndex]
//
// The trampoline is returned.
llvm::Function* World::NativeTrampoline(Native nativeId, int arity) {
  llvm::Function* cached = natural_native_trampolines_[nativeId];
  if (cached != nullptr) return cached;

  std::vector<llvm::Type*> types(arity + 1);
  types[0] = process_ptr_type;
  for (int i = 0; i < arity; i++) {
    types[i + 1] = object_ptr_type;
  }
  llvm::FunctionType* function_type =
      llvm::FunctionType::get(object_ptr_type, types, false);
  llvm::Function* declaration = nullptr;
  llvm::Function* trampoline = nullptr;

#define N(e, c, n, d)                                                          \
  if (nativeId == k##e) {                                                      \
    declaration = llvm::Function::Create(                                      \
        function_type, llvm::Function::ExternalLinkage, "Native" #e, module_); \
    trampoline =                                                               \
        llvm::Function::Create(function_type, llvm::Function::ExternalLinkage, \
                               "trampoline_" #e, module_);                     \
  }
  NATIVES_DO(N)
#undef N

  trampoline->setGC("statepoint-example");
  GiveIdToFunction(trampoline);

  llvm::IRBuilder<> builder(*context);
  BasicBlockBuilder b(this, NULL, trampoline, &builder, {});
  b.DoPrologue();

  std::vector<llvm::Value*> args(arity + 1);
  int index = 0;
  for (llvm::Argument& arg : trampoline->getArgumentList()) {
    args[index++] = &arg;
  }

  auto bb_gc_retry = llvm::BasicBlock::Create(*context, "gc_retry", trampoline);
  builder.CreateBr(bb_gc_retry);

  builder.SetInsertPoint(bb_gc_retry);
  auto result = builder.CreateCall(declaration, args, "result");

  // Natives can't cause GC (but they can return a value that indicates we
  // need a GC).
  b.SetNoGC(result);

  auto bb_call_gc = llvm::BasicBlock::Create(*context, "call_gc", trampoline);
  auto bb_return = llvm::BasicBlock::Create(*context, "return", trampoline);

  auto mask = CWord(Failure::kTypeMask | Failure::kTagMask);
  auto value = CWord(Failure::kRetryAfterGC | Failure::kTag);
  auto check = builder.CreateICmpEQ(
      builder.CreateAnd(builder.CreatePtrToInt(result, intptr_type), mask),
      value);
  llvm::MDBuilder md_builder(*context);
  llvm::MDNode* assume_no_fail = md_builder.createBranchWeights(0, 1000);
  builder.CreateCondBr(check, bb_call_gc, bb_return, assume_no_fail);

  builder.SetInsertPoint(bb_return);
  builder.CreateRet(result);

  builder.SetInsertPoint(bb_call_gc);
  auto process = args[0];
  builder.CreateCall(dartino_gc_trampoline, {process});
  builder.CreateBr(bb_gc_retry);

  natural_natives_[nativeId] = declaration;
  natural_native_trampolines_[nativeId] = trampoline;
  return trampoline;
}

llvm::Function* World::GetSmiSlowCase(int selector) {
  auto cached = smi_slow_cases.find(selector);
  if (cached != smi_slow_cases.end()) return cached->second;

  auto type = FunctionType(2);
  auto function = llvm::Function::Create(type, llvm::Function::ExternalLinkage,
                                         name("Smi_%p", selector), module_);
  function->setGC("statepoint-example");
  GiveIdToFunction(function);

  llvm::IRBuilder<> builder(*context);
  BasicBlockBuilder b(this, NULL, function, &builder, {});
  b.DoPrologue();

  std::vector<llvm::Value*> args(3);
  int index = 0;
  for (llvm::Argument& arg : function->getArgumentList()) {
    args[index++] = &arg;
  }
  // TODO(dmitryolsh): revise this 0 as BCI arg
  llvm::Value* result = b.InvokeMethodHelper(0, selector, args);
  builder.CreateRet(result);

  smi_slow_cases[selector] = function;
  return function;
}

void World::GiveIdToFunction(llvm::Function* llvm_function) {
  llvm::AttributeSet attr_set = llvm_function->getAttributes();
  int id = next_function_id++;
  attr_set = attr_set.addAttribute(*context, llvm::AttributeSet::FunctionIndex,
                                   "dartino-id", std::to_string(id));
  llvm_function->setAttributes(attr_set);
  function_to_statepoint_id[llvm_function] = id;
}

static void BuildVtable(World* w) {
  // One big vtable for the whole program. Unlike the dispatch table this
  // just has code pointers, removing a level of indirection.
  Array* dispatch_table = w->program_->dispatch_table();
  int length = dispatch_table->length();
  auto vtable_type = llvm::ArrayType::get(w->int8_ptr_type, length);
  std::vector<llvm::Constant*> elements;
  for (int i = 0; i < length; i++) {
    DispatchTableEntry* entry =
        DispatchTableEntry::cast(dispatch_table->get(i));
    Function* target = entry->target();
    auto code = w->llvm_functions[target];
    elements.push_back(
        llvm::ConstantExpr::getPointerCast(code, w->int8_ptr_type));
  }
  auto vtable = llvm::ConstantArray::get(vtable_type, elements);
  vtable = new llvm::GlobalVariable(
      *w->module_, vtable_type, true, llvm::GlobalValue::ExternalLinkage,
      vtable, "dartino_vtable");
  w->vtable = llvm::ConstantExpr::getPointerCast(vtable, w->int8_ptr_ptr_type);
}

void LLVMCodegen::Generate(const char* filename, bool optimize,
                           bool verify_module) {
  llvm::LLVMContext context;
  llvm::Module module("dart_code", context);

  // llvm::DebugFlag = 1;
  // llvm::setCurrentDebugType("stackmaps");
  // llvm::setCurrentDebugType("statepoint-lowering");
  // llvm::setCurrentDebugType("rewrite-statepoints-for-gc");

  World world(program_, &context, &module);

  ExceptionsSetup();

  CreateGCSafepointPollFunction(&module, &world, &context);

  HeapBuilder builder(&world);
  program_->heap()->IterateObjects(&builder);

  RootsBuilder rbuilder(&world, &builder);
  world.roots = rbuilder.BuildRoots();

  BuildVtable(&world);

  NativesBuilder nbuilder(&world);
  nbuilder.BuildNativeDeclarations();

  FunctionsBuilder fbuilder(&world);
  program_->heap()->IterateObjects(&fbuilder);

  FunctionTableBuilder function_table_builder(&world);
  function_table_builder.Build();

  GlobalSymbolsBuilder sbuilder(&world);
  sbuilder.BuildGlobalSymbols();

  if (verify_module) {
    // Please note that this is pretty time consuming!
    VerifyModule(&module);
  }

  if (optimize) {
    OptimizeModule(&module, &world);
  }

  LowerIntrinsics(&module, &world);

  if (optimize) {
    OptimizeAfterLowering(&module, &world);
  }

  SaveModule(&module, filename);
}

void LLVMCodegen::VerifyModule(llvm::Module* module) {
  std::string ErrorStr;
  llvm::raw_string_ostream OS(ErrorStr);
  Print::Error("Module verification started ...");
  if (llvm::verifyModule(*module, &OS)) {
    Print::Error("Module verification failed:");
    std::cerr << OS.str();
    FATAL("Modul verification failed. Cannot proceed.");
  }
  Print::Error("Module verification passed.");
}

struct AddStatepointIDsToCallSites : public llvm::FunctionPass {
  static char ID;  // Pass identification, replacement for typeid.
  World* w;
  explicit AddStatepointIDsToCallSites(World* world)
      : FunctionPass(ID), w(world) {}

  void setAttributes(llvm::BasicBlock& bb, const std::string& id) {
    for (llvm::Instruction& instruction : bb) {
      if (llvm::CallInst* call = llvm::dyn_cast<llvm::CallInst>(&instruction)) {
        if (llvm::Function* function = call->getCalledFunction()) {
          if (function->hasFnAttribute("gc-leaf-function")) continue;
        }
        call->addAttribute(llvm::AttributeSet::FunctionIndex, "statepoint-id",
                           id);
      } else if (llvm::InvokeInst* invoke =
                     llvm::dyn_cast<llvm::InvokeInst>(&instruction)) {
        if (llvm::Function* function = invoke->getCalledFunction()) {
          if (function->hasFnAttribute("gc-leaf-function")) continue;
        }
        llvm::AttributeSet attributes = invoke->getAttributes();
        attributes = attributes.addAttribute(*w->context,
                                             llvm::AttributeSet::FunctionIndex,
                                             "statepoint-id", id);
        invoke->setAttributes(attributes);
      }
    }
  }

  bool runOnFunction(llvm::Function& func) override {
    auto caller_attributes = func.getAttributes();
    std::string id =
        caller_attributes.getAttribute(llvm::AttributeSet::FunctionIndex,
                                       "dartino-id")
            .getValueAsString();
    for (llvm::BasicBlock& bb : func) {
      setAttributes(bb, id);
    }
    return false;
  }
};

// A pass to lower tagread intrinsics into actual instructions.
struct RewriteGCIntrinsics : public llvm::FunctionPass {
  static char ID;  // Pass identification, replacement for typeid.
  World* w;
  llvm::Module* m;
  llvm::Value* process;
  RewriteGCIntrinsics(World* world, llvm::Module* module)
      : FunctionPass(ID), w(world), m(module) {}

  bool tryRewrite(llvm::BasicBlock& bb) {
    for (llvm::Instruction& instruction : bb) {
      if (llvm::CallInst* call = llvm::dyn_cast<llvm::CallInst>(&instruction)) {
        llvm::Function* fn = call->getCalledFunction();
        if (fn && fn->isIntrinsic()) {
          fn->recalculateIntrinsicID();
          llvm::IRBuilder<> b(&instruction);
          IRHelper h(w, &b);
          // Have to stop iteration by returning true if block structure has
          // changed.
          switch (fn->getIntrinsicID()) {
            case llvm::Intrinsic::tagread: {
              llvm::Value* pointer = call->getArgOperand(0);
              pointer = b.CreatePointerBitCastOrAddrSpaceCast(pointer,
                                                              w->int8_ptr_type);
              auto gep = b.CreateGEP(pointer, {w->CInt(-1)});
              gep = b.CreatePointerCast(gep,
                                        w->object_ptr_aspace0_ptr_aspace0_type);
              auto result = b.CreateLoad(gep);
              auto cast_result = b.CreatePointerBitCastOrAddrSpaceCast(
                  result, w->object_ptr_type);
              call->replaceAllUsesWith(cast_result);
              call->eraseFromParent();
              return true;
            }
            case llvm::Intrinsic::tagwrite: {
              auto receiver = call->getArgOperand(0);
              auto value = call->getArgOperand(1);
              auto cell = call->getArgOperand(2);

              h.WriteFieldNoWriteBarrier(cell, value);

              // Remembered set write barrier.
              auto card1 = b.CreateLShr(
                  b.CreatePtrToInt(call->getArgOperand(0), w->intptr_type),
                  w->CWord(GCMetadata::kCardBits), "card1");
              auto bias_gep = h.RememberedSetBiasGEP(process);
              auto bias = b.CreateLoad(bias_gep);
              bias->setMetadata(llvm::LLVMContext::MD_invariant_load,
                                llvm::MDNode::get(*w->context, llvm::None));
              bias->setMetadata(llvm::LLVMContext::MD_tbaa,
                                w->invariant_alias_analysis_node);
              auto mark = b.CreateGEP(bias, card1, "mark");
              // Cast the receiver to a byte and use that to store into the
              // byte-sized card mark. The receiver is always tagged with 1, so
              // we know it is not going to be zero.
              auto remembered_set_store =
                  b.CreateStore(b.CreatePtrToInt(receiver, w->int8_type), mark);
              remembered_set_store->setMetadata(
                  llvm::LLVMContext::MD_tbaa,
                  w->remembered_set_alias_analysis_node);
              call->eraseFromParent();
              return true;
            }
            case llvm::Intrinsic::smitoint: {
              auto pointer = call->getArgOperand(0);
              auto number = b.CreatePtrToInt(pointer, w->intptr_type);
              auto result = b.CreateAShr(number, w->CInt(1));
              call->replaceAllUsesWith(result);
              call->eraseFromParent();
              return true;
            }
            case llvm::Intrinsic::smitoint64: {
              auto pointer = call->getArgOperand(0);
              auto number = b.CreatePtrToInt(pointer, w->int64_type);
              // Remove tag with an arithmetic shift.
              auto result = b.CreateAShr(number, w->CInt64(1));
              call->replaceAllUsesWith(result);
              call->eraseFromParent();
              return true;
            }
            case llvm::Intrinsic::inttosmi64:
            case llvm::Intrinsic::inttosmi: {
              auto number = call->getArgOperand(0);
              // Tag with zero by adding to itself.
              number = b.CreateAdd(number, number);
              auto result = b.CreateIntToPtr(number, w->object_ptr_type);
              call->replaceAllUsesWith(result);
              call->eraseFromParent();
              return true;
            }
            default:
              break;
          }
        }
      }
    }
    return false;
  }

  bool runOnFunction(llvm::Function& func) override {
    // 0th argument is always the process.
    process = &*func.getArgumentList().begin();
    for (llvm::BasicBlock& bb : func) {
      while (tryRewrite(bb)) {
      }
    }
    process = nullptr;
    return false;
  }
};

char RewriteGCIntrinsics::ID = 0;
char AddStatepointIDsToCallSites::ID = 1;

// The createPlaceSafepointsPass that is built into Clang takes the body of the
// gc.safepoint_poll function and inlines its body at the safepoint site. Right
// now we don't have support for polling for GC.  If we need it (for
// multithread implementations) it might want to check the stack limit. Right
// now, we just return void, which turns into nothing when inlined.
void LLVMCodegen::CreateGCSafepointPollFunction(llvm::Module* module,
                                                World* world,
                                                llvm::LLVMContext* context) {
  llvm::IRBuilder<> builder(*context);

  auto poll_function_as_constant = module->getOrInsertFunction(
      "gc.safepoint_poll", llvm::Type::getVoidTy(*context), nullptr);
  auto poll_fn = llvm::cast<llvm::Function>(poll_function_as_constant);
  auto entry = llvm::BasicBlock::Create(*world->context,
                                        "gc.safepoint_poll.entry", poll_fn);

  builder.SetInsertPoint(entry);
  builder.CreateRetVoid();
}

void LLVMCodegen::OptimizeModule(llvm::Module* module, World* world) {
  llvm::legacy::FunctionPassManager fpm(module);

  // TODO(llvm): We should find out what other optimization passes would makes
  // sense.
  llvm::legacy::PassManager mpm;
  mpm.add(llvm::createFunctionInliningPass());
  mpm.run(*module);

  fpm.add(llvm::createPromoteMemoryToRegisterPass());
  fpm.add(llvm::createCFGSimplificationPass());
  fpm.add(llvm::createConstantPropagationPass());
  fpm.add(llvm::createLICMPass());
  fpm.add(llvm::createEarlyCSEPass());
  fpm.add(llvm::createGVNPass());
  fpm.add(llvm::createAggressiveDCEPass());

  if (Flags::optimize) {
    for (auto& f : *module) fpm.run(f);
  } else {
    // Even with -Xno-optimize we optimize the one function that has "use llvm".
    for (auto& f : *module) {
      if (world->use_llvm_function) {
        if (world->use_llvm_function == &f) {
          fpm.run(f);
        }
      } else {
        fpm.run(f);
      }
    }
  }
}

void LLVMCodegen::LowerIntrinsics(llvm::Module* module, World* world) {
  llvm::legacy::FunctionPassManager fpm(module);

  fpm.add(new AddStatepointIDsToCallSites(world));
  fpm.add(llvm::createPlaceSafepointsPass());
  fpm.add(new RewriteGCIntrinsics(world, module));

  for (auto& f : *module) fpm.run(f);

  llvm::legacy::PassManager mpm;
  mpm.add(llvm::createRewriteStatepointsForGCPass());
  mpm.run(*module);
}

void LLVMCodegen::OptimizeAfterLowering(llvm::Module* module, World* world) {
  llvm::legacy::FunctionPassManager fpm(module);

  fpm.add(llvm::createEarlyCSEPass());
  fpm.add(llvm::createDeadStoreEliminationPass());
  fpm.add(llvm::createLICMPass());

  if (Flags::optimize) {
    for (auto& f : *module) fpm.run(f);
  } else {
    // Even with -Xno-optimize we optimize the one function that has "use llvm".
    for (auto& f : *module) {
      if (world->use_llvm_function) {
        if (world->use_llvm_function == &f) {
          fpm.run(f);
        }
      } else {
        fpm.run(f);
      }
    }
  }
}

void LLVMCodegen::SaveModule(llvm::Module* module, const char* filename) {
  // This would dump the LLVM IR in text format to stdout.
  // module->dump();

  std::error_code ec;
  llvm::raw_fd_ostream stream(filename, ec, llvm::sys::fs::F_RW);
  if (ec) FATAL("Could not open output file");
  llvm::WriteBitcodeToFile(module, stream);
}

// ************ Utilities *******************

// Buffers used for implementing [name].
static int _bit = 0;
static const int kBufferSize = 1024;
static char _buffer[2][kBufferSize];

// This function supports vsnprintf() without memory allocation by using two
// static buffers (switching between them, so the result of one call can be used
// as input to another without overriding the result):
char* name(const char* format, ...) {
  _bit++;
  _bit %= 2;

  va_list vargs;
  va_start(vargs, format);
  vsnprintf(&_buffer[_bit][0], kBufferSize, format, vargs);
  va_end(vargs);

  return &_buffer[_bit][0];
}

// Will return a nice string representation of a bytecode.
char* bytecode_string(uint8* bcp) {
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

static llvm::BasicBlock* ResolveBasicBlock(
    const std::vector<const char*>& labels,
    const std::vector<llvm::BasicBlock*>& blocks, const char* label) {
  ASSERT(blocks.size() == labels.size());
  int len = strlen(label);
  for (unsigned i = 0; i < blocks.size(); i++) {
    if (!strncmp(label, labels[i], len)) return blocks[i];
  }
  UNREACHABLE();  // Misspelled or undefined label.
  return nullptr;
}

void ForthFunction::Codegen(World* w, BasicBlockBuilder* b, IRHelper* h,
                            std::vector<llvm::Value*>* forth_stack) {
  Init();
  llvm::IRBuilder<>* irb = b->b;
  std::vector<llvm::BasicBlock*> blocks;
  for (auto label : labels_) {
    auto block =
        llvm::BasicBlock::Create(*w->context, label, b->llvm_function());
    blocks.push_back(block);
  }
  std::vector<llvm::Value*> locals;
  for (auto var : variable_names_) {
    // We have to add the allocas to the entry block, not the current block,
    // otherwise the mem2reg pass cannot turn them into SSA values.
    llvm::BasicBlock* current = irb->GetInsertBlock();
    irb->SetInsertPoint(b->bb_entry_);
    llvm::Value* slot;
    if (!strncmp("int ", var, 4)) {
      slot = irb->CreateAlloca(w->intptr_type, NULL, var + 4);
    } else if (!strncmp("bool ", var, 5)) {
      slot = irb->CreateAlloca(w->int1_type, NULL, var + 5);
    } else {
      slot = irb->CreateAlloca(w->object_ptr_type, NULL, var);
    }
    irb->SetInsertPoint(current);
    locals.push_back(slot);
  }
  for (auto bc : codes_) {
    switch (bc.instruction) {
      case F_STACK0:
        Push(forth_stack, irb->CreateLoad(b->stack_[0]));
        break;
      case F_STACK1:
        Push(forth_stack, irb->CreateLoad(b->stack_[1]));
        break;
      case F_BIT_TRUE:
        Push(forth_stack, w->CBit(1));
        break;
      case F_BIT_FALSE:
        Push(forth_stack, w->CBit(0));
        break;
      case F_LOAD: {
        auto index = Pop(forth_stack);
        auto object = Pop(forth_stack);
        auto receiver = irb->CreatePointerBitCastOrAddrSpaceCast(
            object, w->int8_ptr_aspace1_type);
        // Untag before loading, but leave address-space-1 on the pointer, so
        // it is GC marked.  The GC should still be able to distinguish this
        // pointer from a Smi because it gets base-derived pairs, and the base
        // will still be tagged.
        // TODO(erikcorry): Fix the offset if the host and the target have
        // different word sizes.
        std::vector<llvm::Value*> indices = {
            irb->CreateAdd(index, w->CWord(-1))};
        auto gep = irb->CreateGEP(receiver, indices, "untagged_gep");
        auto loaded = irb->CreateLoad(
            irb->CreatePointerCast(gep, w->object_ptr_ptr_type));
        Push(forth_stack, loaded);
        break;
      }
      case F_RETURN:
        irb->CreateRet(Pop(forth_stack));
        break;
      case F_PUSH:
        // Pop off the Forth stack and push on the Dart stack.
        b->push(Pop(forth_stack));
        break;
      case F_SMI_CHECK:
        Push(forth_stack, h->CreateSmiCheck(Pop(forth_stack)));
        break;
      case F_IF_ELSE: {
        auto if_true = ResolveBasicBlock(labels_, blocks, bc.label1);
        auto if_false = ResolveBasicBlock(labels_, blocks, bc.label2);
        irb->CreateCondBr(Pop(forth_stack), if_true, if_false);
        break;
      }
      case F_UNTAG:
        Push(forth_stack, h->DecodeSmi(Pop(forth_stack)));
        break;
      case F_TO_PTR:
        Push(forth_stack,
             irb->CreateIntToPtr(Pop(forth_stack), w->object_ptr_type));
        break;
      case F_TO_INT:
        Push(forth_stack,
             irb->CreatePtrToInt(Pop(forth_stack), w->intptr_type));
        break;
      case F_NEG:
        Push(forth_stack, irb->CreateNeg(Pop(forth_stack)));
        break;
      case F_NOT:
        Push(forth_stack, irb->CreateNot(Pop(forth_stack)));
        break;
      case F_SADD_OVERFLOW:
      case F_SSUB_OVERFLOW:
      case F_SMUL_OVERFLOW: {
        auto rhs = Pop(forth_stack);
        auto lhs = Pop(forth_stack);
        auto insn = bc.instruction;
        auto intr = llvm::Intrinsic::smul_with_overflow;
        if (insn == F_SADD_OVERFLOW) intr = llvm::Intrinsic::sadd_with_overflow;
        if (insn == F_SSUB_OVERFLOW) intr = llvm::Intrinsic::ssub_with_overflow;
        llvm::Function* f = llvm::Intrinsic::getDeclaration(
            w->module_, intr, {w->intptr_type});
        auto s = irb->CreateCall(f, {lhs, rhs});
        Push(forth_stack, irb->CreateExtractValue(s, {0}));  // Result.
        Push(forth_stack, irb->CreateExtractValue(s, {1}));  // Overflow bit.
        break;
      }
      case F_DISCARD:
        Pop(forth_stack);
        break;
      case F_GOTO: {
        auto dest = ResolveBasicBlock(labels_, blocks, bc.label1);
        irb->CreateBr(dest);
        break;
      }
      case F_LABEL: {
        auto bb = ResolveBasicBlock(labels_, blocks, bc.label1);
        irb->SetInsertPoint(bb);
        break;
      }
      case F_EQ:
      case F_UGE:
      case F_SLT:
      case F_ADD:
      case F_UDIV:
      case F_ASHR:
      case F_SHL:
      case F_AND: {
        auto rhs = Pop(forth_stack);
        auto lhs = Pop(forth_stack);
        llvm::Value* res;
        switch (bc.instruction) {
          case F_EQ: res = irb->CreateICmpEQ(lhs, rhs); break;
          case F_UGE: res = irb->CreateICmpUGE(lhs, rhs); break;
          case F_SLT: res = irb->CreateICmpSLT(lhs, rhs); break;
          case F_ADD: res = irb->CreateAdd(lhs, rhs); break;
          case F_UDIV: res = irb->CreateUDiv(lhs, rhs); break;
          case F_ASHR: res = irb->CreateAShr(lhs, rhs); break;
          case F_SHL: res = irb->CreateShl(lhs, rhs); break;
          case F_AND: res = irb->CreateAnd(lhs, rhs); break;
          default: UNREACHABLE();
        }
        Push(forth_stack, res);
        break;
      }
      case F_READ:
      case F_ASSIGN: {
        int index = -1;
        int len = strlen(bc.source) - 1;
        for (unsigned i = 0; i <= variable_names_.size(); i++) {
          // Misspelled or undeclared variable.
          ASSERT(i != variable_names_.size());
          const char* var = variable_names_[i];
          if (!strncmp("int ", var, 4)) var += 4;
          if (!strncmp("bool ", var, 5)) var += 5;
          if (!strncmp(var, bc.source, len)) {
            index = i;
            break;
          }
        }
        if (bc.instruction == F_READ) {
          Push(forth_stack, irb->CreateLoad(locals[index]));
        } else {
          ASSERT(bc.instruction == F_ASSIGN);
          irb->CreateStore(Pop(forth_stack), locals[index]);
        }
        break;
      }
      case F_CONSTANT:
        Push(forth_stack, w->CWord(bc.constant));
        break;
      case F_EXPAND_MACRO:
        kArrayLoadMacro.Codegen(w, b, h, forth_stack);
        break;
      case F_NONE:
        UNREACHABLE();
    }
  }
}

}  // namespace dartino
