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
  LoadBoxed,
  LoadStatic,
  LoadStaticInit,
  LoadField,
  LoadConst,
  LoadConstUnfold,
  StoreLocal,
  StoreBoxed,
  StoreStatic,
  StoreField,
  LoadLiteralNull,
  LoadLiteralTrue,
  LoadLiteralFalse,
  LoadLiteral0,
  LoadLiteral1,
  LoadLiteral,
  LoadLiteralWide,
  InvokeMethod,
  InvokeStatic,
  InvokeStaticUnfold,
  InvokeFactory,
  InvokeFactoryUnfold,
  InvokeNative,
  InvokeNativeYield,
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
  Pop,
  Return,
  BranchLong,
  BranchIfTrueLong,
  BranchIfFalseLong,
  BranchBack,
  BranchBackIfTrue,
  BranchBackIfFalse,
  BranchBackLong,
  BranchBackIfTrueLong,
  BranchBackIfFalseLong,
  Allocate,
  AllocateUnfold,
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

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load local 0';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class LoadLocal1 extends Bytecode {
  const LoadLocal1()
      : super();

  Opcode get opcode => Opcode.LoadLocal1;

  String get name => 'LoadLocal1';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load local 1';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class LoadLocal2 extends Bytecode {
  const LoadLocal2()
      : super();

  Opcode get opcode => Opcode.LoadLocal2;

  String get name => 'LoadLocal2';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load local 2';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class LoadLocal extends Bytecode {
  final int uint8Argument0;
  const LoadLocal(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.LoadLocal;

  String get name => 'LoadLocal';

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
}

class LoadBoxed extends Bytecode {
  final int uint8Argument0;
  const LoadBoxed(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.LoadBoxed;

  String get name => 'LoadBoxed';

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
}

class LoadStatic extends Bytecode {
  final int uint32Argument0;
  const LoadStatic(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.LoadStatic;

  String get name => 'LoadStatic';

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
}

class LoadStaticInit extends Bytecode {
  final int uint32Argument0;
  const LoadStaticInit(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.LoadStaticInit;

  String get name => 'LoadStaticInit';

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
}

class LoadField extends Bytecode {
  final int uint8Argument0;
  const LoadField(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.LoadField;

  String get name => 'LoadField';

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
}

class LoadConst extends Bytecode {
  final int uint32Argument0;
  const LoadConst(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.LoadConst;

  String get name => 'LoadConst';

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
}

class LoadConstUnfold extends Bytecode {
  final int uint32Argument0;
  const LoadConstUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.LoadConstUnfold;

  String get name => 'LoadConstUnfold';

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
}

class StoreLocal extends Bytecode {
  final int uint8Argument0;
  const StoreLocal(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.StoreLocal;

  String get name => 'StoreLocal';

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
}

class StoreBoxed extends Bytecode {
  final int uint8Argument0;
  const StoreBoxed(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.StoreBoxed;

  String get name => 'StoreBoxed';

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
}

class StoreStatic extends Bytecode {
  final int uint32Argument0;
  const StoreStatic(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.StoreStatic;

  String get name => 'StoreStatic';

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
}

class StoreField extends Bytecode {
  final int uint8Argument0;
  const StoreField(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.StoreField;

  String get name => 'StoreField';

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
}

class LoadLiteralNull extends Bytecode {
  const LoadLiteralNull()
      : super();

  Opcode get opcode => Opcode.LoadLiteralNull;

  String get name => 'LoadLiteralNull';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load literal null';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class LoadLiteralTrue extends Bytecode {
  const LoadLiteralTrue()
      : super();

  Opcode get opcode => Opcode.LoadLiteralTrue;

  String get name => 'LoadLiteralTrue';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load literal true';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class LoadLiteralFalse extends Bytecode {
  const LoadLiteralFalse()
      : super();

  Opcode get opcode => Opcode.LoadLiteralFalse;

  String get name => 'LoadLiteralFalse';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load literal false';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class LoadLiteral0 extends Bytecode {
  const LoadLiteral0()
      : super();

  Opcode get opcode => Opcode.LoadLiteral0;

  String get name => 'LoadLiteral0';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load literal 0';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class LoadLiteral1 extends Bytecode {
  const LoadLiteral1()
      : super();

  Opcode get opcode => Opcode.LoadLiteral1;

  String get name => 'LoadLiteral1';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 1;

  String get formatString => 'load literal 1';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class LoadLiteral extends Bytecode {
  final int uint8Argument0;
  const LoadLiteral(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.LoadLiteral;

  String get name => 'LoadLiteral';

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
}

class LoadLiteralWide extends Bytecode {
  final int uint32Argument0;
  const LoadLiteralWide(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.LoadLiteralWide;

  String get name => 'LoadLiteralWide';

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
}

class InvokeMethod extends Bytecode {
  final int uint32Argument0;
  const InvokeMethod(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeMethod;

  String get name => 'InvokeMethod';

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
}

class InvokeStatic extends Bytecode {
  final int uint32Argument0;
  const InvokeStatic(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeStatic;

  String get name => 'InvokeStatic';

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
}

class InvokeStaticUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeStaticUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeStaticUnfold;

  String get name => 'InvokeStaticUnfold';

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
}

class InvokeFactory extends Bytecode {
  final int uint32Argument0;
  const InvokeFactory(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeFactory;

  String get name => 'InvokeFactory';

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
}

class InvokeFactoryUnfold extends Bytecode {
  final int uint32Argument0;
  const InvokeFactoryUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeFactoryUnfold;

  String get name => 'InvokeFactoryUnfold';

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
}

class InvokeNative extends Bytecode {
  final int uint8Argument0;
  final int uint8Argument1;
  const InvokeNative(this.uint8Argument0, this.uint8Argument1)
      : super();

  Opcode get opcode => Opcode.InvokeNative;

  String get name => 'InvokeNative';

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
}

class InvokeNativeYield extends Bytecode {
  final int uint8Argument0;
  final int uint8Argument1;
  const InvokeNativeYield(this.uint8Argument0, this.uint8Argument1)
      : super();

  Opcode get opcode => Opcode.InvokeNativeYield;

  String get name => 'InvokeNativeYield';

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
}

class InvokeTest extends Bytecode {
  final int uint32Argument0;
  const InvokeTest(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeTest;

  String get name => 'InvokeTest';

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
}

class InvokeEq extends Bytecode {
  final int uint32Argument0;
  const InvokeEq(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeEq;

  String get name => 'InvokeEq';

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke eq';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }
}

class InvokeLt extends Bytecode {
  final int uint32Argument0;
  const InvokeLt(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeLt;

  String get name => 'InvokeLt';

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke lt';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }
}

class InvokeLe extends Bytecode {
  final int uint32Argument0;
  const InvokeLe(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeLe;

  String get name => 'InvokeLe';

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke le';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }
}

class InvokeGt extends Bytecode {
  final int uint32Argument0;
  const InvokeGt(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeGt;

  String get name => 'InvokeGt';

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke gt';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }
}

class InvokeGe extends Bytecode {
  final int uint32Argument0;
  const InvokeGe(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeGe;

  String get name => 'InvokeGe';

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke ge';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }
}

class InvokeAdd extends Bytecode {
  final int uint32Argument0;
  const InvokeAdd(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeAdd;

  String get name => 'InvokeAdd';

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke add';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }
}

class InvokeSub extends Bytecode {
  final int uint32Argument0;
  const InvokeSub(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeSub;

  String get name => 'InvokeSub';

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke sub';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }
}

class InvokeMod extends Bytecode {
  final int uint32Argument0;
  const InvokeMod(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeMod;

  String get name => 'InvokeMod';

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke mod';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }
}

class InvokeMul extends Bytecode {
  final int uint32Argument0;
  const InvokeMul(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeMul;

  String get name => 'InvokeMul';

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke mul';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }
}

class InvokeTruncDiv extends Bytecode {
  final int uint32Argument0;
  const InvokeTruncDiv(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeTruncDiv;

  String get name => 'InvokeTruncDiv';

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke trunc div';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }
}

class InvokeBitNot extends Bytecode {
  final int uint32Argument0;
  const InvokeBitNot(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitNot;

  String get name => 'InvokeBitNot';

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'invoke bit not';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }
}

class InvokeBitAnd extends Bytecode {
  final int uint32Argument0;
  const InvokeBitAnd(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitAnd;

  String get name => 'InvokeBitAnd';

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke bit and';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }
}

class InvokeBitOr extends Bytecode {
  final int uint32Argument0;
  const InvokeBitOr(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitOr;

  String get name => 'InvokeBitOr';

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke bit or';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }
}

class InvokeBitXor extends Bytecode {
  final int uint32Argument0;
  const InvokeBitXor(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitXor;

  String get name => 'InvokeBitXor';

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke bit xor';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }
}

class InvokeBitShr extends Bytecode {
  final int uint32Argument0;
  const InvokeBitShr(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitShr;

  String get name => 'InvokeBitShr';

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke bit shr';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }
}

class InvokeBitShl extends Bytecode {
  final int uint32Argument0;
  const InvokeBitShl(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.InvokeBitShl;

  String get name => 'InvokeBitShl';

  String get format => 'I';

  int get size => 5;

  int get stackPointerDifference => -1;

  String get formatString => 'invoke bit shl';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..addUint32(uint32Argument0)
        ..sendOn(sink);
  }
}

class Pop extends Bytecode {
  const Pop()
      : super();

  Opcode get opcode => Opcode.Pop;

  String get name => 'Pop';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => -1;

  String get formatString => 'pop';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class Return extends Bytecode {
  final int uint8Argument0;
  final int uint8Argument1;
  const Return(this.uint8Argument0, this.uint8Argument1)
      : super();

  Opcode get opcode => Opcode.Return;

  String get name => 'Return';

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
}

class BranchLong extends Bytecode {
  final int uint32Argument0;
  const BranchLong(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.BranchLong;

  String get name => 'BranchLong';

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
}

class BranchIfTrueLong extends Bytecode {
  final int uint32Argument0;
  const BranchIfTrueLong(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.BranchIfTrueLong;

  String get name => 'BranchIfTrueLong';

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
}

class BranchIfFalseLong extends Bytecode {
  final int uint32Argument0;
  const BranchIfFalseLong(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.BranchIfFalseLong;

  String get name => 'BranchIfFalseLong';

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
}

class BranchBack extends Bytecode {
  final int uint8Argument0;
  const BranchBack(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.BranchBack;

  String get name => 'BranchBack';

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
}

class BranchBackIfTrue extends Bytecode {
  final int uint8Argument0;
  const BranchBackIfTrue(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.BranchBackIfTrue;

  String get name => 'BranchBackIfTrue';

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
}

class BranchBackIfFalse extends Bytecode {
  final int uint8Argument0;
  const BranchBackIfFalse(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.BranchBackIfFalse;

  String get name => 'BranchBackIfFalse';

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
}

class BranchBackLong extends Bytecode {
  final int uint32Argument0;
  const BranchBackLong(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.BranchBackLong;

  String get name => 'BranchBackLong';

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
}

class BranchBackIfTrueLong extends Bytecode {
  final int uint32Argument0;
  const BranchBackIfTrueLong(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.BranchBackIfTrueLong;

  String get name => 'BranchBackIfTrueLong';

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
}

class BranchBackIfFalseLong extends Bytecode {
  final int uint32Argument0;
  const BranchBackIfFalseLong(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.BranchBackIfFalseLong;

  String get name => 'BranchBackIfFalseLong';

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
}

class Allocate extends Bytecode {
  final int uint32Argument0;
  const Allocate(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.Allocate;

  String get name => 'Allocate';

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
}

class AllocateUnfold extends Bytecode {
  final int uint32Argument0;
  const AllocateUnfold(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.AllocateUnfold;

  String get name => 'AllocateUnfold';

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
}

class AllocateBoxed extends Bytecode {
  const AllocateBoxed()
      : super();

  Opcode get opcode => Opcode.AllocateBoxed;

  String get name => 'AllocateBoxed';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 0;

  String get formatString => 'allocate boxed';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class Negate extends Bytecode {
  const Negate()
      : super();

  Opcode get opcode => Opcode.Negate;

  String get name => 'Negate';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 0;

  String get formatString => 'negate';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class StackOverflowCheck extends Bytecode {
  const StackOverflowCheck()
      : super();

  Opcode get opcode => Opcode.StackOverflowCheck;

  String get name => 'StackOverflowCheck';

  String get format => '';

  int get size => 5;

  int get stackPointerDifference => 0;

  String get formatString => 'stack overflow check';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class Throw extends Bytecode {
  const Throw()
      : super();

  Opcode get opcode => Opcode.Throw;

  String get name => 'Throw';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 0;

  String get formatString => 'throw';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class SubroutineCall extends Bytecode {
  final int uint32Argument0;
  final int uint32Argument1;
  const SubroutineCall(this.uint32Argument0, this.uint32Argument1)
      : super();

  Opcode get opcode => Opcode.SubroutineCall;

  String get name => 'SubroutineCall';

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
}

class SubroutineReturn extends Bytecode {
  const SubroutineReturn()
      : super();

  Opcode get opcode => Opcode.SubroutineReturn;

  String get name => 'SubroutineReturn';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => -1;

  String get formatString => 'subroutine return';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class ProcessYield extends Bytecode {
  const ProcessYield()
      : super();

  Opcode get opcode => Opcode.ProcessYield;

  String get name => 'ProcessYield';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 0;

  String get formatString => 'process yield';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class CoroutineChange extends Bytecode {
  const CoroutineChange()
      : super();

  Opcode get opcode => Opcode.CoroutineChange;

  String get name => 'CoroutineChange';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => -1;

  String get formatString => 'coroutine change';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class Identical extends Bytecode {
  const Identical()
      : super();

  Opcode get opcode => Opcode.Identical;

  String get name => 'Identical';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => -1;

  String get formatString => 'identical';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class IdenticalNonNumeric extends Bytecode {
  const IdenticalNonNumeric()
      : super();

  Opcode get opcode => Opcode.IdenticalNonNumeric;

  String get name => 'IdenticalNonNumeric';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => -1;

  String get formatString => 'identical non numeric';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class EnterNoSuchMethod extends Bytecode {
  const EnterNoSuchMethod()
      : super();

  Opcode get opcode => Opcode.EnterNoSuchMethod;

  String get name => 'EnterNoSuchMethod';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => 3;

  String get formatString => 'enter noSuchMethod';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class ExitNoSuchMethod extends Bytecode {
  const ExitNoSuchMethod()
      : super();

  Opcode get opcode => Opcode.ExitNoSuchMethod;

  String get name => 'ExitNoSuchMethod';

  String get format => '';

  int get size => 1;

  int get stackPointerDifference => -1;

  String get formatString => 'exit noSuchMethod';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
        ..sendOn(sink);
  }
}

class FrameSize extends Bytecode {
  final int uint8Argument0;
  const FrameSize(this.uint8Argument0)
      : super();

  Opcode get opcode => Opcode.FrameSize;

  String get name => 'FrameSize';

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
}

class MethodEnd extends Bytecode {
  final int uint32Argument0;
  const MethodEnd(this.uint32Argument0)
      : super();

  Opcode get opcode => Opcode.MethodEnd;

  String get name => 'MethodEnd';

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
}
