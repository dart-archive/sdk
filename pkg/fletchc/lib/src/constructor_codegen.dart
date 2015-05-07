// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.constructor_codegen;

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

import 'lazy_field_initializer_codegen.dart';

import 'codegen_visitor.dart';

class ConstructorCodegen extends CodegenVisitor {
  final CompiledClass compiledClass;

  final Map<FieldElement, LocalValue> fieldScope = <FieldElement, LocalValue>{};

  final List<ConstructorElement> constructors = <ConstructorElement>[];

  ConstructorCodegen(CompiledFunction compiledFunction,
                     FletchContext context,
                     TreeElements elements,
                     Registry registry,
                     ClosureEnvironment closureEnvironment,
                     ConstructorElement constructor,
                     this.compiledClass)
      : super(compiledFunction, context, elements, registry,
              closureEnvironment, constructor);

  ConstructorElement get constructor => element;

  BytecodeBuilder get builder => compiledFunction.builder;

  void compile() {
    // Push all initial field values (including super-classes).
    pushInitialFieldValues(compiledClass);
    // The stack is now:
    //  Value for field-0
    //  ...
    //  Value for field-n
    //
    FunctionSignature signature = constructor.functionSignature;
    int parameterCount = signature.parameterCount;

    // Visit constructor and evaluate initializers and super calls. The
    // arguments to the constructor are located before the return address.
    inlineInitializers(constructor, -parameterCount - 1);

    handleAllocationAndBodyCall();
  }

  LazyFieldInitializerCodegen lazyFieldInitializerCodegenFor(
      CompiledFunction function,
      FieldElement field) {
    TreeElements elements = field.resolvedAst.elements;
    return new LazyFieldInitializerCodegen(
        function,
        context,
        elements,
        registry,
        context.backend.createClosureEnvironment(field, elements),
        field);
  }

  void handleAllocationAndBodyCall() {
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
    // TODO(ajohnsen): Set immutable for all-final classes.
    builder.allocate(classConstant, fields, immutable: element.isConst);

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
    if (checkCompileError(constructor) ||
        checkCompileError(constructor.enclosingClass)) {
      return;
    }

    if (constructors.indexOf(constructor) >= 0) {
      internalError(constructor.node,
                    "Multiple visits to the same constructor");
    }

    if (constructor.isSynthesized) {
      // If the constructor is implicit, invoke the defining constructor.
      if (constructor.functionSignature.parameterCount == 0) {
        ConstructorElement defining = constructor.definingConstructor;
        int initSlot = builder.stackSize;
        loadArguments(new NodeList.empty(), defining);
        inlineInitializers(defining, initSlot);
        return;
      }

      // Otherwise the constructor is synthesized in the context of mixin
      // applications, use the defining constructor.
      do {
        constructor = constructor.definingConstructor;
      } while (constructor.isSynthesized);
    }

    constructors.add(constructor);
    FunctionSignature signature = constructor.functionSignature;
    int parameterIndex = 0;

    // Visit parameters and add them to scope. Note the scope is the scope of
    // locals, in VisitingCodegen.
    signature.orderedForEachParameter((ParameterElement parameter) {
      int slot = firstParameterSlot + parameterIndex;
      LocalValue value = createLocalValueForParameter(parameter, slot);
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

  void handleThisPropertySet(Send node) {
    Element element = elements[node];
    fieldScope[element].store(builder);
  }

  // This is called for each initializer list assignment.
  void visitThisPropertySet(
      Send node,
      Selector selector,
      Node rhs,
      _) {
    visitForValue(rhs);
    handleThisPropertySet(node);
    applyVisitState();
  }

  void callConstructorBody(ConstructorElement constructor) {
    FunctionExpression node = constructor.node;
    if (node == null || node.body.asEmptyStatement() != null) return;

    registerStaticInvocation(constructor.declaration);

    int methodId = context.backend.functionMethodId(constructor);
    int constructorId = compiledFunction.allocateConstantFromFunction(methodId);

    FunctionSignature signature = constructor.functionSignature;

    // Prepare for constructor body invoke.
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
      pushInitialFieldValues(compiledClass.superclass);
    }
    int fieldIndex = compiledClass.superclassFields;
    ClassElement classElement = compiledClass.element.implementation;
    classElement.forEachInstanceField((_, FieldElement field) {
      fieldScope[field] = new UnboxedLocalValue(fieldIndex++, field);
      Expression initializer = field.initializer;
      if (initializer == null) {
        builder.loadLiteralNull();
      } else {
        // Create a LazyFieldInitializerCodegen for compiling the initializer.
        // Note that we reuse the compiledFunction, to inline it into the
        // constructor.
        LazyFieldInitializerCodegen codegen =
            lazyFieldInitializerCodegenFor(compiledFunction, field);

        // We only want the value of the actual initializer, not the usual
        // 'body'.
        codegen.visitForValue(initializer);
      }
    });
  }
}
