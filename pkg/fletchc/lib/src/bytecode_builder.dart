// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.bytecode_builder;

import '../bytecodes.dart';

class BytecodeBuilder {
  final List<Bytecode> bytecodes = <Bytecode>[];

  int stackSize = 0;

  void loadConst(int id) {
    bytecodes.add(new LoadConstUnfold(id));
    stackSize += 1;
  }

  void loadLiteralNull() {
    bytecodes.add(new LoadLiteralNull());
    stackSize += 1;
  }

  void invokeStatic(int id, int arguments) {
    bytecodes.add(new InvokeStaticUnfold(id));
    stackSize += 1 - arguments;
  }

  void pop() {
    bytecodes.add(new Pop());
    stackSize -= 1;
  }

  void ret() {
    assert(stackSize > 0);
    // TODO(ajohnsen): Set argument count.
    bytecodes.add(new Return(stackSize - 1, 0));
    stackSize -= 1;
  }

  bool get endsWithReturn => bytecodes.isNotEmpty && bytecodes.last is Return;

  void methodEnd() {
    int size = 0;
    for (var bytecode in bytecodes) size += bytecode.size;
    bytecodes.add(new MethodEnd(size));
  }
}
