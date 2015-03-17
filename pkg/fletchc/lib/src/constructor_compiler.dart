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

import 'closure_environment.dart';

import 'function_compiler.dart';

// TODO(ajohnsen): Extend SemanticVisitor instead of FunctionCompiler?
class ConstructorCompiler extends FunctionCompiler {
  final CompiledClass compiledClass;

  final Map<FieldElement, LocalValue> fieldScope = <FieldElement, LocalValue>{};

  final List<ConstructorElement> constructors = <ConstructorElement>[];

  ConstructorCompiler(CompiledFunction compiledFunction,
                      FletchContext context,
                      TreeElements elements,
                      Registry registry,
                      ClosureEnvironment closureEnvironment,
                      ConstructorElement constructor,
                      this.compiledClass)
      : super.forFactory(compiledFunction, context, elements, registry,
                         closureEnvironment, constructor);

  BytecodeBuilder get builder => compiledFunction.builder;

  void compile() {
    // Push all initial field values (including super-classes).
    pushInitialFieldValues(compiledClass);
    // The stack is now:
    //  Value for field-0
    //  ...
    //  Value for field-n
    //
    FunctionSignature signature = function.functionSignature;
    int parameterCount = signature.parameterCount;

    // Visit constructor and evaluate initializers and super calls. The
    // arguments to the constructor are located before the return address.
    inlineInitializers(function, -parameterCount - 1);

    // TODO(ajohnsen): Let allocate take an offset to the field stack, so we
    // don't have to copy all the fields?
    // Copy all the fields to the end of the stack.
    int fields = compiledClass.fields;
    for (int i = 0; i < fields; i++) {
      builder.loadSlot(i);
    }

    // The stack is now:
    //  Value for field-0
    //  ...
    //  Value for field-n
    //  [super arguments]
    //  Value for field-0
    //  ...
    //  Value for field-n

    // Create the actual instance.
    int classConstant = compiledFunction.allocateConstantFromClass(
        compiledClass.id);
    builder.allocate(classConstant, fields);

    // The stack is now:
    //  Value for field-0
    //  ...
    //  Value for field-n
    //  [super arguments]
    //  instance

    // Call constructor bodies in reverse order.
    for (int i = constructors.length - 1; i >= 0; i--) {
      callConstructorBody(constructors[i]);
    }

    // Return the instance.
    builder
        ..ret()
        ..methodEnd();
  }

  /**
   * Visit [constructor] and inline initializers and super calls, recursively.
   */
  void inlineInitializers(
      ConstructorElement constructor,
      int firstParameterSlot) {
    if (constructors.indexOf(constructor) >= 0) {
      internalError(constructor.node,
                    "Multiple visits to the same constructor");
    }

    constructors.add(constructor);
    FunctionSignature signature = constructor.functionSignature;
    int parameterIndex = 0;

    // Visit parameters and add them to scope. Note the scope is the scope of
    // locals, in FunctionCompiler.
    signature.orderedForEachParameter((ParameterElement parameter) {
      int slot = firstParameterSlot + parameterIndex;
      // TODO(ajohnsen): Validate that we handle boxed parameters correctly.
      LocalValue value = createLocalValueFor(parameter, slot);
      scope[parameter] = value;
      if (parameter.isInitializingFormal) {
        // If it's a initializing formal, store the value into initial
        // field value.
        InitializingFormalElement formal = parameter;
        value.load(builder);
        fieldScope[formal.fieldElement].store(builder);
        builder.pop();
      }
      parameterIndex++;
    });

    // Now the parameters are in the scope, visit the constructor initializers.
    FunctionExpression node = constructor.node;
    if (node == null) return;
    NodeList initializers = node.initializers;
    if (initializers == null) return;
    for (var initializer in initializers) {
      Element element = elements[initializer];
      if (element.isGenerativeConstructor) {
        // TODO(ajohnsen): Handle named arguments.
        // Load all parameters to the constructor, onto the stack.
        int initSlot = builder.stackSize;
        loadArguments(initializer.argumentsNode, element);
        inlineInitializers(element, initSlot);
      } else {
        // An initializer is a SendSet, leaving a value on the stack. Be sure to
        // pop it by visiting for effect.
        visitForEffect(initializer);
      }
    }
  }

  // This is called for each initializer list assignment.
  void visitThisPropertySet(
      Send node,
      Selector selector,
      Node rhs,
      _) {
    visitForValue(rhs);
    Element element = elements[node];
    fieldScope[element].store(builder);
    applyVisitState();
  }

  void callConstructorBody(ConstructorElement constructor) {
    FunctionExpression node = constructor.node;
    if (node == null || node.body.asEmptyStatement() != null) return;

    registry.registerStaticInvocation(constructor);

    int methodId = context.backend.allocateMethodId(constructor);
    int constructorId = compiledFunction.allocateConstantFromFunction(methodId);

    FunctionSignature signature = constructor.functionSignature;

    // Prepate for constructor body invoke.
    builder.dup();
    signature.orderedForEachParameter((FormalElement parameter) {
      scope[parameter].load(builder);
    });

    builder
        ..invokeStatic(constructorId, 1 + signature.parameterCount)
        ..pop();
  }

  void pushInitialFieldValues(CompiledClass compiledClass) {
    if (compiledClass.hasSuperClass) {
      pushInitialFieldValues(compiledClass.superClass);
    }
    int fieldIndex = compiledClass.superClassFields;
    compiledClass.element.forEachInstanceField((_, FieldElement field) {
      fieldScope[field] = new UnboxedLocalValue(fieldIndex++, field);
      Expression initializer = field.initializer;
      if (initializer == null) {
        builder.loadLiteralNull();
      } else {
        visitForValue(initializer);
      }
    });
  }
}
