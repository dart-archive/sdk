// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_NAMES_H_
#define SRC_SHARED_NAMES_H_

namespace fletch {

#define NAMES_LIST(N)                                   \
  N(Illegal, "<illegal>")                               \
  N(Object, "Object")                                   \
  N(Bool, "bool")                                       \
  N(Null, "Null")                                       \
  N(Double, "_DoubleImpl")                              \
  N(Int, "int")                                         \
  N(Smi, "_Smi")                                        \
  N(Mint, "_Mint")                                      \
  N(ConstantList, "_ConstantList")                      \
  N(ConstantByteList, "_ConstantByteList")              \
  N(ConstantMap, "_ConstantMap")                        \
  N(Num, "num")                                         \
  N(Coroutine, "Coroutine")                             \
  N(Port, "Port")                                       \
  N(Process, "Process")                                 \
  N(ProcessDeath, "ProcessDeath")                       \
  N(ForeignMemory, "ForeignMemory")                     \
  N(OneByteString, "_OneByteString")                    \
  N(TwoByteString, "_TwoByteString")                    \
  N(StackOverflowError, "StackOverflowError")           \
  N(FletchNoSuchMethodError, "FletchNoSuchMethodError") \
                                                        \
  N(Equals, "==")                                       \
  N(LessThan, "<")                                      \
  N(LessEqual, "<=")                                    \
  N(GreaterThan, ">")                                   \
  N(GreaterEqual, ">=")                                 \
                                                        \
  N(Add, "+")                                           \
  N(Sub, "-")                                           \
  N(Mod, "%")                                           \
  N(Mul, "*")                                           \
  N(TruncDiv, "~/")                                     \
                                                        \
  N(BitNot, "~")                                        \
  N(BitAnd, "&")                                        \
  N(BitOr, "|")                                         \
  N(BitXor, "^")                                        \
  N(BitShr, ">>")                                       \
  N(BitShl, "<<")                                       \
                                                        \
  N(IndexAssign, "[]=")                                 \
                                                        \
  N(NoSuchMethod, "_noSuchMethod")                      \
  N(NoSuchMethodTrampoline, "_noSuchMethodTrampoline")  \
  N(Yield, "_yield")                                    \
  N(CoroutineChange, "_coroutineChange")                \
  N(CoroutineStart, "_coroutineStart")                  \
  N(Call, "call")                                       \
  N(Identical, "identical")

class Names {
 public:
  enum Id {
#define N(n, s) k##n,
    NAMES_LIST(N)
#undef N
        kCount,
  };

  static bool IsBuiltinClassName(int id) {
    return id >= kObject && id <= kTwoByteString;
  }
};

}  // namespace fletch

#endif  // SRC_SHARED_NAMES_H_
