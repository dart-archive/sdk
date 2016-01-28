// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// WARNING: Generated file, do not edit!

part of fletch.bytecodes;

enum Opcode {
  LoadLocal0,
  LoadLocal1,
  LoadLocal2,
  LoadLocal3,
  LoadLocal4,
  LoadLocal5,
  LoadLocal,
  LoadLocalWide,
  LoadBoxed,
  LoadStatic,
  LoadStaticInit,
  LoadField,
  LoadFieldWide,
  StoreLocal,
  StoreBoxed,
  StoreStatic,
  StoreField,
  StoreFieldWide,
  LoadLiteralNull,
  LoadLiteralTrue,
  LoadLiteralFalse,
  LoadLiteral0,
  LoadLiteral1,
  LoadLiteral,
  LoadLiteralWide,
  InvokeMethod,
  InvokeTest,
  InvokeEq,
  InvokeLt,
  InvokeLe,
  InvokeGt,
  InvokeGe,
  InvokeAdd,
  InvokeSub,
  InvokeMod,
  InvokeMul,
  InvokeTruncDiv,
  InvokeBitNot,
  InvokeBitAnd,
  InvokeBitOr,
  InvokeBitXor,
  InvokeBitShr,
  InvokeBitShl,
  InvokeStatic,
  InvokeFactory,
  Allocate,
  AllocateImmutable,
  InvokeNoSuchMethod,
  InvokeTestNoSuchMethod,
  InvokeNative,
  InvokeNativeYield,
  InvokeSelector,
  Pop,
  Drop,
  Return,
  ReturnNull,
  BranchWide,
  BranchIfTrueWide,
  BranchIfFalseWide,
  BranchBack,
  BranchBackIfTrue,
  BranchBackIfFalse,
  BranchBackWide,
  BranchBackIfTrueWide,
  BranchBackIfFalseWide,
  PopAndBranchWide,
  PopAndBranchBackWide,
  AllocateBoxed,
  Negate,
  StackOverflowCheck,
  Throw,
  SubroutineCall,
  SubroutineReturn,
  ProcessYield,
  CoroutineChange,
  Identical,
  IdenticalNonNumeric,
  EnterNoSuchMethod,
  ExitNoSuchMethod,
  InvokeMethodUnfold,
  InvokeTestUnfold,
  InvokeEqUnfold,
  InvokeLtUnfold,
  InvokeLeUnfold,
  InvokeGtUnfold,
  InvokeGeUnfold,
  InvokeAddUnfold,
  InvokeSubUnfold,
  InvokeModUnfold,
  InvokeMulUnfold,
  InvokeTruncDivUnfold,
  InvokeBitNotUnfold,
  InvokeBitAndUnfold,
  InvokeBitOrUnfold,
  InvokeBitXorUnfold,
  InvokeBitShrUnfold,
  InvokeBitShlUnfold,
  LoadConst,
  MethodEnd,
}

class LoadLocal0 extends Bytecode {
  const LoadLocal0()
      : super();

  Opcode get opcode => Opcode.LoadLocal0;

  String get name => 'LoadLocal0';

  bool get isBranching => false;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load local 0';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'load local 0';
}

class LoadLocal1 extends Bytecode {
  const LoadLocal1()
      : super();

  Opcode get opcode => Opcode.LoadLocal1;

  String get name => 'LoadLocal1';

  bool get isBranching => false;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load local 1';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'load local 1';
}

class LoadLocal2 extends Bytecode {
  const LoadLocal2()
      : super();

  Opcode get opcode => Opcode.LoadLocal2;

  String get name => 'LoadLocal2';

  bool get isBranching => false;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load local 2';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'load local 2';
}

class LoadLocal3 extends Bytecode {
  const LoadLocal3()
      : super();

  Opcode get opcode => Opcode.LoadLocal3;

  String get name => 'LoadLocal3';

  bool get isBranching => false;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load local 3';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'load local 3';
}

class LoadLocal4 extends Bytecode {
  const LoadLocal4()
      : super();

  Opcode get opcode => Opcode.LoadLocal4;

  String get name => 'LoadLocal4';

  bool get isBranching => false;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load local 4';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'load local 4';
}

class LoadLocal5 extends Bytecode {
  const LoadLocal5()
      : super();

  Opcode get opcode => Opcode.LoadLocal5;

  String get name => 'LoadLocal5';

  bool get isBranching => false;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load local 5';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'load local 5';
}

class LoadLocal extends Bytecode {
  final int uint8Argument0;
  const LoadLocal(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.LoadLocal;

  String get name => 'LoadLocal';

  bool get isBranching => false;

  String get format => 'B';

  int get size => 2;

  int get stackPointerDifference => 1;

  String get formatString => 'load local %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..sendOn(sink);
  }

  String toString() => 'load local ${uint8Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    LoadLocal rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
    return value;
  }
}

class LoadLocalWide extends Bytecode {
  final int uint32Argument0;
  const LoadLocalWide(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.LoadLocalWide;

  String get name => 'LoadLocalWide';

  bool get isBranching => false;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 1;

  String get formatString => 'load local %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'load local ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    LoadLocalWide rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class LoadBoxed extends Bytecode {
  final int uint8Argument0;
  const LoadBoxed(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.LoadBoxed;

  String get name => 'LoadBoxed';

  bool get isBranching => false;

  String get format => 'B';

  int get size => 2;

  int get stackPointerDifference => 1;

  String get formatString => 'load boxed %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..sendOn(sink);
  }

  String toString() => 'load boxed ${uint8Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    LoadBoxed rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
    return value;
  }
}

class LoadStatic extends Bytecode {
  final int uint32Argument0;
  const LoadStatic(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.LoadStatic;

  String get name => 'LoadStatic';

  bool get isBranching => false;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 1;

  String get formatString => 'load static %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'load static ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    LoadStatic rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class LoadStaticInit extends Bytecode {
  final int uint32Argument0;
  const LoadStaticInit(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.LoadStaticInit;

  String get name => 'LoadStaticInit';

  bool get isBranching => false;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 1;

  String get formatString => 'load static init %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'load static init ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    LoadStaticInit rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class LoadField extends Bytecode {
  final int uint8Argument0;
  const LoadField(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.LoadField;

  String get name => 'LoadField';

  bool get isBranching => false;

  String get format => 'B';

  int get size => 2;

  int get stackPointerDifference => 0;

  String get formatString => 'load field %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..sendOn(sink);
  }

  String toString() => 'load field ${uint8Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    LoadField rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
    return value;
  }
}

class LoadFieldWide extends Bytecode {
  final int uint32Argument0;
  const LoadFieldWide(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.LoadFieldWide;

  String get name => 'LoadFieldWide';

  bool get isBranching => false;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'load field %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'load field ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    LoadFieldWide rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class StoreLocal extends Bytecode {
  final int uint8Argument0;
  const StoreLocal(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.StoreLocal;

  String get name => 'StoreLocal';

  bool get isBranching => false;

  String get format => 'B';

  int get size => 2;

  int get stackPointerDifference => 0;

  String get formatString => 'store local %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..sendOn(sink);
  }

  String toString() => 'store local ${uint8Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    StoreLocal rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
    return value;
  }
}

class StoreBoxed extends Bytecode {
  final int uint8Argument0;
  const StoreBoxed(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.StoreBoxed;

  String get name => 'StoreBoxed';

  bool get isBranching => false;

  String get format => 'B';

  int get size => 2;

  int get stackPointerDifference => 0;

  String get formatString => 'store boxed %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..sendOn(sink);
  }

  String toString() => 'store boxed ${uint8Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    StoreBoxed rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
    return value;
  }
}

class StoreStatic extends Bytecode {
  final int uint32Argument0;
  const StoreStatic(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.StoreStatic;

  String get name => 'StoreStatic';

  bool get isBranching => false;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'store static %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'store static ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    StoreStatic rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class StoreField extends Bytecode {
  final int uint8Argument0;
  const StoreField(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.StoreField;

  String get name => 'StoreField';

  bool get isBranching => false;

  String get format => 'B';

  int get size => 2;

  int get stackPointerDifference => -1;

  String get formatString => 'store field %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..sendOn(sink);
  }

  String toString() => 'store field ${uint8Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    StoreField rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
    return value;
  }
}

class StoreFieldWide extends Bytecode {
  final int uint32Argument0;
  const StoreFieldWide(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.StoreFieldWide;

  String get name => 'StoreFieldWide';

  bool get isBranching => false;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'store field %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'store field ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    StoreFieldWide rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class LoadLiteralNull extends Bytecode {
  const LoadLiteralNull()
      : super();

  Opcode get opcode => Opcode.LoadLiteralNull;

  String get name => 'LoadLiteralNull';

  bool get isBranching => false;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load literal null';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'load literal null';
}

class LoadLiteralTrue extends Bytecode {
  const LoadLiteralTrue()
      : super();

  Opcode get opcode => Opcode.LoadLiteralTrue;

  String get name => 'LoadLiteralTrue';

  bool get isBranching => false;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load literal true';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'load literal true';
}

class LoadLiteralFalse extends Bytecode {
  const LoadLiteralFalse()
      : super();

  Opcode get opcode => Opcode.LoadLiteralFalse;

  String get name => 'LoadLiteralFalse';

  bool get isBranching => false;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load literal false';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'load literal false';
}

class LoadLiteral0 extends Bytecode {
  const LoadLiteral0()
      : super();

  Opcode get opcode => Opcode.LoadLiteral0;

  String get name => 'LoadLiteral0';

  bool get isBranching => false;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load literal 0';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'load literal 0';
}

class LoadLiteral1 extends Bytecode {
  const LoadLiteral1()
      : super();

  Opcode get opcode => Opcode.LoadLiteral1;

  String get name => 'LoadLiteral1';

  bool get isBranching => false;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load literal 1';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'load literal 1';
}

class LoadLiteral extends Bytecode {
  final int uint8Argument0;
  const LoadLiteral(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.LoadLiteral;

  String get name => 'LoadLiteral';

  bool get isBranching => false;

  String get format => 'B';

  int get size => 2;

  int get stackPointerDifference => 1;

  String get formatString => 'load literal %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..sendOn(sink);
  }

  String toString() => 'load literal ${uint8Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    LoadLiteral rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
    return value;
  }
}

class LoadLiteralWide extends Bytecode {
  final int uint32Argument0;
  const LoadLiteralWide(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.LoadLiteralWide;

  String get name => 'LoadLiteralWide';

  bool get isBranching => false;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 1;

  String get formatString => 'load literal %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'load literal ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    LoadLiteralWide rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeMethod extends Bytecode {
  final int uint32Argument0;
  const InvokeMethod(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeMethod;

  String get name => 'InvokeMethod';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'invoke method %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke method ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeMethod rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeTest extends Bytecode {
  final int uint32Argument0;
  const InvokeTest(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeTest;

  String get name => 'InvokeTest';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'invoke test %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke test ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeTest rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeEq extends Bytecode {
  final int uint32Argument0;
  const InvokeEq(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeEq;

  String get name => 'InvokeEq';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke eq %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke eq ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeEq rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeLt extends Bytecode {
  final int uint32Argument0;
  const InvokeLt(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeLt;

  String get name => 'InvokeLt';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke lt %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke lt ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeLt rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeLe extends Bytecode {
  final int uint32Argument0;
  const InvokeLe(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeLe;

  String get name => 'InvokeLe';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke le %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke le ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeLe rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeGt extends Bytecode {
  final int uint32Argument0;
  const InvokeGt(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeGt;

  String get name => 'InvokeGt';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke gt %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke gt ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeGt rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeGe extends Bytecode {
  final int uint32Argument0;
  const InvokeGe(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeGe;

  String get name => 'InvokeGe';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke ge %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke ge ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeGe rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeAdd extends Bytecode {
  final int uint32Argument0;
  const InvokeAdd(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeAdd;

  String get name => 'InvokeAdd';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke add %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke add ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeAdd rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeSub extends Bytecode {
  final int uint32Argument0;
  const InvokeSub(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeSub;

  String get name => 'InvokeSub';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke sub %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke sub ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeSub rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeMod extends Bytecode {
  final int uint32Argument0;
  const InvokeMod(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeMod;

  String get name => 'InvokeMod';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke mod %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke mod ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeMod rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeMul extends Bytecode {
  final int uint32Argument0;
  const InvokeMul(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeMul;

  String get name => 'InvokeMul';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke mul %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke mul ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeMul rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeTruncDiv extends Bytecode {
  final int uint32Argument0;
  const InvokeTruncDiv(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeTruncDiv;

  String get name => 'InvokeTruncDiv';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke trunc div %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke trunc div ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeTruncDiv rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitNot extends Bytecode {
  final int uint32Argument0;
  const InvokeBitNot(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitNot;

  String get name => 'InvokeBitNot';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'invoke bit not %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke bit not ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitNot rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitAnd extends Bytecode {
  final int uint32Argument0;
  const InvokeBitAnd(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitAnd;

  String get name => 'InvokeBitAnd';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke bit and %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke bit and ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitAnd rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitOr extends Bytecode {
  final int uint32Argument0;
  const InvokeBitOr(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitOr;

  String get name => 'InvokeBitOr';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke bit or %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke bit or ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitOr rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitXor extends Bytecode {
  final int uint32Argument0;
  const InvokeBitXor(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitXor;

  String get name => 'InvokeBitXor';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke bit xor %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke bit xor ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitXor rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitShr extends Bytecode {
  final int uint32Argument0;
  const InvokeBitShr(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitShr;

  String get name => 'InvokeBitShr';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke bit shr %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke bit shr ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitShr rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitShl extends Bytecode {
  final int uint32Argument0;
  const InvokeBitShl(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitShl;

  String get name => 'InvokeBitShl';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke bit shl %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke bit shl ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitShl rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeStatic extends Bytecode {
  final int uint32Argument0;
  const InvokeStatic(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeStatic;

  String get name => 'InvokeStatic';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'invoke static %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke static ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeStatic rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeFactory extends Bytecode {
  final int uint32Argument0;
  const InvokeFactory(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeFactory;

  String get name => 'InvokeFactory';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'invoke factory %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke factory ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeFactory rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class Allocate extends Bytecode {
  final int uint32Argument0;
  const Allocate(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.Allocate;

  String get name => 'Allocate';

  bool get isBranching => false;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'allocate %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'allocate ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    Allocate rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class AllocateImmutable extends Bytecode {
  final int uint32Argument0;
  const AllocateImmutable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.AllocateImmutable;

  String get name => 'AllocateImmutable';

  bool get isBranching => false;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'allocateim %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'allocateim ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    AllocateImmutable rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeNoSuchMethod extends Bytecode {
  final int uint32Argument0;
  const InvokeNoSuchMethod(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeNoSuchMethod;

  String get name => 'InvokeNoSuchMethod';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'invoke no such method %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke no such method ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeNoSuchMethod rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeTestNoSuchMethod extends Bytecode {
  final int uint32Argument0;
  const InvokeTestNoSuchMethod(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeTestNoSuchMethod;

  String get name => 'InvokeTestNoSuchMethod';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'invoke test no such method %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke test no such method ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeTestNoSuchMethod rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeNative extends Bytecode {
  final int uint8Argument0;
  final int uint8Argument1;
  const InvokeNative(this.uint8Argument0, this.uint8Argument1)
      : super();

  Opcode get opcode => Opcode.InvokeNative;

  String get name => 'InvokeNative';

  bool get isBranching => true;

  String get format => 'BB';

  int get size => 3;

  int get stackPointerDifference => 1;

  String get formatString => 'invoke native %d %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..addUint8(uint8Argument1)
        ..sendOn(sink);
  }

  String toString() => 'invoke native ${uint8Argument0} ${uint8Argument1}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeNative rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    if (uint8Argument1 != rhs.uint8Argument1) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
    value += uint8Argument1;
    return value;
  }
}

class InvokeNativeYield extends Bytecode {
  final int uint8Argument0;
  final int uint8Argument1;
  const InvokeNativeYield(this.uint8Argument0, this.uint8Argument1)
      : super();

  Opcode get opcode => Opcode.InvokeNativeYield;

  String get name => 'InvokeNativeYield';

  bool get isBranching => true;

  String get format => 'BB';

  int get size => 3;

  int get stackPointerDifference => 1;

  String get formatString => 'invoke native yield %d %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..addUint8(uint8Argument1)
        ..sendOn(sink);
  }

  String toString() => 'invoke native yield ${uint8Argument0} ${uint8Argument1}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeNativeYield rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    if (uint8Argument1 != rhs.uint8Argument1) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
    value += uint8Argument1;
    return value;
  }
}

class InvokeSelector extends Bytecode {
  final int uint32Argument0;
  const InvokeSelector(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeSelector;

  String get name => 'InvokeSelector';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'invoke selector';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke selector${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeSelector rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class Pop extends Bytecode {
  const Pop()
      : super();

  Opcode get opcode => Opcode.Pop;

  String get name => 'Pop';

  bool get isBranching => false;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => -1;

  String get formatString => 'pop';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'pop';
}

class Drop extends Bytecode {
  final int uint8Argument0;
  const Drop(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.Drop;

  String get name => 'Drop';

  bool get isBranching => false;

  String get format => 'B';

  int get size => 2;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'drop %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..sendOn(sink);
  }

  String toString() => 'drop ${uint8Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    Drop rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
    return value;
  }
}

class Return extends Bytecode {
  const Return()
      : super();

  Opcode get opcode => Opcode.Return;

  String get name => 'Return';

  bool get isBranching => true;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => -1;

  String get formatString => 'return';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'return';
}

class ReturnNull extends Bytecode {
  const ReturnNull()
      : super();

  Opcode get opcode => Opcode.ReturnNull;

  String get name => 'ReturnNull';

  bool get isBranching => true;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 0;

  String get formatString => 'return null';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'return null';
}

class BranchWide extends Bytecode {
  final int uint32Argument0;
  const BranchWide(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.BranchWide;

  String get name => 'BranchWide';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'branch +%d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'branch +${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    BranchWide rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class BranchIfTrueWide extends Bytecode {
  final int uint32Argument0;
  const BranchIfTrueWide(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.BranchIfTrueWide;

  String get name => 'BranchIfTrueWide';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'branch if true +%d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'branch if true +${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    BranchIfTrueWide rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class BranchIfFalseWide extends Bytecode {
  final int uint32Argument0;
  const BranchIfFalseWide(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.BranchIfFalseWide;

  String get name => 'BranchIfFalseWide';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'branch if false +%d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'branch if false +${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    BranchIfFalseWide rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class BranchBack extends Bytecode {
  final int uint8Argument0;
  const BranchBack(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.BranchBack;

  String get name => 'BranchBack';

  bool get isBranching => true;

  String get format => 'B';

  int get size => 2;

  int get stackPointerDifference => 0;

  String get formatString => 'branch -%d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..sendOn(sink);
  }

  String toString() => 'branch -${uint8Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    BranchBack rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
    return value;
  }
}

class BranchBackIfTrue extends Bytecode {
  final int uint8Argument0;
  const BranchBackIfTrue(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.BranchBackIfTrue;

  String get name => 'BranchBackIfTrue';

  bool get isBranching => true;

  String get format => 'B';

  int get size => 2;

  int get stackPointerDifference => -1;

  String get formatString => 'branch if true -%d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..sendOn(sink);
  }

  String toString() => 'branch if true -${uint8Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    BranchBackIfTrue rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
    return value;
  }
}

class BranchBackIfFalse extends Bytecode {
  final int uint8Argument0;
  const BranchBackIfFalse(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.BranchBackIfFalse;

  String get name => 'BranchBackIfFalse';

  bool get isBranching => true;

  String get format => 'B';

  int get size => 2;

  int get stackPointerDifference => -1;

  String get formatString => 'branch if false -%d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..sendOn(sink);
  }

  String toString() => 'branch if false -${uint8Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    BranchBackIfFalse rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
    return value;
  }
}

class BranchBackWide extends Bytecode {
  final int uint32Argument0;
  const BranchBackWide(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.BranchBackWide;

  String get name => 'BranchBackWide';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'branch -%d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'branch -${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    BranchBackWide rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class BranchBackIfTrueWide extends Bytecode {
  final int uint32Argument0;
  const BranchBackIfTrueWide(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.BranchBackIfTrueWide;

  String get name => 'BranchBackIfTrueWide';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'branch if true -%d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'branch if true -${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    BranchBackIfTrueWide rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class BranchBackIfFalseWide extends Bytecode {
  final int uint32Argument0;
  const BranchBackIfFalseWide(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.BranchBackIfFalseWide;

  String get name => 'BranchBackIfFalseWide';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'branch if false -%d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'branch if false -${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    BranchBackIfFalseWide rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class PopAndBranchWide extends Bytecode {
  final int uint8Argument0;
  final int uint32Argument1;
  const PopAndBranchWide(this.uint8Argument0, this.uint32Argument1)
      : super();

  Opcode get opcode => Opcode.PopAndBranchWide;

  String get name => 'PopAndBranchWide';

  bool get isBranching => true;

  String get format => 'BI';

  int get size => 6;

  int get stackPointerDifference => 0;

  String get formatString => 'pop %d and branch +%d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..addUint32(uint32Argument1)
        ..sendOn(sink);
  }

  String toString() => 'pop ${uint8Argument0} and branch +${uint32Argument1}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    PopAndBranchWide rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    if (uint32Argument1 != rhs.uint32Argument1) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
    value += uint32Argument1;
    return value;
  }
}

class PopAndBranchBackWide extends Bytecode {
  final int uint8Argument0;
  final int uint32Argument1;
  const PopAndBranchBackWide(this.uint8Argument0, this.uint32Argument1)
      : super();

  Opcode get opcode => Opcode.PopAndBranchBackWide;

  String get name => 'PopAndBranchBackWide';

  bool get isBranching => true;

  String get format => 'BI';

  int get size => 6;

  int get stackPointerDifference => 0;

  String get formatString => 'pop %d and branch -%d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..addUint32(uint32Argument1)
        ..sendOn(sink);
  }

  String toString() => 'pop ${uint8Argument0} and branch -${uint32Argument1}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    PopAndBranchBackWide rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    if (uint32Argument1 != rhs.uint32Argument1) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
    value += uint32Argument1;
    return value;
  }
}

class AllocateBoxed extends Bytecode {
  const AllocateBoxed()
      : super();

  Opcode get opcode => Opcode.AllocateBoxed;

  String get name => 'AllocateBoxed';

  bool get isBranching => false;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 0;

  String get formatString => 'allocate boxed';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'allocate boxed';
}

class Negate extends Bytecode {
  const Negate()
      : super();

  Opcode get opcode => Opcode.Negate;

  String get name => 'Negate';

  bool get isBranching => false;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 0;

  String get formatString => 'negate';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'negate';
}

class StackOverflowCheck extends Bytecode {
  final int uint32Argument0;
  const StackOverflowCheck(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.StackOverflowCheck;

  String get name => 'StackOverflowCheck';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'stack overflow check %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'stack overflow check ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    StackOverflowCheck rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class Throw extends Bytecode {
  const Throw()
      : super();

  Opcode get opcode => Opcode.Throw;

  String get name => 'Throw';

  bool get isBranching => true;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 0;

  String get formatString => 'throw';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'throw';
}

class SubroutineCall extends Bytecode {
  final int uint32Argument0;
  final int uint32Argument1;
  const SubroutineCall(this.uint32Argument0, this.uint32Argument1)
      : super();

  Opcode get opcode => Opcode.SubroutineCall;

  String get name => 'SubroutineCall';

  bool get isBranching => true;

  String get format => 'II';

  int get size => 9;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'subroutine call +%d -%d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..addUint32(uint32Argument1)
        ..sendOn(sink);
  }

  String toString() => 'subroutine call +${uint32Argument0} -${uint32Argument1}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    SubroutineCall rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    if (uint32Argument1 != rhs.uint32Argument1) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    value += uint32Argument1;
    return value;
  }
}

class SubroutineReturn extends Bytecode {
  const SubroutineReturn()
      : super();

  Opcode get opcode => Opcode.SubroutineReturn;

  String get name => 'SubroutineReturn';

  bool get isBranching => true;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => -1;

  String get formatString => 'subroutine return';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'subroutine return';
}

class ProcessYield extends Bytecode {
  const ProcessYield()
      : super();

  Opcode get opcode => Opcode.ProcessYield;

  String get name => 'ProcessYield';

  bool get isBranching => true;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 0;

  String get formatString => 'process yield';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'process yield';
}

class CoroutineChange extends Bytecode {
  const CoroutineChange()
      : super();

  Opcode get opcode => Opcode.CoroutineChange;

  String get name => 'CoroutineChange';

  bool get isBranching => true;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => -1;

  String get formatString => 'coroutine change';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'coroutine change';
}

class Identical extends Bytecode {
  const Identical()
      : super();

  Opcode get opcode => Opcode.Identical;

  String get name => 'Identical';

  bool get isBranching => true;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => -1;

  String get formatString => 'identical';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'identical';
}

class IdenticalNonNumeric extends Bytecode {
  const IdenticalNonNumeric()
      : super();

  Opcode get opcode => Opcode.IdenticalNonNumeric;

  String get name => 'IdenticalNonNumeric';

  bool get isBranching => true;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => -1;

  String get formatString => 'identical non numeric';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'identical non numeric';
}

class EnterNoSuchMethod extends Bytecode {
  final int uint8Argument0;
  const EnterNoSuchMethod(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.EnterNoSuchMethod;

  String get name => 'EnterNoSuchMethod';

  bool get isBranching => true;

  String get format => 'B';

  int get size => 2;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'enter noSuchMethod +%d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..sendOn(sink);
  }

  String toString() => 'enter noSuchMethod +${uint8Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    EnterNoSuchMethod rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
    return value;
  }
}

class ExitNoSuchMethod extends Bytecode {
  const ExitNoSuchMethod()
      : super();

  Opcode get opcode => Opcode.ExitNoSuchMethod;

  String get name => 'ExitNoSuchMethod';

  bool get isBranching => true;

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => -1;

  String get formatString => 'exit noSuchMethod';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'exit noSuchMethod';
}

class InvokeMethodUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeMethodUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeMethodUnfold;

  String get name => 'InvokeMethodUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'invoke unfold method %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold method ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeMethodUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeTestUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeTestUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeTestUnfold;

  String get name => 'InvokeTestUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'invoke unfold test %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold test ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeTestUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeEqUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeEqUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeEqUnfold;

  String get name => 'InvokeEqUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke unfold eq %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold eq ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeEqUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeLtUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeLtUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeLtUnfold;

  String get name => 'InvokeLtUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke unfold lt %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold lt ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeLtUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeLeUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeLeUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeLeUnfold;

  String get name => 'InvokeLeUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke unfold le %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold le ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeLeUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeGtUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeGtUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeGtUnfold;

  String get name => 'InvokeGtUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke unfold gt %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold gt ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeGtUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeGeUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeGeUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeGeUnfold;

  String get name => 'InvokeGeUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke unfold ge %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold ge ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeGeUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeAddUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeAddUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeAddUnfold;

  String get name => 'InvokeAddUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke unfold add %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold add ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeAddUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeSubUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeSubUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeSubUnfold;

  String get name => 'InvokeSubUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke unfold sub %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold sub ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeSubUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeModUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeModUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeModUnfold;

  String get name => 'InvokeModUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke unfold mod %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold mod ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeModUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeMulUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeMulUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeMulUnfold;

  String get name => 'InvokeMulUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke unfold mul %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold mul ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeMulUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeTruncDivUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeTruncDivUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeTruncDivUnfold;

  String get name => 'InvokeTruncDivUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke unfold trunc div %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold trunc div ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeTruncDivUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitNotUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeBitNotUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitNotUnfold;

  String get name => 'InvokeBitNotUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'invoke unfold bit not %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold bit not ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitNotUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitAndUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeBitAndUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitAndUnfold;

  String get name => 'InvokeBitAndUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke unfold bit and %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold bit and ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitAndUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitOrUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeBitOrUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitOrUnfold;

  String get name => 'InvokeBitOrUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke unfold bit or %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold bit or ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitOrUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitXorUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeBitXorUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitXorUnfold;

  String get name => 'InvokeBitXorUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke unfold bit xor %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold bit xor ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitXorUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitShrUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeBitShrUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitShrUnfold;

  String get name => 'InvokeBitShrUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke unfold bit shr %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold bit shr ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitShrUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitShlUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeBitShlUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitShlUnfold;

  String get name => 'InvokeBitShlUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke unfold bit shl %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke unfold bit shl ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitShlUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class LoadConst extends Bytecode {
  final int uint32Argument0;
  const LoadConst(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.LoadConst;

  String get name => 'LoadConst';

  bool get isBranching => false;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 1;

  String get formatString => 'load const @%d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'load const @${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    LoadConst rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class MethodEnd extends Bytecode {
  final int uint32Argument0;
  const MethodEnd(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.MethodEnd;

  String get name => 'MethodEnd';

  bool get isBranching => false;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'method end %d';

  void addTo(Sink<List<int>> sink) {
    new BytecodeBuffer()
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'method end ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    MethodEnd rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}
