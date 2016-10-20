// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_CODEGEN_LLVM_H_
#define SRC_VM_CODEGEN_LLVM_H_

#include "src/vm/assembler.h"
#include "src/vm/program.h"
#include "src/vm/vector.h"

#include "src/shared/natives.h"

#ifdef DEBUG
#define DARTINO_DEBUG 1
#undef DEBUG
#endif

#include "llvm/Bitcode/ReaderWriter.h"
#include "llvm/CodeGen/GCStrategy.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/GlobalVariable.h"
#include "llvm/IR/MDBuilder.h"
#include "llvm/IR/Metadata.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Verifier.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/Pass.h"
#include "llvm/Transforms/Scalar.h"

#include "llvm/Support/Debug.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/raw_ostream.h"

#ifdef DARTINO_DEBUG
#undef DEBUG
#undef DARTINO_DEBUG
#define DEBUG 1
#endif

#include <vector>
#include <map>
#include <unordered_map>

namespace dartino {

struct CatchBlock {
  int start;
  int end;
  int frame_size;
};

class World {
 public:
  World(Program* program, llvm::LLVMContext* context, llvm::Module* module);

  llvm::StructType* ObjectArrayType(int n, llvm::Type* entry_type,
                                    const char* name);
  llvm::StructType* InstanceType(int n);
  llvm::PointerType* InstanceTypePtr(int n);
  llvm::StructType* OneByteStringType(int n);
  llvm::FunctionType* FunctionType(int n);
  llvm::PointerType* FunctionPtrType(int n);

  // Helper methods for creating/manipulating constants
  llvm::Constant* CTag(llvm::Constant* constant, llvm::Type* ptr_type);
  llvm::Constant* CTagAddressSpaceZero(llvm::Constant* constant,
                                       llvm::Type* ptr_type = NULL);
  llvm::Constant* CBit(int8 value);
  llvm::Constant* CInt(int32 integer);
  llvm::Constant* CInt8(uint8 integer);
  llvm::Constant* CInt64(int64 value);
  llvm::Constant* CWord(intptr_t value);
  llvm::Constant* CDouble(double value);
  llvm::Constant* CSmi(uint32 integer);
  llvm::Constant* CPointer2Int(llvm::Constant* constant);
  llvm::Constant* CInt2Pointer(llvm::Constant* constant,
                               llvm::Type* ptr_type = NULL);
  llvm::Constant* CCast(llvm::Constant* constant, llvm::Type* ptr_type = NULL);

  // Helper method for getting hold of a smi slow-case helper function for
  // the slow path for inlined smi operations.
  llvm::Function* GetSmiSlowCase(int selector);
  llvm::Function* NativeTrampoline(Native native_id, int arity);

  void GiveIdToFunction(llvm::Function* llvm_function);

  void CreateGCTrampoline();

  Program* const program_;
  llvm::LLVMContext* context;
  llvm::Module* module_;

  // This is the word size (32 or 64) for the target, not llvm-codegen.
  int bits_per_word;

  // Basically intptr_t of the target. Used for pointer->int, int->pointer
  // conversions.
  llvm::IntegerType* intptr_type;
  llvm::IntegerType* int8_type;
  llvm::PointerType* int8_ptr_type;
  llvm::PointerType* int8_ptr_ptr_type;
  llvm::IntegerType* int32_type;
  llvm::IntegerType* int64_type;
  llvm::Type* float_type;

  // dartino::Object*
  llvm::PointerType* object_ptr_type;
  // dartino::Object**
  llvm::PointerType* object_ptr_ptr_type;
  // dartino::Object* where we know it's a constant so it doesn't need to be in
  // address space 1 because constants are not GCed.
  llvm::PointerType* object_ptr_aspace0_type;
  // dartino::Object** where we know it is a field in a constant, which means
  // it is also pointing at a constant.
  llvm::PointerType* object_ptr_aspace0_ptr_aspace0_type;
  // dartino::Object**
  // It's a pointer to a tagged address-space-1 field, but the pointer itself
  // is address-space-0 ie not tracked by the GC machinery.  This could be
  // useful for:
  // * A pointer to an off-heap GC root variable.
  // * A value used late in the optimization process, eg. a GEP obtained after
  //   untagging while lowering load/store intrinsics.  Such GEPS may never be
  //   live at a state point.
  llvm::PointerType* object_ptr_ptr_unsafe_type;
  llvm::PointerType* arguments_ptr_type;

  llvm::StructType* heap_object_type;
  llvm::PointerType* heap_object_ptr_type;

  llvm::StructType* class_type;
  llvm::PointerType* class_ptr_type;

  llvm::StructType* function_type;
  llvm::PointerType* function_ptr_type;

  llvm::StructType* array_header;
  llvm::PointerType* array_header_ptr;

  llvm::StructType* onebytestring_type;
  llvm::PointerType* onebytestring_ptr_type;

  llvm::StructType* initializer_type;
  llvm::PointerType* initializer_ptr_type;

  llvm::StructType* instance_type;
  llvm::PointerType* instance_ptr_type;

  llvm::StructType* largeinteger_type;
  llvm::PointerType* largeinteger_ptr_type;

  llvm::StructType* double_type;
  llvm::PointerType* double_ptr_type;

  llvm::PointerType* process_ptr_type;

  llvm::StructType* dte_type;
  llvm::PointerType* dte_ptr_type;
  llvm::PointerType* dte_ptr_ptr_type;

  llvm::StructType* roots_type;
  llvm::PointerType* roots_ptr_type;

  llvm::Type* caught_result_type;

  llvm::Constant* roots;

  llvm::Function* libc__exit;
  llvm::Function* libc__printf;
  llvm::Function* libc__puts;

  llvm::Function* runtime__HandleGC;
  llvm::Function* dartino_gc_trampoline;
  llvm::Function* runtime__HandleAllocate;
  llvm::Function* runtime__HandleAllocateBoxed;
  llvm::Function* runtime__HandleInvokeSelector;
  llvm::Function* runtime__HandleObjectFromFailure;

  llvm::Function* raise_exception;
  llvm::Function* current_exception;
  llvm::Function* dart_personality;

  // Constants, tagged and in the GC-ed space.
  std::map<HeapObject*, llvm::Constant*> tagged_aspace1;
  // The same, but address space zero.
  std::map<HeapObject*, llvm::Constant*> tagged_aspace0;
  // The actual addresses of constants, ie without the 1-tag.
  std::map<HeapObject*, llvm::Constant*> untagged_aspace0;
  std::map<HeapObject*, llvm::Function*> llvm_functions;
  std::unordered_map<llvm::Function*, int> function_to_statepoint_id;
  int next_function_id = 0;

  std::map<int, llvm::Function*> smi_slow_cases;

  std::vector<llvm::Function*> natives_;
  std::vector<llvm::Function*> natural_natives_ =
      std::vector<llvm::Function*>(dartino::Native::kNumberOfNatives, nullptr);
  std::vector<llvm::Function*> natural_native_trampolines_ =
      std::vector<llvm::Function*>(dartino::Native::kNumberOfNatives, nullptr);
};

static const int kRegularNameSpace = 0;
static const int kGCNameSpace = 1;

class LLVMCodegen {
 public:
  explicit LLVMCodegen(Program* program) : program_(program) {}

  void Generate(const char* filename, bool optimize, bool verify_module);

 private:
  void VerifyModule(llvm::Module* module);
  void OptimizeModule(llvm::Module* module, World* world);
  void CreateGCSafepointPollFunction(llvm::Module* module, World* world,
                                     llvm::LLVMContext* context);
  void LowerIntrinsics(llvm::Module* module, World* world);
  void SaveModule(llvm::Module* module, const char* filename);

  Program* const program_;
};

// ************ Utilities *******************

char* name(const char* format, ...);
char* bytecode_string(uint8* bcp);

}  // namespace dartino

#endif  // SRC_VM_CODEGEN_LLVM_H_
