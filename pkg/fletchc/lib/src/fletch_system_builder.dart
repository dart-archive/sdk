// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_system_builder;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue,
    StringConstantValue;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    Element,
    FunctionSignature;

import 'fletch_class_builder.dart';
import 'fletch_context.dart';
import 'fletch_function_builder.dart';

import '../fletch_system.dart';
import '../commands.dart';

class FletchSystemBuilder {
  final FletchSystem predecessorSystem;

  final List<FletchFunctionBuilder> _newFunctions = <FletchFunctionBuilder>[];
  final List<FletchClassBuilder> _newClasses = <FletchClassBuilder>[];
  final Map<ConstantValue, int> _newConstants = <ConstantValue, int>{};

  FletchSystemBuilder(this.predecessorSystem);

  // TODO(ajohnsen): Remove and add a lookupConstant.
  Map<ConstantValue, int> getCompiledConstants() => _newConstants;

  FletchFunctionBuilder newFunctionBuilder(
      FletchFunctionKind kind,
      int arity,
      {String name,
       Element element,
       FunctionSignature signature,
       int memberOf}) {
    int nextFunctionId =
        predecessorSystem.functions.length + _newFunctions.length;
    FletchFunctionBuilder builder = new FletchFunctionBuilder(
        nextFunctionId,
        kind,
        arity,
        name: name,
        element: element,
        signature: signature,
        memberOf: memberOf);
    _newFunctions.add(builder);
    return builder;
  }

  FletchFunctionBuilder newFunctionBuilderWithSignature(
      String name,
      Element element,
      FunctionSignature signature,
      int memberOf,
      {FletchFunctionKind kind: FletchFunctionKind.NORMAL}) {
    int arity = signature.parameterCount + (memberOf != null ? 1 : 0);
    return newFunctionBuilder(
          kind,
          arity,
          name: name,
          element: element,
          signature: signature,
          memberOf: memberOf);
  }

  FletchFunction lookupFunction(int functionId) {
    return predecessorSystem.functions[functionId];
  }

  FletchFunctionBuilder lookupFunctionBuilder(int functionId) {
    return _newFunctions[functionId - predecessorSystem.functions.length];
  }

  List<FletchFunctionBuilder> getNewFunctions() => _newFunctions;

  FletchClassBuilder newClassBuilder(
      ClassElement element,
      FletchClassBuilder superclass,
      bool isBuiltin,
      {int extraFields: 0}) {
    int nextClassId =
        predecessorSystem.classes.length + _newClasses.length;
    FletchClassBuilder builder = new FletchClassBuilder(
        nextClassId,
        element,
        superclass,
        isBuiltin,
        extraFields);
    _newClasses.add(builder);
    return builder;
  }

  FletchClass lookupClass(int classId) {
    return predecessorSystem.classes[classId];
  }

  FletchClassBuilder lookupClassBuilder(int classId) {
    return _newClasses[classId - predecessorSystem.classes.length];
  }

  List<FletchClassBuilder> getNewClasses() => _newClasses;

  void registerConstant(ConstantValue constant, FletchContext context) {
    // TODO(ajohnsen): Look in predecessorSystem.
    _newConstants.putIfAbsent(constant, () {
      if (constant.isConstructedObject) {
        context.registerConstructedConstantValue(constant);
      } else if (constant.isFunction) {
        context.registerFunctionConstantValue(constant);
      }
      for (ConstantValue value in constant.getDependencies()) {
        registerConstant(value, context);
      }
      return _newConstants.length;
    });
  }

  // TODO(ajohnsen): Merge with FletchBackend's computeDelta.
  FletchDelta computeDelta(FletchContext context) {
    List<Command> commands = <Command>[const PrepareForChanges()];

    int changes = 0;

    List<FletchFunction> functions = <FletchFunction>[];
    for (FletchFunctionBuilder builder in _newFunctions) {
      functions.add(builder.finalizeFunction(context, commands));
    }

    _newConstants.forEach((ConstantValue constant, int id) {
      // TODO(ajohnsen): Support other constants.
      StringConstantValue value = constant;
      commands.add(new PushNewString(value.primitiveValue.slowToString()));
      commands.add(new PopToMap(MapId.constants, id));
    });

    for (FletchFunction function in functions) {
      List<FletchConstant> constants = function.constants;
      for (int i = 0; i < constants.length; i++) {
        FletchConstant constant = constants[i];
        commands
            ..add(new PushFromMap(MapId.methods, function.methodId))
            ..add(new PushFromMap(constant.mapId, constant.id))
            ..add(new ChangeMethodLiteral(i));
        changes++;
      }
    }

    // TODO(ajohnsen): Big hack. We should not track method dependency like
    // this.
    for (FletchFunctionBuilder function in _newFunctions) {
      if (function.element == context.compiler.mainFunction) {
        FletchFunctionBuilder callMain =
            context.backend.functionBuilders[
                context.backend.fletchSystemLibrary.findLocal('callMain')];
        commands.add(new PushFromMap(MapId.methods, callMain.methodId));
        commands.add(new PushFromMap(MapId.methods, function.methodId));
        commands.add(new ChangeMethodLiteral(0));
        changes++;
      }
    }

    commands.add(new CommitChanges(changes));
    functions = new List<FletchFunction>.from(predecessorSystem.functions)
        ..addAll(functions);

    return new FletchDelta(
        new FletchSystem(functions, <FletchClass>[]),
        predecessorSystem,
        commands);
  }
}
