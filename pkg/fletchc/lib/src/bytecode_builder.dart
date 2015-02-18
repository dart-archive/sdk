// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.bytecode_builder;

import '../bytecodes.dart';

class BytecodeLabel {
  int position = -1;
  final List<int> usage = <int>[];

  void addUsage(int bytecodePosition) {
    usage.add(bytecodePosition);
  }

  void forEach(f(int index)) {
    usage.forEach(f);
  }

  int get lastIndex {
    if (usage.isEmpty) return -1;
    return usage.last;
  }

  void removeLastUsage() {
    usage.removeLast();
  }

  void bind(int value) {
    position = value;
    usage.clear();
  }

  bool get isBound => position != -1;
}

class BytecodeBuilder {
  final List<Bytecode> bytecodes = <Bytecode>[];

  final int functionArity;

  int byteSize = 0;
  int stackSize = 0;

  BytecodeBuilder(this.functionArity);

  void loadConst(int id) {
    internalAdd(new LoadConstUnfold(id));
  }

  void loadLocal(int offset) {
    assert(offset >= 0);
    internalAdd(new LoadLocal(offset));
  }

  void loadSlot(int slot) {
    int offset = stackSize - slot - 1;
    loadLocal(offset);
  }

  void loadStatic(int index) {
    internalAdd(new LoadStatic(index));
  }

  void loadLiteralNull() {
    internalAdd(new LoadLiteralNull());
  }

  void loadLiteralTrue() {
    internalAdd(new LoadLiteralTrue());
  }

  void loadLiteralFalse() {
    internalAdd(new LoadLiteralFalse());
  }

  void storeLocal(int offset) {
    assert(offset >= 0);
    internalAdd(new StoreLocal(offset));
  }

  void storeSlot(int slot) {
    int offset = stackSize - slot - 1;
    storeLocal(offset);
  }

  void storeStatic(int index) {
    internalAdd(new StoreStatic(index));
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
    internalAdd(new Return(stackSize - 1, functionArity));
  }

  void bind(BytecodeLabel label) {
    assert(label.position == -1);
    // TODO(ajohnsen): If the previous bytecode is a branch to this label,
    // consider popping it - if no other binds has happened at this bytecode
    // index.
    int position = byteSize;
    label.forEach((int index) {
      var bytecode = bytecodes[index];
      switch (bytecode.opcode) {
        case Opcode.BranchIfTrueLong:
          int offset = position - bytecode.uint32Argument0;
          bytecodes[index] = new BranchIfTrueLong(offset);
          break;

        case Opcode.BranchLong:
          int offset = position - bytecode.uint32Argument0;
          bytecodes[index] = new BranchLong(offset);
          break;

        default:
          throw "Unhandled bind bytecode: $bytecode";
      }
    });
    label.bind(position);
  }

  void branchIfTrue(BytecodeLabel label) {
    if (label.isBound) {
      internalBranchBack(
          label,
          (v) => new BranchBackIfTrue(v),
          (v) => new BranchBackIfTrueLong(v));
    } else {
      label.addUsage(bytecodes.length);
      internalAdd(new BranchIfTrueLong(byteSize));
    }
  }

  void branch(BytecodeLabel label) {
    if (label.isBound) {
      internalBranchBack(
          label,
          (v) => new BranchBack(v),
          (v) => new BranchBackLong(v));
    } else {
      label.addUsage(bytecodes.length);
      internalAdd(new BranchLong(byteSize));
    }
  }

  void internalBranchBack(
      BytecodeLabel label,
      Bytecode short(int offset),
      Bytecode long(int offset)) {
    int offset = byteSize - label.position;
    if (offset < 255) {
      internalAdd(short(offset));
    } else {
      internalAdd(long(offset));
    }
  }

  bool get endsWithTerminator {
    if (bytecodes.isEmpty) return false;
    Opcode opcode = bytecodes.last.opcode;
    return opcode == Opcode.Return || opcode == Opcode.Throw;
  }

  void methodEnd() {
    internalAdd(new MethodEnd(byteSize));
  }

  void processYield() {
    internalAdd(new ProcessYield());
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

  void invokeNative(int arity, int index) {
    internalAdd(new InvokeNative(arity, index));
  }

  void emitThrow() {
    internalAdd(const Throw());
  }
}
