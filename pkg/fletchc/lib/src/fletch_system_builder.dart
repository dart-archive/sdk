// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_system_builder;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue,
    StringConstantValue;

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

  int get nextFunctionId {
    return predecessorSystem.functions.length + _newFunctions.length;
  }

  void registerNewFunction(FletchFunctionBuilder function) {
    assert(function.methodId == nextFunctionId);
    _newFunctions.add(function);
  }

  FletchFunction lookupFunction(int functionId) {
    return predecessorSystem.functions[functionId];
  }

  FletchFunctionBuilder lookupFunctionBuilder(int functionId) {
    return _newFunctions[functionId - predecessorSystem.functions.length];
  }

  List<FletchFunctionBuilder> getNewFunctions() => _newFunctions;

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

    List<FletchFunction> fletchFunctions = <FletchFunction>[];
    for (FletchFunctionBuilder functionBuilder in _newFunctions) {
      fletchFunctions.add(functionBuilder.finalizeFunction(context, commands));
    }

    _newConstants.forEach((ConstantValue constant, int id) {
      // TODO(ajohnsen): Support other constants.
      StringConstantValue value = constant;
      commands.add(new PushNewString(value.primitiveValue.slowToString()));
      commands.add(new PopToMap(MapId.constants, id));
    });

    for (FletchFunction function in fletchFunctions) {
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

    return new FletchDelta(
        new FletchSystem(fletchFunctions, <FletchClass>[]),
        predecessorSystem,
        commands);
  }
}
