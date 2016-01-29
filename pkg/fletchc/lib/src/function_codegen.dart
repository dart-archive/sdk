// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.function_codegen;

import 'package:compiler/src/resolution/tree_elements.dart' show
    TreeElements;

import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/tree/tree.dart';

import 'fletch_context.dart';

import 'fletch_function_builder.dart' show
    FletchFunctionBuilder;

import 'fletch_registry.dart' show
    FletchRegistry;

import 'closure_environment.dart';

import 'codegen_visitor.dart';

class FunctionCodegen extends CodegenVisitor with FletchRegistryMixin {
  final FletchRegistry registry;
  int setterResultSlot;

  FunctionCodegen(FletchFunctionBuilder functionBuilder,
                  FletchContext context,
                  TreeElements elements,
                  this.registry,
                  ClosureEnvironment closureEnvironment,
                  FunctionElement function)
      : super(functionBuilder, context, elements,
              closureEnvironment, function);

  FunctionElement get function => element;

  // If the function is a setter, push the argument to later be returned.
  // TODO(ajohnsen): If the argument is semantically final, we don't have to
  // do this.
  bool get hasAssignmentSemantics =>
      function.isSetter || function.name == '[]=';

  void compile() {
    if (checkCompileError(function)) {
      assembler.methodEnd();
      return;
    }

    ClassElement enclosing = function.enclosingClass;
    // Generate implicit 'null' check for '==' functions.
    if (enclosing != null && function.name == '==') {
      BytecodeLabel notNull = new BytecodeLabel();
      assembler.loadParameter(1);
      assembler.loadLiteralNull();
      assembler.identicalNonNumeric();
      assembler.branchIfFalse(notNull);
      // TODO(ajohnsen): Consider creating an injected operator== into 'null',
      // to avoid this extra check.
      assembler.loadParameter(0);
      assembler.loadLiteralNull();
      assembler.identicalNonNumeric();
      assembler.ret();
      assembler.bind(notNull);
    }

    FunctionSignature functionSignature = function.functionSignature;
    int parameterCount = functionSignature.parameterCount;

    if (hasAssignmentSemantics) {
      setterResultSlot = assembler.stackSize;
      // The result is always the last argument.
      assembler.loadParameter(functionBuilder.arity - 1);
    }

    // Skip 'this' if present.
    int parameterIndex = functionBuilder.arity - parameterCount;

    functionSignature.orderedForEachParameter((ParameterElement parameter) {
      // For constructors, the argument is passed as boxed (from the initializer
      // inlining).
      LocalValue value = createLocalValueForParameter(
          parameter,
          parameterIndex,
          isCapturedValueBoxed: element.isGenerativeConstructor);
      pushVariableDeclaration(value);
      parameterIndex++;
    });

    ClosureInfo info = closureEnvironment.closures[function];
    if (info != null) {
      int index = 0;
      if (info.isThisFree) {
        thisValue = new UnboxedLocalValue(assembler.stackSize, null);
        assembler.loadParameter(0);
        assembler.loadField(index++);
      }
      for (LocalElement local in info.free) {
        pushVariableDeclaration(createLocalValueFor(local));
        // TODO(ajohnsen): Use a specialized helper for loading the closure.
        assembler.loadParameter(0);
        assembler.loadField(index++);
      }
    }

    FunctionExpression node = function.node;
    if (node != null) {
      node.body.accept(this);
    }

    // Emit implicit 'return null' if no terminator is present.
    if (!assembler.endsWithTerminator) generateImplicitReturn(node);

    assembler.methodEnd();
  }

  void generateImplicitReturn(FunctionExpression node) {
    if (hasAssignmentSemantics) {
      assembler.loadSlot(setterResultSlot);
      assembler.ret();
    } else {
      assembler.returnNull();
    }
  }

  void optionalReplaceResultValue() {
    if (hasAssignmentSemantics) {
      assembler.pop();
      assembler.loadSlot(setterResultSlot);
    }
  }
}
