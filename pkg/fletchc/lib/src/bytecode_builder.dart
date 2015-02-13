// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.bytecode_builder;

import '../bytecodes.dart';

class BytecodeBuilder {
  final List<Bytecode> bytecodes = <Bytecode>[];

  int byteSize = 0;
  int stackSize = 0;

  void loadConst(int id) {
    internalAdd(new LoadConstUnfold(id));
  }

  void loadLiteralNull() {
    internalAdd(new LoadLiteralNull());
  }

  void invokeStatic(int id, int arguments) {
    internalAddStackPointerDifference(
        new InvokeStaticUnfold(id),
        1 - arguments);
  }

  void pop() {
    internalAdd(new Pop());
  }

  void ret() {
    if (stackSize <= 0) throw "Bad stackSize for return bytecode: $stackSize";
    // TODO(ajohnsen): Set correct argument count (second argument to Return).
    internalAdd(new Return(stackSize - 1, 0));
  }

  bool get endsWithTerminator {
    if (bytecodes.isEmpty) return false;
    Opcode opcode = bytecodes.last.opcode;
    return opcode == Opcode.Return || opcode == Opcode.Throw;
  }

  void methodEnd() {
    internalAdd(new MethodEnd(byteSize));
  }

  void internalAdd(Bytecode bytecode) {
    internalAddStackPointerDifference(
        bytecode,
        bytecode.stackPointerDifference);
  }

  void internalAddStackPointerDifference(
      Bytecode bytecode,
      int stackPointerDifference) {
    assert(stackPointerDifference != VAR_DIFF);
    bytecodes.add(bytecode);
    stackSize += stackPointerDifference;
    byteSize += bytecode.size;
  }
}
