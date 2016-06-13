// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.parameter_stub_codegen;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue;

import 'package:compiler/src/elements/elements.dart' show
    ExecutableElement,
    ParameterElement;

import 'package:compiler/src/tree/tree.dart' show
    Expression;

import 'package:compiler/src/universe/selector.dart' show
    Selector;

import '../dartino_system.dart' show
    DartinoFunctionBase,
    ParameterStubSignature;

import 'codegen_visitor.dart' show
    CodegenVisitor,
    DartinoRegistryMixin;

import 'dartino_context.dart' show
    DartinoContext;

import 'dartino_function_builder.dart' show
    DartinoFunctionBuilder;

import 'dartino_registry.dart' show
    DartinoRegistry;

class ParameterStubCodegen extends CodegenVisitor with DartinoRegistryMixin {
  final DartinoRegistry registry;
  final DartinoFunctionBase function;
  final Selector selector;
  final ParameterStubSignature signature;
  final int arity;

  ParameterStubCodegen(
      DartinoFunctionBuilder functionBuilder,
      DartinoContext context,
      this.registry,
      ExecutableElement element,
      this.function,
      this.selector,
      this.signature,
      this.arity)
      : super(functionBuilder, context, null, null, element);

  void loadInitializerOrNull(ParameterElement parameter) {
    Expression initializer = parameter.initializer;
    if (initializer != null) {
      ConstantValue value = evaluateAndUseConstant(
          initializer, elements: parameter.memberContext.resolvedAst.elements,
          isConst: true);
      int constId = functionBuilder.allocateConstant(value);
      assembler.loadConst(constId);
    } else {
      assembler.loadLiteralNull();
    }
  }

  void compile() {
    // Load this.
    if (function.isInstanceMember) assembler.loadParameter(0);

    int index = function.isInstanceMember ? 1 : 0;
    function.signature.orderedForEachParameter((ParameterElement parameter) {
      if (checkCompileError(parameter)) return;
      if (!parameter.isOptional) {
        assembler.loadParameter(index);
      } else if (parameter.isNamed) {
        int parameterIndex = selector.namedArguments.indexOf(parameter.name);
        if (parameterIndex >= 0) {
          if (function.isInstanceMember) parameterIndex++;
          int position = selector.positionalArgumentCount + parameterIndex;
          assembler.loadParameter(position);
        } else {
          loadInitializerOrNull(parameter);
        }
      } else {
        if (index < arity) {
          assembler.loadParameter(index);
        } else {
          loadInitializerOrNull(parameter);
        }
      }
      index++;
    });

    // TODO(ajohnsen): We have to be extra careful when overriding a
    // method that takes optional arguments. We really should
    // enumerate all the stubs in the superclasses and make sure
    // they're overridden.
    int constId =
        functionBuilder.allocateConstantFromFunction(function.functionId);
    assembler
        ..invokeStatic(constId, index)
        ..ret()
        ..methodEnd();

    systemBase.registerParameterStub(function, signature, functionBuilder);
  }
}
