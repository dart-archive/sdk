// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.compiled_function;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue;

import 'package:compiler/src/elements/elements.dart';

import 'dartino_constants.dart' show
    DartinoFunctionConstant,
    DartinoClassConstant;

import '../bytecodes.dart' show
    Bytecode,
    Opcode;

import 'dartino_context.dart';
import 'bytecode_assembler.dart';

import '../dartino_system.dart';
import '../vm_commands.dart';

class DartinoFunctionBuilder extends DartinoFunctionBase {
  final BytecodeAssembler assembler;

  /**
   * If the functions is an instance member, [memberOf] is set to the id of the
   * class.
   *
   * If [memberOf] is set, the compiled function takes a 'this' argument in
   * addition to those of [signature].
   */
  final Map<ConstantValue, int> constants = <ConstantValue, int>{};
  final Map<int, ConstantValue> functionConstantValues = <int, ConstantValue>{};
  final Map<int, ConstantValue> classConstantValues = <int, ConstantValue>{};

  DartinoFunctionBuilder.fromDartinoFunction(DartinoFunction function)
      : this(
          function.functionId,
          function.kind,
          function.arity,
          name: function.name,
          element: function.element,
          memberOf: function.memberOf);

  DartinoFunctionBuilder(
      int functionId,
      DartinoFunctionKind kind,
      int arity,
      {String name,
       Element element,
       FunctionSignature signature,
       int memberOf: -1})
      : super(functionId, kind, arity, name, element, signature, memberOf),
        assembler = new BytecodeAssembler(arity) {
    assert(memberOf is int);
    assert(signature == null ||
        arity == (signature.parameterCount + (isInstanceMember ? 1 : 0)));
  }

  void reuse() {
    assembler.reuse();
    constants.clear();
    functionConstantValues.clear();
    classConstantValues.clear();
  }

  int allocateConstant(ConstantValue constant) {
    if (constant == null) throw "bad constant";
    return constants.putIfAbsent(constant, () => constants.length);
  }

  int allocateConstantFromFunction(int functionId) {
    DartinoFunctionConstant constant =
        functionConstantValues.putIfAbsent(
            functionId, () => new DartinoFunctionConstant(functionId));
    return allocateConstant(constant);
  }

  int allocateConstantFromClass(int classId) {
    DartinoClassConstant constant =
        classConstantValues.putIfAbsent(
            classId, () => new DartinoClassConstant(classId));
    return allocateConstant(constant);
  }

  DartinoFunction finalizeFunction(
      DartinoContext context,
      List<VmCommand> commands) {
    int constantCount = constants.length;
    for (int i = 0; i < constantCount; i++) {
      commands.add(const PushNull());
    }

    assert(assembler.bytecodes.last.opcode == Opcode.MethodEnd);

    commands.add(
        new PushNewFunction(
            assembler.functionArity,
            constantCount,
            assembler.bytecodes,
            assembler.catchRanges));

    commands.add(new PopToMap(MapId.methods, functionId));

    return new DartinoFunction(
        functionId,
        kind,
        arity,
        name,
        element,
        signature,
        assembler.bytecodes,
        createDartinoConstants(context),
        memberOf);
  }

  List<DartinoConstant> createDartinoConstants(DartinoContext context) {
    List<DartinoConstant> dartinoConstants = <DartinoConstant>[];

    constants.forEach((constant, int index) {
      if (constant is ConstantValue) {
        if (constant is DartinoFunctionConstant) {
          dartinoConstants.add(
              new DartinoConstant(constant.functionId, MapId.methods));
        } else if (constant is DartinoClassConstant) {
          dartinoConstants.add(
              new DartinoConstant(constant.classId, MapId.classes));
        } else {
          int id = context.lookupConstantIdByValue(constant);
          if (id == null) {
            throw "Unsupported constant: ${constant.toStructuredString()}";
          }
          dartinoConstants.add(
              new DartinoConstant(id, MapId.constants));
        }
      } else {
        throw "Unsupported constant: ${constant.runtimeType}";
      }
    });

    return dartinoConstants;
  }

  String verboseToString() {
    StringBuffer sb = new StringBuffer();

    sb.writeln("Function $functionId, Arity=${assembler.functionArity}");
    sb.writeln("Constants:");
    constants.forEach((constant, int index) {
      if (constant is ConstantValue) {
        constant = constant.toStructuredString();
      }
      sb.writeln("  #$index: $constant");
    });

    sb.writeln("Bytecodes (${assembler.byteSize} bytes):");
    Bytecode.prettyPrint(sb, assembler.bytecodes);

    return '$sb';
  }
}
