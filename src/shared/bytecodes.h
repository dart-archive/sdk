// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_BYTECODES_H_
#define SRC_SHARED_BYTECODES_H_

#include "src/shared/globals.h"

namespace fletch {

const int kVarDiff = 0x7FFFFFFF;
const int kLoadLiteralWideLimit = 0x3fffffff;

#define BYTECODES_DO(V)                                                      \
  /* Name              Format Size   SP-diff  format-string               */ \
  V(LoadLocal0,            "",   1,        1, "load local 0")                \
  V(LoadLocal1,            "",   1,        1, "load local 1")                \
  V(LoadLocal2,            "",   1,        1, "load local 2")                \
  V(LoadLocal,             "B",  2,        1, "load local %d")               \
                                                                             \
  V(LoadBoxed,             "B",  2,        1, "load boxed %d")               \
  V(LoadStatic,            "I",  5,        1, "load static %d")              \
  V(LoadStaticInit,        "I",  5,        1, "load static init %d")         \
  V(LoadField,             "B",  2,        0, "load field %d")               \
                                                                             \
  V(LoadConst,             "I",  5,        1, "load const %d")               \
  V(LoadConstUnfold,       "I",  5,        1, "load const @%d")              \
                                                                             \
  V(StoreLocal,            "B",  2,        0, "store local %d")              \
  V(StoreBoxed,            "B",  2,        0, "store boxed %d")              \
  V(StoreStatic,           "I",  5,        0, "store static %d")             \
  V(StoreField,            "B",  2,       -1, "store field %d")              \
                                                                             \
  V(LoadLiteralNull,       "",   1,        1, "load literal null")           \
  V(LoadLiteralTrue,       "",   1,        1, "load literal true")           \
  V(LoadLiteralFalse,      "",   1,        1, "load literal false")          \
  V(LoadLiteral0,          "",   1,        1, "load literal 0")              \
  V(LoadLiteral1,          "",   1,        1, "load literal 1")              \
  V(LoadLiteral,           "B",  2,        1, "load literal %d")             \
  V(LoadLiteralWide,       "I",  5,        1, "load literal %d")             \
                                                                             \
  V(InvokeMethod,          "I",  5, kVarDiff, "invoke %d")                   \
  V(InvokeMethodFast,      "I",  5, kVarDiff, "invoke fast %d")              \
  V(InvokeMethodVtable,    "I",  5, kVarDiff, "invoke vtable %d")            \
                                                                             \
  V(InvokeStatic,          "I",  5, kVarDiff, "invoke static %d")            \
  V(InvokeStaticUnfold,    "I",  5, kVarDiff, "invoke static @%d")           \
  V(InvokeFactory,         "I",  5, kVarDiff, "invoke factory %d")           \
  V(InvokeFactoryUnfold,   "I",  5, kVarDiff, "invoke factory @%d")          \
                                                                             \
  V(InvokeNative,          "BB", 3,        1, "invoke native %d %d")         \
  V(InvokeNativeYield,     "BB", 3,        1, "invoke native yield %d %d")   \
                                                                             \
  V(InvokeTest,            "I",  5,        0, "invoke test %d")              \
                                                                             \
  V(InvokeEq,              "I",  5,       -1, "invoke eq")                   \
  V(InvokeLt,              "I",  5,       -1, "invoke lt")                   \
  V(InvokeLe,              "I",  5,       -1, "invoke le")                   \
  V(InvokeGt,              "I",  5,       -1, "invoke gt")                   \
  V(InvokeGe,              "I",  5,       -1, "invoke ge")                   \
                                                                             \
  V(InvokeAdd,             "I",  5,       -1, "invoke add")                  \
  V(InvokeSub,             "I",  5,       -1, "invoke sub")                  \
  V(InvokeMod,             "I",  5,       -1, "invoke mod")                  \
  V(InvokeMul,             "I",  5,       -1, "invoke mul")                  \
  V(InvokeTruncDiv,        "I",  5,       -1, "invoke trunc div")            \
                                                                             \
  V(InvokeBitNot,          "I",  5,        0, "invoke bit not")              \
  V(InvokeBitAnd,          "I",  5,       -1, "invoke bit and")              \
  V(InvokeBitOr,           "I",  5,       -1, "invoke bit or")               \
  V(InvokeBitXor,          "I",  5,       -1, "invoke bit xor")              \
  V(InvokeBitShr,          "I",  5,       -1, "invoke bit shr")              \
  V(InvokeBitShl,          "I",  5,       -1, "invoke bit shl")              \
                                                                             \
  V(Pop,                   "",   1,       -1, "pop")                         \
  V(Return,                "BB", 3,       -1, "return %d %d")                \
                                                                             \
  V(BranchLong,            "I",  5,        0, "branch +%d")                  \
  V(BranchIfTrueLong,      "I",  5,       -1, "branch if true +%d")          \
  V(BranchIfFalseLong,     "I",  5,       -1, "branch if false +%d")         \
                                                                             \
  V(BranchBack,            "B",  2,        0, "branch -%d")                  \
  V(BranchBackIfTrue,      "B",  2,       -1, "branch if true -%d")          \
  V(BranchBackIfFalse,     "B",  2,       -1, "branch if false -%d")         \
                                                                             \
  V(BranchBackLong,        "I",  5,        0, "branch -%d")                  \
  V(BranchBackIfTrueLong,  "I",  5,       -1, "branch if true -%d")          \
  V(BranchBackIfFalseLong, "I",  5,       -1, "branch if false -%d")         \
                                                                             \
  V(Allocate,              "I",  5, kVarDiff, "allocate %d")                 \
  V(AllocateUnfold,        "I",  5, kVarDiff, "allocate @%d")                \
  V(AllocateBoxed,         "",   1,        0, "allocate boxed")              \
                                                                             \
  V(Negate,                "",   1,        0, "negate")                      \
                                                                             \
  V(StackOverflowCheck,    "",   5,        0, "stack overflow check")        \
                                                                             \
  V(Throw,                 "",   1,        0, "throw")                       \
  V(SubroutineCall,        "II", 9, kVarDiff, "subroutine call +%d -%d")     \
  V(SubroutineReturn,      "",   1,       -1, "subroutine return")           \
                                                                             \
  V(ProcessYield,          "",   1,        0, "process yield")               \
  V(CoroutineChange,       "",   1,       -1, "coroutine change")            \
                                                                             \
  V(Identical,             "",   1,       -1, "identical")                   \
  V(IdenticalNonNumeric,   "",   1,       -1, "identical non numeric")       \
                                                                             \
  V(EnterNoSuchMethod,     "",   1,        3, "enter noSuchMethod")          \
  V(ExitNoSuchMethod,      "",   1,       -1, "exit noSuchMethod")           \
                                                                             \
  V(FrameSize,             "B",  2, kVarDiff, "frame size %d")               \
                                                                             \
  V(MethodEnd,             "I",  5,        0, "method end %d")               \

#define BYTECODE_OPCODE(name, format, length, stack_diff, print) k##name,
enum Opcode {
  BYTECODES_DO(BYTECODE_OPCODE)
};
#undef BYTECODE_OPCODE

#define BYTECODE_LENGTH(name, format, length, stack_diff, print) \
  const int k##name##Length = length;
BYTECODES_DO(BYTECODE_LENGTH)
#undef BYTECODE_LENGTH

class Bytecode {
 public:
  static const int kNumBytecodes = kMethodEnd + 1;
  static const int kGuaranteedFrameSize = 32;

  class Writer {
   public:
    virtual ~Writer() {}
    virtual void Write(const char* format, ...) = 0;
  };

  // If writer isn't given, the bytecode is printed on stdout.
  static int Print(uint8* bcp, Writer* writer = NULL);

  // Get the size of the opcode.
  static int Size(Opcode opcode);

  // Get the stack diff of the opcode. If the opcode is variable, kVarDiff is
  // returned.
  static int StackDiff(Opcode opcode);

  // Get the print format of the opcode.
  static const char* PrintFormat(Opcode opcode);

  // Get the bytecode format of the opcode.
  static const char* BytecodeFormat(Opcode opcode);

 private:
  static int sizes_[];
  static int stack_diffs_[];
};

}  // namespace fletch

#endif  // SRC_SHARED_BYTECODES_H_
