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

  /**
   * The signature of the CompiledFunction.
   *
   * Som compiled functions does not have a signature (for example, generated
   * accessors).
   */
  final FunctionSignature signature;

  /**
   * If the functions is an instance member, [memberOf] is set to the compiled
   * class.
   *
   * If [memberOf] is set, the compiled function takes an 'this' argument in
   * addition to that of [signature].
   */
  final CompiledClass memberOf;

  final Map<ConstantValue, int> constants = <ConstantValue, int>{};

  final Map<int, ConstantValue> functionConstantValues = <int, ConstantValue>{};

  final Map<int, ConstantValue> classConstantValues = <int, ConstantValue>{};

  CompiledFunction(this.methodId,
                   FunctionSignature signature,
                   CompiledClass memberOf)
      : this.signature = signature,
        this.memberOf = memberOf,
        builder = new BytecodeBuilder(
          signature.parameterCount + (memberOf != null ? 1 : 0));

  CompiledFunction.accessor(this.methodId, bool setter)
      : builder = new BytecodeBuilder(setter ? 2 : 1);

  bool get hasThisArgument => memberOf != null;

  int allocateConstant(ConstantValue constant) {
    return constants.putIfAbsent(constant, () => constants.length);
  }

  int allocateConstantFromFunction(int methodId) {
    FletchFunctionConstant constant =
        functionConstantValues.putIfAbsent(
            methodId, () => new FletchFunctionConstant(methodId));
    return allocateConstant(constant);
  }

  int allocateConstantFromClass(int classId) {
    FletchClassConstant constant =
        classConstantValues.putIfAbsent(
            classId, () => new FletchClassConstant(classId));
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
