// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// WARNING: Generated file, do not edit!

part of fletch.bytecodes;

enum Opcode {
  LoadLocal0,
  LoadLocal1,
  LoadLocal2,
  LoadLocal,
  LoadLocalWide,
  LoadBoxed,
  LoadStatic,
  LoadStaticInit,
  LoadField,
  LoadFieldWide,
  LoadConst,
  LoadConstUnfold,
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
  InvokeMethodFast,
  InvokeMethodVtable,
  InvokeStatic,
  InvokeStaticUnfold,
  InvokeFactory,
  InvokeFactoryUnfold,
  InvokeNative,
  InvokeNativeYield,
  InvokeSelector,
  InvokeTest,
  InvokeTestFast,
  InvokeTestVtable,
  InvokeEq,
  InvokeEqFast,
  InvokeEqVtable,
  InvokeLt,
  InvokeLtFast,
  InvokeLtVtable,
  InvokeLe,
  InvokeLeFast,
  InvokeLeVtable,
  InvokeGt,
  InvokeGtFast,
  InvokeGtVtable,
  InvokeGe,
  InvokeGeFast,
  InvokeGeVtable,
  InvokeAdd,
  InvokeAddFast,
  InvokeAddVtable,
  InvokeSub,
  InvokeSubFast,
  InvokeSubVtable,
  InvokeMod,
  InvokeModFast,
  InvokeModVtable,
  InvokeMul,
  InvokeMulFast,
  InvokeMulVtable,
  InvokeTruncDiv,
  InvokeTruncDivFast,
  InvokeTruncDivVtable,
  InvokeBitNot,
  InvokeBitNotFast,
  InvokeBitNotVtable,
  InvokeBitAnd,
  InvokeBitAndFast,
  InvokeBitAndVtable,
  InvokeBitOr,
  InvokeBitOrFast,
  InvokeBitOrVtable,
  InvokeBitXor,
  InvokeBitXorFast,
  InvokeBitXorVtable,
  InvokeBitShr,
  InvokeBitShrFast,
  InvokeBitShrVtable,
  InvokeBitShl,
  InvokeBitShlFast,
  InvokeBitShlVtable,
  Pop,
  Return,
  ReturnWide,
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
  Allocate,
  AllocateUnfold,
  AllocateImmutable,
  AllocateImmutableUnfold,
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
  FrameSize,
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
    buffer
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
    buffer
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
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'load local 2';
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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

  String get formatString => 'load const %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'load const ${uint32Argument0}';

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

class LoadConstUnfold extends Bytecode {
  final int uint32Argument0;
  const LoadConstUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.LoadConstUnfold;

  String get name => 'LoadConstUnfold';

  bool get isBranching => false;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 1;

  String get formatString => 'load const @%d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'load const @${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    LoadConstUnfold rhs = other;
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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

  String get formatString => 'invoke %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke ${uint32Argument0}';

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

class InvokeMethodFast extends Bytecode {
  final int uint32Argument0;
  const InvokeMethodFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeMethodFast;

  String get name => 'InvokeMethodFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'invoke fast %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeMethodFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeMethodVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeMethodVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeMethodVtable;

  String get name => 'InvokeMethodVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'invoke vtable %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeMethodVtable rhs = other;
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
    buffer
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

class InvokeStaticUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeStaticUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeStaticUnfold;

  String get name => 'InvokeStaticUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'invoke static @%d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke static @${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeStaticUnfold rhs = other;
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
    buffer
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

class InvokeFactoryUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeFactoryUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeFactoryUnfold;

  String get name => 'InvokeFactoryUnfold';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'invoke factory @%d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke factory @${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeFactoryUnfold rhs = other;
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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

class InvokeTestFast extends Bytecode {
  final int uint32Argument0;
  const InvokeTestFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeTestFast;

  String get name => 'InvokeTestFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'invoke fast test %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast test ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeTestFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeTestVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeTestVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeTestVtable;

  String get name => 'InvokeTestVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'invoke vtable test %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable test ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeTestVtable rhs = other;
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
    buffer
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

class InvokeEqFast extends Bytecode {
  final int uint32Argument0;
  const InvokeEqFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeEqFast;

  String get name => 'InvokeEqFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke fast eq %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast eq ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeEqFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeEqVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeEqVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeEqVtable;

  String get name => 'InvokeEqVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke vtable eq %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable eq ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeEqVtable rhs = other;
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
    buffer
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

class InvokeLtFast extends Bytecode {
  final int uint32Argument0;
  const InvokeLtFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeLtFast;

  String get name => 'InvokeLtFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke fast lt %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast lt ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeLtFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeLtVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeLtVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeLtVtable;

  String get name => 'InvokeLtVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke vtable lt %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable lt ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeLtVtable rhs = other;
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
    buffer
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

class InvokeLeFast extends Bytecode {
  final int uint32Argument0;
  const InvokeLeFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeLeFast;

  String get name => 'InvokeLeFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke fast le %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast le ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeLeFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeLeVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeLeVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeLeVtable;

  String get name => 'InvokeLeVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke vtable le %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable le ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeLeVtable rhs = other;
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
    buffer
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

class InvokeGtFast extends Bytecode {
  final int uint32Argument0;
  const InvokeGtFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeGtFast;

  String get name => 'InvokeGtFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke fast gt %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast gt ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeGtFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeGtVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeGtVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeGtVtable;

  String get name => 'InvokeGtVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke vtable gt %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable gt ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeGtVtable rhs = other;
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
    buffer
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

class InvokeGeFast extends Bytecode {
  final int uint32Argument0;
  const InvokeGeFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeGeFast;

  String get name => 'InvokeGeFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke fast ge %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast ge ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeGeFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeGeVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeGeVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeGeVtable;

  String get name => 'InvokeGeVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke vtable ge %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable ge ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeGeVtable rhs = other;
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
    buffer
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

class InvokeAddFast extends Bytecode {
  final int uint32Argument0;
  const InvokeAddFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeAddFast;

  String get name => 'InvokeAddFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke fast add %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast add ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeAddFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeAddVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeAddVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeAddVtable;

  String get name => 'InvokeAddVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke vtable add %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable add ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeAddVtable rhs = other;
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
    buffer
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

class InvokeSubFast extends Bytecode {
  final int uint32Argument0;
  const InvokeSubFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeSubFast;

  String get name => 'InvokeSubFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke fast sub %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast sub ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeSubFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeSubVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeSubVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeSubVtable;

  String get name => 'InvokeSubVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke vtable sub %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable sub ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeSubVtable rhs = other;
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
    buffer
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

class InvokeModFast extends Bytecode {
  final int uint32Argument0;
  const InvokeModFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeModFast;

  String get name => 'InvokeModFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke fast mod %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast mod ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeModFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeModVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeModVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeModVtable;

  String get name => 'InvokeModVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke vtable mod %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable mod ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeModVtable rhs = other;
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
    buffer
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

class InvokeMulFast extends Bytecode {
  final int uint32Argument0;
  const InvokeMulFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeMulFast;

  String get name => 'InvokeMulFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke fast mul %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast mul ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeMulFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeMulVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeMulVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeMulVtable;

  String get name => 'InvokeMulVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke vtable mul %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable mul ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeMulVtable rhs = other;
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
    buffer
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

class InvokeTruncDivFast extends Bytecode {
  final int uint32Argument0;
  const InvokeTruncDivFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeTruncDivFast;

  String get name => 'InvokeTruncDivFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke fast trunc div %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast trunc div ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeTruncDivFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeTruncDivVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeTruncDivVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeTruncDivVtable;

  String get name => 'InvokeTruncDivVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke vtable trunc div %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable trunc div ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeTruncDivVtable rhs = other;
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
    buffer
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

class InvokeBitNotFast extends Bytecode {
  final int uint32Argument0;
  const InvokeBitNotFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitNotFast;

  String get name => 'InvokeBitNotFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'invoke fast bit not %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast bit not ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitNotFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitNotVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeBitNotVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitNotVtable;

  String get name => 'InvokeBitNotVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'invoke vtable bit not %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable bit not ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitNotVtable rhs = other;
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
    buffer
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

class InvokeBitAndFast extends Bytecode {
  final int uint32Argument0;
  const InvokeBitAndFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitAndFast;

  String get name => 'InvokeBitAndFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke fast bit and %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast bit and ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitAndFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitAndVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeBitAndVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitAndVtable;

  String get name => 'InvokeBitAndVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke vtable bit and %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable bit and ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitAndVtable rhs = other;
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
    buffer
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

class InvokeBitOrFast extends Bytecode {
  final int uint32Argument0;
  const InvokeBitOrFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitOrFast;

  String get name => 'InvokeBitOrFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke fast bit or %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast bit or ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitOrFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitOrVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeBitOrVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitOrVtable;

  String get name => 'InvokeBitOrVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke vtable bit or %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable bit or ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitOrVtable rhs = other;
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
    buffer
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

class InvokeBitXorFast extends Bytecode {
  final int uint32Argument0;
  const InvokeBitXorFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitXorFast;

  String get name => 'InvokeBitXorFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke fast bit xor %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast bit xor ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitXorFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitXorVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeBitXorVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitXorVtable;

  String get name => 'InvokeBitXorVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke vtable bit xor %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable bit xor ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitXorVtable rhs = other;
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
    buffer
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

class InvokeBitShrFast extends Bytecode {
  final int uint32Argument0;
  const InvokeBitShrFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitShrFast;

  String get name => 'InvokeBitShrFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke fast bit shr %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast bit shr ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitShrFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitShrVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeBitShrVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitShrVtable;

  String get name => 'InvokeBitShrVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke vtable bit shr %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable bit shr ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitShrVtable rhs = other;
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
    buffer
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

class InvokeBitShlFast extends Bytecode {
  final int uint32Argument0;
  const InvokeBitShlFast(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitShlFast;

  String get name => 'InvokeBitShlFast';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke fast bit shl %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke fast bit shl ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitShlFast rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    return value;
  }
}

class InvokeBitShlVtable extends Bytecode {
  final int uint32Argument0;
  const InvokeBitShlVtable(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitShlVtable;

  String get name => 'InvokeBitShlVtable';

  bool get isBranching => true;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke vtable bit shl %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'invoke vtable bit shl ${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    InvokeBitShlVtable rhs = other;
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
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'pop';
}

class Return extends Bytecode {
  final int uint8Argument0;
  final int uint8Argument1;
  const Return(this.uint8Argument0, this.uint8Argument1)
      : super();

  Opcode get opcode => Opcode.Return;

  String get name => 'Return';

  bool get isBranching => true;

  String get format => 'BB';

  int get size => 3;

  int get stackPointerDifference => -1;

  String get formatString => 'return %d %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..addUint8(uint8Argument1)
        ..sendOn(sink);
  }

  String toString() => 'return ${uint8Argument0} ${uint8Argument1}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    Return rhs = other;
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

class ReturnWide extends Bytecode {
  final int uint32Argument0;
  final int uint8Argument1;
  const ReturnWide(this.uint32Argument0, this.uint8Argument1)
      : super();

  Opcode get opcode => Opcode.ReturnWide;

  String get name => 'ReturnWide';

  bool get isBranching => true;

  String get format => 'IB';

  int get size => 6;

  int get stackPointerDifference => -1;

  String get formatString => 'return %d %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..addUint8(uint8Argument1)
        ..sendOn(sink);
  }

  String toString() => 'return ${uint32Argument0} ${uint8Argument1}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    ReturnWide rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    if (uint8Argument1 != rhs.uint8Argument1) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
    value += uint8Argument1;
    return value;
  }
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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

class AllocateUnfold extends Bytecode {
  final int uint32Argument0;
  const AllocateUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.AllocateUnfold;

  String get name => 'AllocateUnfold';

  bool get isBranching => false;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'allocate @%d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'allocate @${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    AllocateUnfold rhs = other;
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
    buffer
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

class AllocateImmutableUnfold extends Bytecode {
  final int uint32Argument0;
  const AllocateImmutableUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.AllocateImmutableUnfold;

  String get name => 'AllocateImmutableUnfold';

  bool get isBranching => false;

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'allocateim @%d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }

  String toString() => 'allocateim @${uint32Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    AllocateImmutableUnfold rhs = other;
    if (uint32Argument0 != rhs.uint32Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint32Argument0;
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
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
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }

  String toString() => 'exit noSuchMethod';
}

class FrameSize extends Bytecode {
  final int uint8Argument0;
  const FrameSize(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.FrameSize;

  String get name => 'FrameSize';

  bool get isBranching => false;

  String get format => 'B';

  int get size => 2;

  int get stackPointerDifference => VAR_DIFF;

  String get formatString => 'frame size %d';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint8(uint8Argument0)
        ..sendOn(sink);
  }

  String toString() => 'frame size ${uint8Argument0}';

  operator==(Bytecode other) {
    if (!(super==(other))) return false;
    FrameSize rhs = other;
    if (uint8Argument0 != rhs.uint8Argument0) return false;
    return true;
  }

  int get hashCode {
    int value = super.hashCode;
    value += uint8Argument0;
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
    buffer
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
