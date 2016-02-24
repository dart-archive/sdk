// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_CODEGEN_LLVM_H_
#define SRC_VM_CODEGEN_LLVM_H_

#include "src/vm/assembler.h"
#include "src/vm/program.h"
#include "src/vm/vector.h"

#include "src/shared/natives.h"

#include "llvm/Bitcode/ReaderWriter.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/GlobalVariable.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Verifier.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/Transforms/Scalar.h"

#include "llvm/Support/FileSystem.h"
#include "llvm/Support/raw_ostream.h"

#include <vector>
#include <map>

namespace dartino {

class LLVMCodegen {
 public:
  LLVMCodegen(Program* program) : program_(program) { }

  void Generate(const char* filename, bool optimize, bool verify_module);

 private:
  void VerifyModule(llvm::Module& module);
  void OptimizeModule(llvm::Module& module);
  void SaveModule(llvm::Module& module, const char* filename);

  Program* const program_;
};


class World {
 public:
  World(Program* program,
        llvm::LLVMContext& context,
        llvm::Module& module);

  llvm::StructType* ObjectArrayType(int n);
  llvm::StructType* InstanceType(int n);
  llvm::PointerType* InstanceTypePtr(int n);
  llvm::StructType* OneByteStringType(int n);
  llvm::FunctionType* FunctionType(int n);
  llvm::PointerType* FunctionPtrType(int n);
  llvm::PointerType* ObjectArrayPtrType(int n);

  // Helper methods for creating/manipulating constants
  llvm::Constant* CTag(llvm::Constant* constant, llvm::Type* ptr_type = NULL);
  llvm::Constant* CUnTag(llvm::Constant* constant, llvm::Type* ptr_type = NULL);
  llvm::Constant* CInt(uint32 integer);
  llvm::Constant* CInt64(int64 value);
  llvm::Constant* CDouble(double value);
  llvm::Constant* CSmi(uint32 integer);
  llvm::Constant* CPointer2Int(llvm::Constant* constant);
  llvm::Constant* CInt2Pointer(llvm::Constant* constant, llvm::Type* ptr_type = NULL);
  llvm::Constant* CCast(llvm::Constant* constant, llvm::Type* ptr_type = NULL);

  Program* const program_;
  llvm::LLVMContext& context;
  llvm::Module& module_;

  // Basically intptr_t of the target. Used for pointer->int, int->pointer
  // conversions. Currently hardcoded to 32-bit target.
  llvm::IntegerType* intptr_type;
  llvm::IntegerType* int8_type;
  llvm::PointerType* int8_ptr_type;
  llvm::IntegerType* int64_type;
  llvm::Type* float_type;

  llvm::StructType* object_type;
  llvm::PointerType* object_ptr_type;
  llvm::PointerType* object_ptr_ptr_type;

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

  llvm::StructType* dte_type;
  llvm::PointerType* dte_ptr_type;

  llvm::StructType* roots_type;
  llvm::PointerType* roots_ptr_type;

  llvm::Constant* roots;

  llvm::Function* libc__printf;
  llvm::Function* libc__printf2;
  llvm::Function* runtime__HandleGC;
  llvm::Function* runtime__HandleAllocate;
  llvm::Function* runtime__HandleAllocateBoxed;
  llvm::Function* runtime__HandleInvokeSelector;
  llvm::Function* runtime__HandleObjectFromFailure;

  std::map<HeapObject*, llvm::Constant*> tagged_heap_objects;
  std::map<HeapObject*, llvm::Constant*> heap_objects;
  std::map<HeapObject*, llvm::Function*> llvm_functions;

  std::vector<llvm::Function*> natives_;
};

// ************ Utilities *******************

char *name(const char* format, ...);
char *bytecode_string(uint8* bcp);

}  // namespace dartino

#endif  // SRC_VM_CODEGEN_LLVM_H_
