// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.compiled_function;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue;

import 'package:compiler/src/elements/elements.dart';

import 'fletch_constants.dart' show
    FletchFunctionConstant,
    FletchClassConstant;

import '../bytecodes.dart' show
    Bytecode;

import 'bytecode_builder.dart';

class CompiledFunction {
  final BytecodeBuilder builder;

  final int methodId;

  final Map<ConstantValue, int> constants = <ConstantValue, int>{};

  final Map<int, ConstantValue> functionConstantValues = <int, ConstantValue>{};

  final Map<Element, ConstantValue> classConstantValues =
      <Element, ConstantValue>{};

  CompiledFunction(this.methodId, int arity)
      : builder = new BytecodeBuilder(arity);

  int allocateConstant(ConstantValue constant) {
    return constants.putIfAbsent(constant, () => constants.length);
  }

  int allocateConstantFromFunction(int methodId) {
    FletchFunctionConstant constant =
        functionConstantValues.putIfAbsent(
            methodId, () => new FletchFunctionConstant(methodId));
    return allocateConstant(constant);
  }

  int allocateConstantFromClass(ClassElement element) {
    FletchClassConstant constant =
        classConstantValues.putIfAbsent(
            element, () => new FletchClassConstant(element));
    return allocateConstant(constant);
  }

  String verboseToString() {
    StringBuffer sb = new StringBuffer();

    sb.writeln("Constants:");
    constants.forEach((constant, int index) {
      if (constant is ConstantValue) {
        constant = constant.toStructuredString();
      }
      sb.writeln("  #$index: $constant");
    });

    sb.writeln("Bytecodes:");
    int offset = 0;
    for (Bytecode bytecode in builder.bytecodes) {
      sb.writeln("  $offset: $bytecode");
      offset += bytecode.size;
    }

    return '$sb';
  }
}
