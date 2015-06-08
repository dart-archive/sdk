// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.compiled_function;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue;

import 'package:compiler/src/constants/expressions.dart' show
    ConstantExpression;

import 'package:compiler/src/tree/tree.dart' show
    Expression;

import 'package:compiler/src/elements/elements.dart';

import 'fletch_constants.dart' show
    FletchFunctionConstant,
    FletchClassConstant;

import 'package:compiler/src/universe/universe.dart'
    show Selector;

import '../bytecodes.dart' show
    Bytecode;

import 'fletch_backend.dart' show
    CompiledClass;

import 'fletch_context.dart';
import 'bytecode_builder.dart';
import 'debug_info.dart';

enum CompiledFunctionKind {
  NORMAL,
  LAZY_FIELD_INITIALIZER,
  INITIALIZER_LIST,
  PARAMETER_STUB,
  ACCESSOR
}

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
  final String name;
  final Element element;
  final Map<ConstantValue, int> constants = <ConstantValue, int>{};
  final Map<int, ConstantValue> functionConstantValues = <int, ConstantValue>{};
  final Map<int, ConstantValue> classConstantValues = <int, ConstantValue>{};
  final Map<Selector, CompiledFunction> parameterMappings =
      <Selector, CompiledFunction>{};
  final int arity;
  final CompiledFunctionKind kind;

  DebugInfo debugInfo;

  CompiledFunction(this.methodId,
                   this.name,
                   this.element,
                   FunctionSignature signature,
                   CompiledClass memberOf,
                   {this.kind: CompiledFunctionKind.NORMAL})
      : this.signature = signature,
        this.memberOf = memberOf,
        arity = signature.parameterCount + (memberOf != null ? 1 : 0),
        builder = new BytecodeBuilder(
          signature.parameterCount + (memberOf != null ? 1 : 0));

  CompiledFunction.normal(this.methodId, int argumentCount)
      : arity = argumentCount,
        builder = new BytecodeBuilder(argumentCount),
        kind = CompiledFunctionKind.NORMAL;

  CompiledFunction.lazyInit(this.methodId,
                            this.name,
                            this.element,
                            int argumentCount)
      : arity = argumentCount,
        builder = new BytecodeBuilder(argumentCount),
        kind = CompiledFunctionKind.LAZY_FIELD_INITIALIZER;

  CompiledFunction.parameterStub(this.methodId, int argumentCount)
      : arity = argumentCount,
        builder = new BytecodeBuilder(argumentCount),
        kind = CompiledFunctionKind.PARAMETER_STUB;

  CompiledFunction.accessor(this.methodId, bool setter)
      : arity = setter ? 2 : 1,
        builder = new BytecodeBuilder(setter ? 2 : 1),
        kind = CompiledFunctionKind.ACCESSOR;

  void reuse() {
    builder.reuse();
    constants.clear();
    functionConstantValues.clear();
    classConstantValues.clear();
  }

  bool get hasThisArgument => memberOf != null;

  bool get isLazyFieldInitializer {
    return kind == CompiledFunctionKind.LAZY_FIELD_INITIALIZER;
  }

  bool get isInitializerList {
    return kind == CompiledFunctionKind.INITIALIZER_LIST;
  }

  bool get isAccessor {
    return kind == CompiledFunctionKind.ACCESSOR;
  }

  bool get isParameterStub {
    return kind == CompiledFunctionKind.PARAMETER_STUB;
  }

  bool get isConstructor => element != null && element.isConstructor;

  int allocateConstant(ConstantValue constant) {
    if (constant == null) throw "bad constant";
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

  // TODO(ajohnsen): Remove this function when usage is avoided in
  // FletchBackend.
  void copyFrom(CompiledFunction function) {
    builder.bytecodes.addAll(function.builder.bytecodes);
    builder.catchRanges.addAll(function.builder.catchRanges);
    constants.addAll(function.constants);
    functionConstantValues.addAll(function.functionConstantValues);
    classConstantValues.addAll(function.classConstantValues);
  }

  bool matchesSelector(Selector selector) {
    if (!canBeCalledAs(selector)) return false;
    if (selector.namedArguments.length != signature.optionalParameterCount) {
      return false;
    }
    int index = 0;
    bool match = true;
    for (var parameter in signature.orderedOptionalParameters) {
      if (parameter.name != selector.namedArguments[index++]) match = false;
    }
    return match;
  }

  // TODO(ajohnsen): Remove and use the one one Selector, when it takes a
  // FunctionSignature directly.
  // This is raw copy of Selector.signaturesApplies.
  bool canBeCalledAs(Selector selector) {
    if (selector.argumentCount > signature.parameterCount) return false;
    int requiredParameterCount = signature.requiredParameterCount;
    int optionalParameterCount = signature.optionalParameterCount;
    if (selector.positionalArgumentCount < requiredParameterCount) return false;

    if (!signature.optionalParametersAreNamed) {
      // We have already checked that the number of arguments are
      // not greater than the number of signature. Therefore the
      // number of positional arguments are not greater than the
      // number of signature.
      assert(selector.positionalArgumentCount <= signature.parameterCount);
      return selector.namedArguments.isEmpty;
    } else {
      if (selector.positionalArgumentCount > requiredParameterCount) {
        return false;
      }
      assert(selector.positionalArgumentCount == requiredParameterCount);
      if (selector.namedArgumentCount > optionalParameterCount) return false;
      Set<String> nameSet = new Set<String>();
      signature.optionalParameters.forEach((Element element) {
        nameSet.add(element.name);
      });
      for (String name in selector.namedArguments) {
        if (!nameSet.contains(name)) return false;
        // TODO(5213): By removing from the set we are checking
        // that we are not passing the name twice. We should have this
        // check in the resolver also.
        nameSet.remove(name);
      }
      return true;
    }
  }

  CompiledFunction createParameterMappingFor(
      Selector selector,
      FletchContext context) {
    return parameterMappings.putIfAbsent(selector, () {
      assert(canBeCalledAs(selector));
      int arity = selector.argumentCount;
      if (hasThisArgument) arity++;

      CompiledFunction compiledFunction = new CompiledFunction.parameterStub(
          context.backend.functions.length,
          arity);
      context.backend.functions.add(compiledFunction);

      BytecodeBuilder builder = compiledFunction.builder;

      void loadInitializerOrNull(ParameterElement parameter) {
        Expression initializer = parameter.initializer;
        if (initializer != null) {
          ConstantExpression expression = context.compileConstant(
              initializer,
              parameter.memberContext.resolvedAst.elements,
              isConst: true);
          int constId = compiledFunction.allocateConstant(
              context.getConstantValue(expression));
          builder.loadConst(constId);
        } else {
          builder.loadLiteralNull();
        }
      }

      // Load this.
      if (hasThisArgument) builder.loadParameter(0);

      int index = hasThisArgument ? 1 : 0;
      signature.orderedForEachParameter((ParameterElement parameter) {
        if (!parameter.isOptional) {
          builder.loadParameter(index);
        } else if (parameter.isNamed) {
          int parameterIndex = selector.namedArguments.indexOf(parameter.name);
          if (parameterIndex >= 0) {
            if (hasThisArgument) parameterIndex++;
            int position = selector.positionalArgumentCount + parameterIndex;
            builder.loadParameter(position);
          } else {
            loadInitializerOrNull(parameter);
          }
        } else {
          if (index < arity) {
            builder.loadParameter(index);
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
      int constId = compiledFunction.allocateConstantFromFunction(methodId);
      builder
          ..invokeStatic(constId, index)
          ..ret()
          ..methodEnd();

      if (memberOf != null) {
        int fletchSelector = context.toFletchSelector(selector);
        memberOf.methodTable[fletchSelector] = compiledFunction.methodId;
      }

      return compiledFunction;
    });
  }

  String verboseToString() {
    StringBuffer sb = new StringBuffer();

    sb.writeln("Method $methodId, Arity=${builder.functionArity}");
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
