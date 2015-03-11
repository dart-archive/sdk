// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.constructor_compiler;

import 'package:compiler/src/constants/expressions.dart' show
    ConstantExpression;

import 'package:compiler/src/dart2jslib.dart' show
    MessageKind,
    Registry;

import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/resolution/resolution.dart';
import 'package:compiler/src/tree/tree.dart';
import 'package:compiler/src/universe/universe.dart';
import 'package:compiler/src/util/util.dart' show Spannable;
import 'package:compiler/src/dart_types.dart';

import 'fletch_context.dart';

import 'fletch_backend.dart';

import 'fletch_constants.dart' show
    CompiledFunctionConstant,
    FletchClassConstant;

import '../bytecodes.dart' show
    Bytecode;

import 'compiled_function.dart' show
    CompiledFunction;

import 'function_compiler.dart';

// TODO(ajohnsen): Extend SemanticVisitor instead of FunctionCompiler?
class ConstructorCompiler extends FunctionCompiler {
  final CompiledClass compiledClass;

  final Map<FieldElement, int> fieldScope = <FieldElement, int>{};

  ConstructorCompiler(int methodId,
                      FletchContext context,
                      TreeElements elements,
                      Registry registry,
                      ConstructorElement constructor,
                      this.compiledClass)
      : super.forFactory(methodId, context, elements, registry, constructor);

  BytecodeBuilder get builder => compiledFunction.builder;

  void compile() {
    // Push all initial field values (including super-classes).
    pushInitialFieldValues(compiledClass);
    // The stack is now:
    //  Initial value for field-0
    //  ...
    //  Initial value for field-n

    FunctionSignature signature = function.functionSignature;

    int parameterCount = signature.parameterCount;

    int parameterIndex = 0;
    // Load all parameters to the constructor, onto the stack.
    signature.orderedForEachParameter((FormalElement parameter) {
      builder.loadParameter(parameterIndex++);
      if (parameter.isInitializingFormal) {
        // If it's a initializing formal, also store the value into initial
        // field value.
        builder.storeSlot(fieldScope[parameter.fieldElement]);
      }
    });

    // The stack is now:
    //  field-0
    //  ...
    //  field-n
    //  parameter-0
    //  ...
    //  parameter-m

    int classConstant = compiledFunction.allocateConstantFromClass(
        compiledClass.element);
    int methodId = context.backend.allocateMethodId(function);
    int constructorId = compiledFunction.allocateConstantFromFunction(methodId);

    int fields = compiledClass.fields;

    // TODO(ajohnsen): Let allocate take an offset to the field stack, so we
    // don't have to copy all the fields?
    // Copy all the fields to the end of the stack.
    for (int i = 0; i < fields; i++) {
      builder.loadSlot(i);
    }

    // The stack is now:
    //  field-0
    //  ...
    //  field-n
    //  parameter-0
    //  ...
    //  parameter-m
    //  field-0
    //  ...
    //  field-n

    // Create the actual instance.
    builder.allocate(classConstant, fields);

    // The stack is now:
    //  field-0
    //  ...
    //  field-n
    //  parameter-0
    //  ...
    //  parameter-m
    //  instance

    // Prepate for constructor body invoke.
    builder.dup();
    for (int i = 0; i < parameterCount; i++) {
      builder.loadSlot(fields + i);
    }

    // The stack is now:
    //  field-0
    //  ...
    //  field-n
    //  parameter-0
    //  ...
    //  parameter-m
    //  instance
    //  instance
    //  parameter-0
    //  ...
    //  parameter-m

    // Invoke the constructor body.
    builder
        ..invokeStatic(constructorId, 1 + parameterCount)
        ..pop();

    // Return the instance.
    builder
        ..ret()
        ..methodEnd();
  }

  void pushInitialFieldValues(CompiledClass compiledClass) {
    if (compiledClass.hasSuperClass) {
      pushInitialFieldValues(compiledClass.superClass);
    }
    int fieldIndex = compiledClass.superClassFields;
    compiledClass.element.forEachInstanceField((_, FieldElement field) {
      fieldScope[field] = fieldIndex++;
      Expression initializer = field.initializer;
      if (initializer == null) {
        builder.loadLiteralNull();
      } else {
        visitForValue(initializer);
      }
    });
  }
}
