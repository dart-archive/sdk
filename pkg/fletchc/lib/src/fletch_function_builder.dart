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
    Bytecode,
    Opcode;

import 'fletch_class_builder.dart' show
    FletchClassBuilder;

import 'fletch_context.dart';
import 'bytecode_assembler.dart';
import 'debug_info.dart';

import '../fletch_system.dart';
import '../commands.dart';

enum FletchFunctionBuilderKind {
  NORMAL,
  LAZY_FIELD_INITIALIZER,
  INITIALIZER_LIST,
  PARAMETER_STUB,
  ACCESSOR
}

class FletchFunctionBuilder {
  final BytecodeAssembler assembler;
  final int methodId;

  /**
   * The signature of the FletchFunctionBuilder.
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
  final FletchClassBuilder memberOf;
  final String name;
  final Element element;
  final Map<ConstantValue, int> constants = <ConstantValue, int>{};
  final Map<int, ConstantValue> functionConstantValues = <int, ConstantValue>{};
  final Map<int, ConstantValue> classConstantValues = <int, ConstantValue>{};
  final Map<Selector, FletchFunctionBuilder> parameterMappings =
      <Selector, FletchFunctionBuilder>{};
  final int arity;
  final FletchFunctionBuilderKind kind;

  DebugInfo debugInfo;

  FletchFunctionBuilder(
      this.methodId,
      this.name,
      this.element,
      FunctionSignature signature,
      FletchClassBuilder memberOf,
      {this.kind: FletchFunctionBuilderKind.NORMAL})
      : this.signature = signature,
        this.memberOf = memberOf,
        arity = signature.parameterCount + (memberOf != null ? 1 : 0),
        assembler = new BytecodeAssembler(
          signature.parameterCount + (memberOf != null ? 1 : 0));

  FletchFunctionBuilder.normal(this.methodId, int argumentCount)
      : arity = argumentCount,
        assembler = new BytecodeAssembler(argumentCount),
        kind = FletchFunctionBuilderKind.NORMAL;

  FletchFunctionBuilder.lazyInit(
      this.methodId,
      this.name,
      this.element,
      int argumentCount)
      : arity = argumentCount,
        assembler = new BytecodeAssembler(argumentCount),
        kind = FletchFunctionBuilderKind.LAZY_FIELD_INITIALIZER;

  FletchFunctionBuilder.parameterStub(this.methodId, int argumentCount)
      : arity = argumentCount,
        assembler = new BytecodeAssembler(argumentCount),
        kind = FletchFunctionBuilderKind.PARAMETER_STUB;

  FletchFunctionBuilder.accessor(this.methodId, bool setter)
      : arity = setter ? 2 : 1,
        assembler = new BytecodeAssembler(setter ? 2 : 1),
        kind = FletchFunctionBuilderKind.ACCESSOR;

  void reuse() {
    assembler.reuse();
    constants.clear();
    functionConstantValues.clear();
    classConstantValues.clear();
  }

  bool get hasThisArgument => memberOf != null;

  bool get hasMemberOf => memberOf != null;

  bool get isLazyFieldInitializer {
    return kind == FletchFunctionBuilderKind.LAZY_FIELD_INITIALIZER;
  }

  bool get isInitializerList {
    return kind == FletchFunctionBuilderKind.INITIALIZER_LIST;
  }

  bool get isAccessor {
    return kind == FletchFunctionBuilderKind.ACCESSOR;
  }

  bool get isParameterStub {
    return kind == FletchFunctionBuilderKind.PARAMETER_STUB;
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
  void copyFrom(FletchFunctionBuilder function) {
    assembler.bytecodes.addAll(function.assembler.bytecodes);
    assembler.catchRanges.addAll(function.assembler.catchRanges);
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

  FletchFunctionBuilder createParameterMappingFor(
      Selector selector,
      FletchContext context) {
    return parameterMappings.putIfAbsent(selector, () {
      assert(canBeCalledAs(selector));
      int arity = selector.argumentCount;
      if (hasThisArgument) arity++;

      FletchFunctionBuilder functionBuilder =
          new FletchFunctionBuilder.parameterStub(
              context.backend.functions.length,
              arity);
      context.backend.functions.add(functionBuilder);

      BytecodeAssembler assembler = functionBuilder.assembler;

      void loadInitializerOrNull(ParameterElement parameter) {
        Expression initializer = parameter.initializer;
        if (initializer != null) {
          ConstantExpression expression = context.compileConstant(
              initializer,
              parameter.memberContext.resolvedAst.elements,
              isConst: true);
          int constId = functionBuilder.allocateConstant(
              context.getConstantValue(expression));
          assembler.loadConst(constId);
        } else {
          assembler.loadLiteralNull();
        }
      }

      // Load this.
      if (hasThisArgument) assembler.loadParameter(0);

      int index = hasThisArgument ? 1 : 0;
      signature.orderedForEachParameter((ParameterElement parameter) {
        if (!parameter.isOptional) {
          assembler.loadParameter(index);
        } else if (parameter.isNamed) {
          int parameterIndex = selector.namedArguments.indexOf(parameter.name);
          if (parameterIndex >= 0) {
            if (hasThisArgument) parameterIndex++;
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
      int constId = functionBuilder.allocateConstantFromFunction(methodId);
      assembler
          ..invokeStatic(constId, index)
          ..ret()
          ..methodEnd();

      if (hasMemberOf) {
        int fletchSelector = context.toFletchSelector(selector);
        memberOf.addToMethodTable(fletchSelector, functionBuilder);
      }

      return functionBuilder;
    });
  }

  FletchFunction finalizeFunction(
      FletchContext context,
      List<Command> commands) {
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

    commands.add(new PopToMap(MapId.methods, methodId));

    return new FletchFunction(
        methodId,
        name,
        assembler.bytecodes,
        createFletchConstants(context),
        hasMemberOf ? memberOf.classId : -1);
  }

  List<FletchConstant> createFletchConstants(FletchContext context) {
    List<FletchConstant> fletchConstants = <FletchConstant>[];

    constants.forEach((constant, int index) {
      if (constant is ConstantValue) {
        if (constant is FletchFunctionConstant) {
          fletchConstants.add(
              new FletchConstant(constant.methodId, MapId.methods));
        } else if (constant is FletchClassConstant) {
          fletchConstants.add(
              new FletchConstant(constant.classId, MapId.classes));
        } else {
          int id = context.compiledConstants[constant];
          if (id == null) {
            throw "Unsupported constant: ${constant.toStructuredString()}";
          }
          fletchConstants.add(
              new FletchConstant(id, MapId.constants));
        }
      } else {
        throw "Unsupported constant: ${constant.runtimeType}";
      }
    });

    return fletchConstants;
  }

  String verboseToString() {
    StringBuffer sb = new StringBuffer();

    sb.writeln("Method $methodId, Arity=${assembler.functionArity}");
    sb.writeln("Constants:");
    constants.forEach((constant, int index) {
      if (constant is ConstantValue) {
        constant = constant.toStructuredString();
      }
      sb.writeln("  #$index: $constant");
    });

    sb.writeln("Bytecodes:");
    int offset = 0;
    for (Bytecode bytecode in assembler.bytecodes) {
      sb.writeln("  $offset: $bytecode");
      offset += bytecode.size;
    }

    return '$sb';
  }
}
