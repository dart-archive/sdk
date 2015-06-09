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

import 'compiled_class.dart' show
    CompiledClass;

import 'closure_environment.dart';

import 'lazy_field_initializer_codegen.dart';

import 'codegen_visitor.dart';

class ConstructorCodegen extends CodegenVisitor {
  final CompiledClass compiledClass;

  final Map<FieldElement, LocalValue> fieldScope = <FieldElement, LocalValue>{};

  final List<ConstructorElement> constructors = <ConstructorElement>[];

  TreeElements initializerElements;

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

  TreeElements get elements {
    if (initializerElements != null) return initializerElements;
    return super.elements;
  }

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
        loadArguments(defining, new NodeList.empty(), CallStructure.NO_ARGS);
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

    initializerElements = constructor.resolvedAst.elements;
    visitInitializers(constructor.node, null);
  }

  void doFieldInitializerSet(Send node, FieldElement field) {
    fieldScope[field].store(builder);
    applyVisitState();
  }

  // This is called for each initializer list assignment.
  void visitFieldInitializer(
      SendSet node,
      FieldElement field,
      Node initializer,
      _) {
    // We only want the value of the actual initializer, not the usual
    // 'body'.
    visitForValue(initializer);
    doFieldInitializerSet(node, field);
  }

  void visitSuperConstructorInvoke(
      Send node,
      ConstructorElement superConstructor,
      InterfaceType type,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    // Load all parameters to the constructor, onto the stack.
    loadArguments(superConstructor, arguments, callStructure);
    int initSlot = builder.stackSize -
        superConstructor.functionSignature.parameterCount;
    var previous = initializerElements;
    inlineInitializers(superConstructor, initSlot);
    initializerElements = previous;
  }

  void visitThisConstructorInvoke(
      Send node,
      ConstructorElement thisConstructor,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    // TODO(ajohnsen): Is this correct behavior?
    thisConstructor = thisConstructor.implementation;
    // Load all parameters to the constructor, onto the stack.
    loadArguments(thisConstructor, arguments, callStructure);
    int initSlot = builder.stackSize -
        thisConstructor.functionSignature.parameterCount;
    var previous = initializerElements;
    inlineInitializers(thisConstructor, initSlot);
    initializerElements = previous;
  }

  void visitImplicitSuperConstructorInvoke(
      FunctionExpression node,
      ConstructorElement superConstructor,
      InterfaceType type,
      _) {
    int initSlot = builder.stackSize;
    // Always load arguments, as the super-constructor may have optional
    // parameters.
    loadArguments(
        superConstructor, new NodeList.empty(), CallStructure.NO_ARGS);
    inlineInitializers(superConstructor, initSlot);
  }

  /**
   * Load the [arguments] for caling [constructor].
   *
   * Return the number of arguments pushed onto the stack.
   */
  int loadArguments(
      ConstructorElement constructor,
      NodeList arguments,
      CallStructure callStructure) {
    FunctionSignature signature = constructor.functionSignature;
    if (!signature.hasOptionalParameters ||
        !signature.optionalParametersAreNamed ||
        callStructure.namedArgumentCount == 0) {
      return loadPositionalArguments(arguments, signature, constructor.name);
    }

    int argumentCount = callStructure.argumentCount;
    int namedArgumentCount = callStructure.namedArgumentCount;

    Iterator<Node> it = arguments.iterator;
    int unnamedArguments = argumentCount - namedArgumentCount;
    for (int i = 0; i < unnamedArguments; i++) {
      it.moveNext();
      visitForValue(it.current);
    }

    bool directMatch = namedArgumentCount == signature.optionalParameterCount;
    Map<String, int> namedArguments = <String, int>{};
    for (int i = 0; i < namedArgumentCount; i++) {
      String name = callStructure.namedArguments[i];
      namedArguments[name] = builder.stackSize;
      it.moveNext();
      visitForValue(it.current);
      if (signature.orderedOptionalParameters[i].name != name) {
        directMatch = false;
      }
    }
    if (directMatch) return argumentCount;

    // There was no direct match. Push all unnamed arguments and all named
    // arguments that have already been evaluated, in signature order.
    for (int i = 0; i < unnamedArguments; i++) {
      builder.loadLocal(argumentCount);
    }

    int count = 0;
    for (ParameterElement parameter in signature.orderedOptionalParameters) {
      int slot = namedArguments[parameter.name];
      if (slot != null) {
        builder.loadSlot(slot);
      } else {
        doParameterInitializer(parameter);
      }
      count++;
    }

    // Some parameters may have defaulted to default value, making the
    // parameter count larger than the argument count.
    return argumentCount + signature.parameterCount;
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
