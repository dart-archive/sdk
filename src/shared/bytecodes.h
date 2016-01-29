// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_BYTECODES_H_
#define SRC_SHARED_BYTECODES_H_

#include "src/shared/globals.h"

namespace fletch {

const int8 kVarDiff = 0x7f;
const int kLoadLiteralWideLimit = 0x3fffffff;

#define INVOKE(V, name, diff, desc, suffix, type) \
  V(Invoke##name##suffix, true, "I", 5, diff, "invoke " type desc "%d")

#define INVOKES_DO(V, suffix, type)                    \
  INVOKE(V, Method, kVarDiff, "method ", suffix, type) \
  INVOKE(V, Test, 0, "test ", suffix, type)            \
                                                       \
  INVOKE(V, Eq, -1, "eq ", suffix, type)               \
  INVOKE(V, Lt, -1, "lt ", suffix, type)               \
  INVOKE(V, Le, -1, "le ", suffix, type)               \
  INVOKE(V, Gt, -1, "gt ", suffix, type)               \
  INVOKE(V, Ge, -1, "ge ", suffix, type)               \
                                                       \
  INVOKE(V, Add, -1, "add ", suffix, type)             \
  INVOKE(V, Sub, -1, "sub ", suffix, type)             \
  INVOKE(V, Mod, -1, "mod ", suffix, type)             \
  INVOKE(V, Mul, -1, "mul ", suffix, type)             \
  INVOKE(V, TruncDiv, -1, "trunc div ", suffix, type)  \
                                                       \
  INVOKE(V, BitNot, 0, "bit not ", suffix, type)       \
  INVOKE(V, BitAnd, -1, "bit and ", suffix, type)      \
  INVOKE(V, BitOr, -1, "bit or ", suffix, type)        \
  INVOKE(V, BitXor, -1, "bit xor ", suffix, type)      \
  INVOKE(V, BitShr, -1, "bit shr ", suffix, type)      \
  INVOKE(V, BitShl, -1, "bit shl ", suffix, type)

#define BYTECODES_DO(V)                                                       \
  /* Name             Branching Format Size   SP-diff  format-string   */     \
  V(LoadLocal0, false, "", 1, 1, "load local 0")                              \
  V(LoadLocal1, false, "", 1, 1, "load local 1")                              \
  V(LoadLocal2, false, "", 1, 1, "load local 2")                              \
  V(LoadLocal3, false, "", 1, 1, "load local 3")                              \
  V(LoadLocal4, false, "", 1, 1, "load local 4")                              \
  V(LoadLocal5, false, "", 1, 1, "load local 5")                              \
  V(LoadLocal, false, "B", 2, 1, "load local %d")                             \
  V(LoadLocalWide, false, "I", 5, 1, "load local %d")                         \
                                                                              \
  V(LoadBoxed, false, "B", 2, 1, "load boxed %d")                             \
  V(LoadStatic, false, "I", 5, 1, "load static %d")                           \
  V(LoadStaticInit, false, "I", 5, 1, "load static init %d")                  \
  V(LoadField, false, "B", 2, 0, "load field %d")                             \
  V(LoadFieldWide, false, "I", 5, 0, "load field %d")                         \
                                                                              \
  V(StoreLocal, false, "B", 2, 0, "store local %d")                           \
  V(StoreBoxed, false, "B", 2, 0, "store boxed %d")                           \
  V(StoreStatic, false, "I", 5, 0, "store static %d")                         \
  V(StoreField, false, "B", 2, -1, "store field %d")                          \
  V(StoreFieldWide, false, "I", 5, -1, "store field %d")                      \
                                                                              \
  V(LoadLiteralNull, false, "", 1, 1, "load literal null")                    \
  V(LoadLiteralTrue, false, "", 1, 1, "load literal true")                    \
  V(LoadLiteralFalse, false, "", 1, 1, "load literal false")                  \
  V(LoadLiteral0, false, "", 1, 1, "load literal 0")                          \
  V(LoadLiteral1, false, "", 1, 1, "load literal 1")                          \
  V(LoadLiteral, false, "B", 2, 1, "load literal %d")                         \
  V(LoadLiteralWide, false, "I", 5, 1, "load literal %d")                     \
                                                                              \
  INVOKES_DO(V, , "")                                                         \
                                                                              \
  INVOKE(V, Static, kVarDiff, "static ", , "")                                \
  INVOKE(V, Factory, kVarDiff, "factory ", , "")                              \
  V(Allocate, false, "I", 5, kVarDiff, "allocate %d")                         \
  V(AllocateImmutable, false, "I", 5, kVarDiff, "allocateim %d")              \
                                                                              \
  V(InvokeNoSuchMethod, true, "I", 5, kVarDiff, "invoke no such method %d")   \
  V(InvokeTestNoSuchMethod, true, "I", 5, 0, "invoke test no such method %d") \
                                                                              \
  V(InvokeNative, true, "BB", 3, 1, "invoke native %d %d")                    \
  V(InvokeNativeYield, true, "BB", 3, 1, "invoke native yield %d %d")         \
                                                                              \
  V(InvokeSelector, true, "I", 5, kVarDiff, "invoke selector")                \
                                                                              \
  V(Pop, false, "", 1, -1, "pop")                                             \
  V(Drop, false, "B", 2, kVarDiff, "drop %d")                                 \
  V(Return, true, "", 1, -1, "return")                                        \
  V(ReturnNull, true, "", 1, 0, "return null")                                \
                                                                              \
  V(BranchWide, true, "I", 5, 0, "branch +%d")                                \
  V(BranchIfTrueWide, true, "I", 5, -1, "branch if true +%d")                 \
  V(BranchIfFalseWide, true, "I", 5, -1, "branch if false +%d")               \
                                                                              \
  V(BranchBack, true, "B", 2, 0, "branch -%d")                                \
  V(BranchBackIfTrue, true, "B", 2, -1, "branch if true -%d")                 \
  V(BranchBackIfFalse, true, "B", 2, -1, "branch if false -%d")               \
                                                                              \
  V(BranchBackWide, true, "I", 5, 0, "branch -%d")                            \
  V(BranchBackIfTrueWide, true, "I", 5, -1, "branch if true -%d")             \
  V(BranchBackIfFalseWide, true, "I", 5, -1, "branch if false -%d")           \
                                                                              \
  V(PopAndBranchWide, true, "BI", 6, 0, "pop %d and branch +%d")              \
  V(PopAndBranchBackWide, true, "BI", 6, 0, "pop %d and branch -%d")          \
                                                                              \
  V(AllocateBoxed, false, "", 1, 0, "allocate boxed")                         \
                                                                              \
  V(Negate, false, "", 1, 0, "negate")                                        \
                                                                              \
  V(StackOverflowCheck, true, "I", 5, 0, "stack overflow check %d")           \
                                                                              \
  V(Throw, true, "", 1, 0, "throw")                                           \
  V(SubroutineCall, true, "II", 9, kVarDiff, "subroutine call +%d -%d")       \
  V(SubroutineReturn, true, "", 1, -1, "subroutine return")                   \
                                                                              \
  V(ProcessYield, true, "", 1, 0, "process yield")                            \
  V(CoroutineChange, true, "", 1, -1, "coroutine change")                     \
                                                                              \
  V(Identical, true, "", 1, -1, "identical")                                  \
  V(IdenticalNonNumeric, true, "", 1, -1, "identical non numeric")            \
                                                                              \
  V(EnterNoSuchMethod, true, "B", 2, kVarDiff, "enter noSuchMethod +%d")      \
  V(ExitNoSuchMethod, true, "", 1, -1, "exit noSuchMethod")                   \
                                                                              \
  INVOKES_DO(V, Unfold, "unfold ")                                            \
  V(LoadConst, false, "I", 5, 1, "load const @%d")                            \
                                                                              \
  V(MethodEnd, false, "I", 5, 0, "method end %d")

#define BYTECODE_OPCODE(name, branching, format, length, stack_diff, print) \
  k##name,
enum Opcode { BYTECODES_DO(BYTECODE_OPCODE) };
#undef BYTECODE_OPCODE

#define BYTECODE_LENGTH(name, branching, format, length, stack_diff, print) \
  const int k##name##Length = length;
BYTECODES_DO(BYTECODE_LENGTH)
#undef BYTECODE_LENGTH

class Bytecode {
 public:
  static const int kNumBytecodes = kMethodEnd + 1;
  static const int kGuaranteedFrameSize = 32;
  static const int kUnfoldOffset = kInvokeMethodUnfold - kInvokeMethod;

  // Print bytecodes on stdout.
  static uint8 Print(uint8* bcp);

  // Get the size of the opcode.
  static uint8 Size(Opcode opcode);

  // Get the stack diff of the opcode. If the opcode is variable, kVarDiff is
  // returned.
  static int8 StackDiff(Opcode opcode);

  // Get the print format of the opcode.
  static const char* PrintFormat(Opcode opcode);

  // Get the bytecode format of the opcode.
  static const char* BytecodeFormat(Opcode opcode);

  // Check if this byte code is an invoke variant.
  static bool IsInvokeVariant(Opcode opcode);

  // Check for invoke variants.
  static bool IsInvokeUnfold(Opcode opcode);
  static bool IsInvoke(Opcode opcode);
  static bool IsStaticInvoke(Opcode opcode);

  // Compute the previous bytecode. Takes time linear in the number of
  // bytecodes in the method.
  static uint8* PreviousBytecode(uint8* current_bcp);
};

}  // namespace fletch

#endif  // SRC_SHARED_BYTECODES_H_
