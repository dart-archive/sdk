// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.function_codegen;

import 'package:compiler/src/dart2jslib.dart' show
    MessageKind,
    Registry;

import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/resolution/resolution.dart';
import 'package:compiler/src/tree/tree.dart';

import 'fletch_context.dart';

import 'compiled_function.dart' show
    CompiledFunction;

import 'closure_environment.dart';

import 'codegen_visitor.dart';

class FunctionCodegen extends CodegenVisitor {

  int setterResultSlot;

  FunctionCodegen(CompiledFunction compiledFunction,
                  FletchContext context,
                  TreeElements elements,
                  Registry registry,
                  ClosureEnvironment closureEnvironment,
                  FunctionElement function)
      : super(compiledFunction, context, elements, registry,
              closureEnvironment, function);

  FunctionElement get function => element;

  // If the function is a setter, push the argument to later be returned.
  // TODO(ajohnsen): If the argument is semantically final, we don't have to
  // do this.
  bool get hasAssignmentSemantics => function.isSetter || function.name == '[]=';

  void compile() {
    checkCompileError(function);

    ClassElement enclosing = function.enclosingClass;
    // Generate implicit 'null' check for '==' functions, except for Null.
    if (enclosing != null &&
        enclosing.declaration != context.compiler.nullClass &&
        function.name == '==') {
      BytecodeLabel notNull = new BytecodeLabel();
      builder.loadParameter(1);
      builder.loadLiteralNull();
      builder.identicalNonNumeric();
      builder.branchIfFalse(notNull);
      builder.loadLiteralFalse();
      builder.ret();
      builder.bind(notNull);
    }

    FunctionSignature functionSignature = function.functionSignature;
    int parameterCount = functionSignature.parameterCount;

    if (hasAssignmentSemantics) {
      setterResultSlot = builder.stackSize;
      // The result is always the last argument (-1 for return address, -1 for
      // last parameter).
      builder.loadSlot(-2);
    }

    int i = 0;
    functionSignature.orderedForEachParameter((ParameterElement parameter) {
      int slot = i++ - parameterCount - 1;
      LocalValue value = createLocalValueForParameter(parameter, slot);
      pushVariableDeclaration(value);
    });

    ClosureInfo info = closureEnvironment.closures[function];
    if (info != null) {
      int index = 0;
      if (info.isThisFree) {
        thisValue = new UnboxedLocalValue(builder.stackSize, null);
        builder.loadParameter(0);
        builder.loadField(index++);
      }
      for (LocalElement local in info.free) {
        pushVariableDeclaration(createLocalValueFor(local));
        // TODO(ajohnsen): Use a specialized helper for loading the closure.
        builder.loadParameter(0);
        builder.loadField(index++);
      }
    }

    FunctionExpression node = function.node;
    if (node != null) {
      node.body.accept(this);
    }

    // Emit implicit 'return null' if no terminator is present.
    if (!builder.endsWithTerminator) {
      if (hasAssignmentSemantics) {
        builder.loadSlot(setterResultSlot);
      } else {
        builder.loadLiteralNull();
      }
      builder.ret();
    }

    builder.methodEnd();
  }

  void optionalReplaceResultValue() {
    if (hasAssignmentSemantics) {
      builder.pop();
      builder.loadSlot(setterResultSlot);
    }
  }
}
