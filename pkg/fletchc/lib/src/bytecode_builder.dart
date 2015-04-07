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
  final List<int> catchRanges = <int>[];

  final int functionArity;

  int byteSize = 0;
  int stackSize = 0;

  BytecodeBuilder(this.functionArity);

  /**
   * Apply a fix to the currently known stack size.
   */
  void applyStackSizeFix(int diff) {
    stackSize += diff;
  }

  void addCatchFrameRange(int start, int end) {
    catchRanges
        ..add(start)
        ..add(end);
  }

  void loadConst(int id) {
    internalAdd(new LoadConstUnfold(id));
  }

  void loadLocal(int offset) {
    assert(offset >= 0);
    Bytecode bytecode;
    switch (offset) {
      case 0:
        bytecode = const LoadLocal0();
        break;
      case 1:
        bytecode = const LoadLocal1();
        break;
      case 2:
        bytecode = const LoadLocal2();
        break;
      default:
        bytecode = new LoadLocal(offset);
        break;
    }
    internalAdd(bytecode);
  }

  void loadBoxed(int offset) {
    assert(offset >= 0);
    internalAdd(new LoadBoxed(offset));
  }

  void dup() {
    loadLocal(0);
  }

  /**
   * A 'slot' is an artificial indexing, that are frame relative. That means
   * the current frame is indexed by where 0 .. frameSize-1, -1 is the return
   * address and -1 - functionArity is the first argument, -2 is the last
   * argument.
   *
   * This kind of indexing are sometimes easier to use than stack-relative,
   * as locals and parameters have a fixed value.
   */
  void loadSlot(int slot) {
    int offset = stackSize - slot - 1;
    loadLocal(offset);
  }

  void loadBoxedSlot(int slot) {
    int offset = stackSize - slot - 1;
    loadBoxed(offset);
  }

  void loadParameter(int parameter) {
    assert(parameter >= 0 && parameter < functionArity);
    int offset = stackSize + functionArity - parameter;
    loadLocal(offset);
  }

  void loadStatic(int index) {
    internalAdd(new LoadStatic(index));
  }

  void loadStaticInit(int index) {
    internalAdd(new LoadStaticInit(index));
  }

  void loadField(int index) {
    internalAdd(new LoadField(index));
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

  void loadLiteral(int value) {
    if (value == 0) {
      internalAdd(const LoadLiteral0());
    } else if (value == 1) {
      internalAdd(const LoadLiteral1());
    } else if (value < 256) {
      internalAdd(new LoadLiteral(value));
    } else {
      internalAdd(new LoadLiteralWide(value));
    }
  }

  void storeLocal(int offset) {
    assert(offset >= 0);
    internalAdd(new StoreLocal(offset));
  }

  void storeBoxed(int offset) {
    assert(offset >= 0);
    internalAdd(new StoreBoxed(offset));
  }

  /**
   * See loadSlot for information about 'slots'.
   */
  void storeSlot(int slot) {
    int offset = stackSize - slot - 1;
    storeLocal(offset);
  }

  void storeBoxedSlot(int slot) {
    int offset = stackSize - slot - 1;
    storeBoxed(offset);
  }

  void storeStatic(int index) {
    internalAdd(new StoreStatic(index));
  }

  void storeField(int index) {
    internalAdd(new StoreField(index));
  }

  void invokeStatic(int id, int arity) {
    internalAddStackPointerDifference(
        new InvokeStaticUnfold(id),
        1 - arity);
  }

  void invokeFactory(int id, int arity) {
    internalAddStackPointerDifference(
        new InvokeFactoryUnfold(id),
        1 - arity);
  }

  void invokeMethod(int selector, int arity, [String name]) {
    switch (name) {
      case '==':
        internalAddStackPointerDifference(new InvokeEq(selector), -arity);
        break;

      case '<':
        internalAddStackPointerDifference(new InvokeLt(selector), -arity);
        break;

      case '<=':
        internalAddStackPointerDifference(new InvokeLe(selector), -arity);
        break;

      case '>':
        internalAddStackPointerDifference(new InvokeGt(selector), -arity);
        break;

      case '>=':
        internalAddStackPointerDifference(new InvokeGe(selector), -arity);
        break;

      case '+':
        internalAddStackPointerDifference(new InvokeAdd(selector), -arity);
        break;

      case '-':
        internalAddStackPointerDifference(new InvokeSub(selector), -arity);
        break;

      case '*':
        internalAddStackPointerDifference(new InvokeMul(selector), -arity);
        break;

      case '~/':
        internalAddStackPointerDifference(new InvokeTruncDiv(selector), -arity);
        break;

      case '%':
        internalAddStackPointerDifference(new InvokeMod(selector), -arity);
        break;

      case '~':
        internalAddStackPointerDifference(new InvokeBitNot(selector), -arity);
        break;

      case '&':
        internalAddStackPointerDifference(new InvokeBitAnd(selector), -arity);
        break;

      case '|':
        internalAddStackPointerDifference(new InvokeBitOr(selector), -arity);
        break;

      case '^':
        internalAddStackPointerDifference(new InvokeBitXor(selector), -arity);
        break;

      case '<<':
        internalAddStackPointerDifference(new InvokeBitShl(selector), -arity);
        break;

      case '>>':
        internalAddStackPointerDifference(new InvokeBitShr(selector), -arity);
        break;

      default:
        internalAddStackPointerDifference(new InvokeMethod(selector), -arity);
        break;
    }
  }

  void invokeTest(int selector, int arity) {
    internalAddStackPointerDifference(new InvokeTest(selector), -arity);
  }

  void pop() {
    internalAdd(new Pop());
  }

  void popMany(int count) {
    // TODO(ajohnsen): Create bytecode for this.
    for (int i = 0; i < count; i++) {
      internalAdd(new Pop());
    }
  }

  void ret() {
    if (stackSize <= 0) throw "Bad stackSize for return bytecode: $stackSize";
    internalAdd(new Return(stackSize, functionArity));
  }

  void identical() {
    internalAdd(const Identical());
  }

  void identicalNonNumeric() {
    internalAdd(const IdenticalNonNumeric());
  }

  void negate() {
    internalAdd(const Negate());
  }

  void bind(BytecodeLabel label) {
    internalBind(label, false);
  }

  void internalBind(BytecodeLabel label, bool isSubroutineReturn) {
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

        case Opcode.BranchIfFalseLong:
          int offset = position - bytecode.uint32Argument0;
          bytecodes[index] = new BranchIfFalseLong(offset);
          break;

        case Opcode.BranchLong:
          int offset = position - bytecode.uint32Argument0;
          bytecodes[index] = new BranchLong(offset);
          break;

        case Opcode.PopAndBranchLong:
          int offset = position - bytecode.uint32Argument1;
          bytecodes[index] = new PopAndBranchLong(
              bytecode.uint8Argument0,
              offset);
          break;

        case Opcode.SubroutineCall:
          if (isSubroutineReturn) {
            int offset = position - bytecode.uint32Argument1;
            offset -= bytecode.size;
            bytecodes[index] = new SubroutineCall(
                bytecode.uint32Argument0,
                offset);
          } else {
            int offset = position - bytecode.uint32Argument0;
            bytecodes[index] = new SubroutineCall(
                offset,
                bytecode.uint32Argument1);
          }
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

  void branchIfFalse(BytecodeLabel label) {
    if (label.isBound) {
      internalBranchBack(
          label,
          (v) => new BranchBackIfFalse(v),
          (v) => new BranchBackIfFalseLong(v));
    } else {
      label.addUsage(bytecodes.length);
      internalAdd(new BranchIfFalseLong(byteSize));
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

  void popAndBranch(int diff, BytecodeLabel label) {
    if (label.isBound) {
      internalBranchBack(
          label,
          (v) => new PopAndBranchBackLong(diff, v),
          (v) => new PopAndBranchBackLong(diff, v));
    } else {
      label.addUsage(bytecodes.length);
      internalAdd(new PopAndBranchLong(diff, byteSize));
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

  void allocate(int classId, int fields) {
    internalAddStackPointerDifference(new AllocateUnfold(classId), 1 - fields);
  }

  void allocateBoxed() {
    internalAdd(const AllocateBoxed());
  }

  void subroutineCall(BytecodeLabel label, BytecodeLabel returnLabel) {
    assert(!label.isBound);
    assert(!returnLabel.isBound);
    label.addUsage(bytecodes.length);
    returnLabel.addUsage(bytecodes.length);
    internalAddStackPointerDifference(
        new SubroutineCall(byteSize, byteSize),
        0);
  }

  void subroutineReturn(BytecodeLabel returnLabel) {
    internalBind(returnLabel, true);
    internalAdd(const SubroutineReturn());
  }

  bool get endsWithTerminator {
    if (bytecodes.isEmpty) return false;
    Opcode opcode = bytecodes.last.opcode;
    return opcode == Opcode.Return || opcode == Opcode.Throw;
  }

  void enterNoSuchMethod() {
    internalAdd(const EnterNoSuchMethod());
  }

  void exitNoSuchMethod() {
    internalAdd(const ExitNoSuchMethod());
  }

  void methodEnd() {
    internalAdd(new MethodEnd(byteSize));
  }

  void processYield() {
    internalAdd(const ProcessYield());
  }

  void coroutineChange() {
    internalAdd(const CoroutineChange());
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

  void invokeNativeYield(int arity, int index) {
    internalAdd(new InvokeNativeYield(arity, index));
  }

  void emitThrow() {
    internalAdd(const Throw());
  }
}
