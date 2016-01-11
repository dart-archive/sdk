// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.bytecode_assembler;

import '../bytecodes.dart';

const int IMPLICIT_STACK_OVERFLOW_LIMIT = 32;
const int frameDescriptorSize = 3;

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

  bool get isUsed => usage.isNotEmpty;
}

class BytecodeAssembler {
  final List<Bytecode> bytecodes = <Bytecode>[];
  final List<int> catchRanges = <int>[];

  final int functionArity;

  int byteSize = 0;
  int stackSize = 0;
  int maxStackSize = 0;

  // A bind after a terminator will still look like the last bytecode
  // is a terminator, however, due to the bind it's not.
  bool hasBindAfterTerminator = false;

  // A bind after a pop will still look like the last bytecode is a
  // pop, however, due to the bind we cannot collapse more pops
  // together.
  bool hasBindAfterPop = false;

  BytecodeAssembler(this.functionArity);

  void reuse() {
    bytecodes.clear();
    catchRanges.clear();
    byteSize = 0;
    stackSize = 0;
    maxStackSize = 0;
  }

  /**
   * Apply a fix to the currently known stack size.
   */
  void applyStackSizeFix(int diff) {
    stackSize += diff;
    if (stackSize > maxStackSize) maxStackSize = stackSize;
  }

  void addCatchFrameRange(int start, int end) {
    catchRanges
        ..add(start)
        ..add(end)
        ..add(stackSize);
  }

  void loadConst(int id) {
    internalAdd(new LoadConst(id));
  }

  void loadLocal(int offset) {
    assert(offset < stackSize);
    loadLocalHelper(offset);
  }

  void loadLocalHelper(int offset) {
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
      case 3:
        bytecode = const LoadLocal3();
        break;
      case 4:
        bytecode = const LoadLocal4();
        break;
      case 5:
        bytecode = const LoadLocal5();
        break;
      default:
        if (offset >= 256) {
          bytecode = new LoadLocalWide(offset);
        } else {
          bytecode = new LoadLocal(offset);
        }
        break;
    }
    internalAdd(bytecode);
  }

  void loadBoxed(int offset) {
    assert(offset < stackSize);
    loadBoxedHelper(offset);
  }

  void loadBoxedHelper(int offset) {
    assert(offset >= 0 && offset <= 255);
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

  int computeParameterOffset(int parameter) {
    return frameDescriptorSize + stackSize + functionArity - parameter - 1;
  }

  void loadParameter(int parameter) {
    assert(parameter >= 0 && parameter < functionArity);
    loadLocalHelper(computeParameterOffset(parameter));
  }

  void loadBoxedParameter(int parameter) {
    assert(parameter >= 0 && parameter < functionArity);
    loadBoxedHelper(computeParameterOffset(parameter));
  }

  void loadStatic(int index) {
    internalAdd(new LoadStatic(index));
  }

  void loadStaticInit(int index) {
    internalAdd(new LoadStaticInit(index));
  }

  void loadField(int index) {
    if (index >= 256) {
      internalAdd(new LoadFieldWide(index));
    } else {
      internalAdd(new LoadField(index));
    }
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
    assert(offset < stackSize);
    storeLocalHelper(offset);
  }

  void storeLocalHelper(int offset) {
    assert(offset >= 0 && offset <= 255);
    internalAdd(new StoreLocal(offset));
  }

  void storeBoxed(int offset) {
    assert(offset < stackSize);
    storeBoxedHelper(offset);
  }

  void storeBoxedHelper(int offset) {
    assert(offset >= 0 && offset <= 255);
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

  void storeParameter(int parameter) {
    assert(parameter >= 0 && parameter < functionArity);
    storeLocalHelper(computeParameterOffset(parameter));
  }

  void storeBoxedParameter(int parameter) {
    assert(parameter >= 0 && parameter < functionArity);
    storeBoxedHelper(computeParameterOffset(parameter));
  }

  void storeStatic(int index) {
    internalAdd(new StoreStatic(index));
  }

  void storeField(int index) {
    if (index >= 256) {
      internalAdd(new StoreFieldWide(index));
    } else {
      internalAdd(new StoreField(index));
    }
  }

  void invokeStatic(int id, int arity) {
    internalAddStackPointerDifference(
        new InvokeStatic(id),
        1 - arity);
  }

  void invokeFactory(int id, int arity) {
    internalAddStackPointerDifference(
        new InvokeFactory(id),
        1 - arity);
  }

  void invokeMethod(int selector, int arity, [String name]) {
    var bytecode;
    switch (name) {
      case '==':
        bytecode = new InvokeEqUnfold(selector);
        break;

      case '<':
        bytecode = new InvokeLtUnfold(selector);
        break;

      case '<=':
        bytecode = new InvokeLeUnfold(selector);
        break;

      case '>':
        bytecode = new InvokeGtUnfold(selector);
        break;

      case '>=':
        bytecode = new InvokeGeUnfold(selector);
        break;

      case '+':
        bytecode = new InvokeAddUnfold(selector);
        break;

      case '-':
        bytecode = new InvokeSubUnfold(selector);
        break;

      case '*':
        bytecode = new InvokeMulUnfold(selector);
        break;

      case '~/':
        bytecode = new InvokeTruncDivUnfold(selector);
        break;

      case '%':
        bytecode = new InvokeModUnfold(selector);
        break;

      case '~':
        bytecode = new InvokeBitNotUnfold(selector);
        break;

      case '&':
        bytecode = new InvokeBitAndUnfold(selector);
        break;

      case '|':
        bytecode = new InvokeBitOrUnfold(selector);
        break;

      case '^':
        bytecode = new InvokeBitXorUnfold(selector);
        break;

      case '<<':
        bytecode = new InvokeBitShlUnfold(selector);
        break;

      case '>>':
        bytecode = new InvokeBitShrUnfold(selector);
        break;

      default:
        bytecode = new InvokeMethodUnfold(selector);
        break;
    }
    internalAddStackPointerDifference(bytecode, -arity);
  }

  void invokeTest(int selector, int arity) {
    internalAddStackPointerDifference(new InvokeTestUnfold(selector), -arity);
  }

  void invokeSelector() {
    internalAddStackPointerDifference(const InvokeSelector(0), 0);
  }

  void pop() {
    if (hasBindAfterPop) {
      internalAdd(new Pop());
      hasBindAfterPop = false;
      return;
    }
    Bytecode last = bytecodes.last;
    if (last.opcode == Opcode.Drop) {
      Drop drop = last;
      int amount = drop.uint8Argument0 + 1;
      if (amount <= 255) {
        bytecodes[bytecodes.length - 1] = new Drop(amount);
        applyStackSizeFix(-1);
      } else {
        internalAdd(new Pop());
      }
    } else if (last.opcode == Opcode.Pop) {
      bytecodes[bytecodes.length - 1] = new Drop(2);
      byteSize += 1;
      applyStackSizeFix(-1);
    } else {
      internalAdd(new Pop());
    }

  }

  void popMany(int count) {
    while (count > 255) {
      internalAddStackPointerDifference(new Drop(255), -255);
      count -= 255;
    }
    if (count > 1) {
      internalAddStackPointerDifference(new Drop(count), -count);
    } else if (count == 1) {
      internalAdd(new Pop());
    }
    hasBindAfterPop = false;
  }

  void ret() {
    hasBindAfterTerminator = false;
    if (stackSize <= 0) throw "Bad stackSize for return bytecode: $stackSize";
    assert(functionArity <= 255);
    internalAdd(new Return(functionArity));
  }

  void returnNull() {
    hasBindAfterTerminator = false;
    assert(functionArity <= 255);
    internalAdd(new ReturnNull(functionArity));
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
    if (label.isUsed) hasBindAfterTerminator = true;
    hasBindAfterPop = true;
    assert(label.position == -1);
    // TODO(ajohnsen): If the previous bytecode is a branch to this label,
    // consider popping it - if no other binds has happened at this bytecode
    // index.
    int position = byteSize;
    label.forEach((int index) {
      var bytecode = bytecodes[index];
      switch (bytecode.opcode) {
        case Opcode.BranchIfTrueWide:
          int offset = position - bytecode.uint32Argument0;
          bytecodes[index] = new BranchIfTrueWide(offset);
          break;

        case Opcode.BranchIfFalseWide:
          int offset = position - bytecode.uint32Argument0;
          bytecodes[index] = new BranchIfFalseWide(offset);
          break;

        case Opcode.BranchWide:
          int offset = position - bytecode.uint32Argument0;
          bytecodes[index] = new BranchWide(offset);
          break;

        case Opcode.PopAndBranchWide:
          int offset = position - bytecode.uint32Argument1;
          bytecodes[index] = new PopAndBranchWide(
              bytecode.uint8Argument0,
              offset);
          break;

        case Opcode.EnterNoSuchMethod:
          int offset = position - bytecode.uint8Argument0;
          bytecodes[index] = new EnterNoSuchMethod(offset);
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
          (v) => new BranchBackIfTrueWide(v));
    } else {
      label.addUsage(bytecodes.length);
      internalAdd(new BranchIfTrueWide(byteSize));
    }
  }

  void branchIfFalse(BytecodeLabel label) {
    if (label.isBound) {
      internalBranchBack(
          label,
          (v) => new BranchBackIfFalse(v),
          (v) => new BranchBackIfFalseWide(v));
    } else {
      label.addUsage(bytecodes.length);
      internalAdd(new BranchIfFalseWide(byteSize));
    }
  }

  void branch(BytecodeLabel label) {
    if (label.isBound) {
      internalBranchBack(
          label,
          (v) => new BranchBack(v),
          (v) => new BranchBackWide(v));
    } else {
      label.addUsage(bytecodes.length);
      internalAdd(new BranchWide(byteSize));
    }
  }

  void popAndBranch(int diff, BytecodeLabel label) {
    assert(diff >= 0 && diff <= 255);
    if (label.isBound) {
      internalBranchBack(
          label,
          (v) => new PopAndBranchBackWide(diff, v),
          (v) => new PopAndBranchBackWide(diff, v));
    } else {
      label.addUsage(bytecodes.length);
      internalAdd(new PopAndBranchWide(diff, byteSize));
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

  void allocate(int classId, int fields, {bool immutable: false}) {
    var instruction = immutable ?
        new AllocateImmutable(classId) : new Allocate(classId);
    internalAddStackPointerDifference(instruction, 1 - fields);
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
    if (hasBindAfterTerminator) return false;
    Opcode opcode = bytecodes.last.opcode;
    return opcode == Opcode.Return || opcode == Opcode.Throw;
  }

  void enterNoSuchMethod(BytecodeLabel skipGetterLabel) {
    assert(!skipGetterLabel.isBound);
    skipGetterLabel.addUsage(bytecodes.length);
    internalAddStackPointerDifference(new EnterNoSuchMethod(byteSize), 0);
  }

  void exitNoSuchMethod() {
    internalAdd(const ExitNoSuchMethod());
  }

  void methodEnd() {
    if (maxStackSize > IMPLICIT_STACK_OVERFLOW_LIMIT) {
      var bytecode = new StackOverflowCheck(
          maxStackSize - IMPLICIT_STACK_OVERFLOW_LIMIT);
      bytecodes.insert(0, bytecode);
      byteSize += bytecode.size;
    }
    int value = (byteSize << 1) | (catchRanges.isNotEmpty ? 1 : 0);
    internalAdd(new MethodEnd(value));
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
    assert(bytecodes.isEmpty || bytecodes.last.opcode != Opcode.MethodEnd);
    bytecodes.add(bytecode);
    byteSize += bytecode.size;
    applyStackSizeFix(stackPointerDifference);
  }

  void invokeNative(int arity, int index) {
    internalAdd(new InvokeNative(arity, index));
  }

  void invokeNativeYield(int arity, int index) {
    internalAdd(new InvokeNativeYield(arity, index));
  }

  void emitThrow() {
    hasBindAfterTerminator = false;
    internalAdd(const Throw());
  }
}
