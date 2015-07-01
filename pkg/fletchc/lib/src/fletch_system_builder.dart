// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_system_builder;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue,
    ConstructedConstantValue,
    FunctionConstantValue,
    ListConstantValue,
    MapConstantValue,
    StringConstantValue;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    Element,
    FunctionElement,
    FunctionSignature;

import 'package:compiler/src/universe/universe.dart' show
    CallStructure;

import 'package:persistent/persistent.dart' show
    PersistentMap;

import 'fletch_constants.dart' show
    FletchClassConstant,
    FletchFunctionConstant,
    FletchClassInstanceConstant;

import 'fletch_class_builder.dart';
import 'fletch_context.dart';
import 'fletch_function_builder.dart';

import '../fletch_system.dart';
import '../commands.dart';

class FletchSystemBuilder {
  final FletchSystem predecessorSystem;
  final int functionIdStart;

  final List<FletchFunctionBuilder> _newFunctions = <FletchFunctionBuilder>[];
  final List<FletchClassBuilder> _newClasses = <FletchClassBuilder>[];
  final Map<ConstantValue, int> _newConstants = <ConstantValue, int>{};
  final Map<FletchFunctionBase, Map<CallStructure, FletchFunctionBuilder>>
      _newParameterStubs =
          <FletchFunctionBase, Map<CallStructure, FletchFunctionBuilder>>{};

  final List<FletchFunction> _removedFunctions = <FletchFunction>[];

  final Map<Element, FletchFunctionBuilder> _buildersByElement =
      <Element, FletchFunctionBuilder>{};

  FletchSystemBuilder(FletchSystem predecessorSystem)
      : this.predecessorSystem = predecessorSystem,
        this.functionIdStart = predecessorSystem.computeMaxFunctionId() + 1;

  // TODO(ajohnsen): Remove and add a lookupConstant.
  Map<ConstantValue, int> getCompiledConstants() => _newConstants;

  FletchFunctionBuilder newFunctionBuilder(
      FletchFunctionKind kind,
      int arity,
      {String name,
       Element element,
       FunctionSignature signature,
       int memberOf}) {
    int nextFunctionId = functionIdStart + _newFunctions.length;
    FletchFunctionBuilder builder = new FletchFunctionBuilder(
        nextFunctionId,
        kind,
        arity,
        name: name,
        element: element,
        signature: signature,
        memberOf: memberOf);
    _newFunctions.add(builder);
    if (element != null) _buildersByElement[element] = builder;
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

  FletchFunctionBase lookupFunction(int functionId) {
    FletchFunction function = predecessorSystem.lookupFunctionById(functionId);
    if (function != null) return function;
    return _newFunctions[functionId];
  }

  FletchFunctionBuilder lookupFunctionBuilder(int functionId) {
    return _newFunctions[functionId - functionIdStart];
  }

  FletchFunctionBase lookupFunctionByElement(Element element) {
    FletchFunction function =
        predecessorSystem.lookupFunctionByElement(element);
    if (function != null) return function;
    return _buildersByElement[element];
  }

  void forgetFunction(FletchFunction function) {
    _removedFunctions.add(function);
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
      return predecessorSystem.constants.length + _newConstants.length;
    });
  }

  FletchFunctionBase parameterStubFor(
      FletchFunctionBase function,
      CallStructure callStructure) {
    // TODO(ajohnsen): Look in predecessorSystem.
    var stubs = _newParameterStubs[function];
    if (stubs == null) return null;
    return stubs[callStructure];
  }

  void registerParameterStubFor(
      FletchFunctionBase function,
      CallStructure callStructure,
      FletchFunctionBuilder stub) {
    var stubs = _newParameterStubs.putIfAbsent(
        function,
        () => <CallStructure, FletchFunctionBuilder>{});
    assert(!stubs.containsKey(callStructure));
    stubs[callStructure] = stub;
  }

  FletchSystem computeSystem(FletchContext context, List<Command> commands) {
    int changes = 0;

    // Remove all removed FletchFunctions.
    for (FletchFunction function in _removedFunctions) {
      commands.add(new RemoveFromMap(MapId.methods, function.methodId));
    }

    // Create all new FletchFunctions.
    List<FletchFunction> functions = <FletchFunction>[];
    for (FletchFunctionBuilder builder in _newFunctions) {
      functions.add(builder.finalizeFunction(context, commands));
    }

    // Create all new FletchClasses.
    List<FletchClass> classes = <FletchClass>[];
    for (FletchClassBuilder builder in _newClasses) {
      classes.add(builder.finalizeClass(context, commands));
      changes++;
    }

    // Create all statics.
    // TODO(ajohnsen): Should be part of the fletch system. Does not work with
    // incremental.
    if (predecessorSystem.isEmpty) {
      context.forEachStatic((element, index) {
        FletchFunctionBuilder initializer =
            context.backend.lazyFieldInitializers[element];
        if (initializer != null) {
          commands.add(new PushFromMap(MapId.methods, initializer.methodId));
          commands.add(const PushNewInitializer());
        } else {
          commands.add(const PushNull());
        }
      });
      commands.add(new ChangeStatics(context.staticIndices.length));
      changes++;
    }

    // Create all FletchConstants.
    List<FletchConstant> constants = <FletchConstant>[];
    _newConstants.forEach((constant, int id) {
      void addList(List<ConstantValue> list) {
        for (ConstantValue entry in list) {
          int entryId = context.compiledConstants[entry];
          commands.add(new PushFromMap(MapId.constants, entryId));
        }
        commands.add(new PushConstantList(list.length));
      }

      if (constant.isInt) {
        commands.add(new PushNewInteger(constant.primitiveValue));
      } else if (constant.isDouble) {
        commands.add(new PushNewDouble(constant.primitiveValue));
      } else if (constant.isTrue) {
        commands.add(new PushBoolean(true));
      } else if (constant.isFalse) {
        commands.add(new PushBoolean(false));
      } else if (constant.isNull) {
        commands.add(const PushNull());
      } else if (constant.isString) {
        commands.add(
            new PushNewString(constant.primitiveValue.slowToString()));
      } else if (constant.isList) {
        ListConstantValue value = constant;
        addList(constant.entries);
      } else if (constant.isMap) {
        MapConstantValue value = constant;
        addList(value.keys);
        addList(value.values);
        commands.add(new PushConstantMap(value.length * 2));
      } else if (constant.isFunction) {
        FunctionConstantValue value = constant;
        FunctionElement element = value.element;
        // TODO(ajohnsen): Avoid usage of functionBuilders.
        FletchFunctionBuilder function =
            context.backend.functionBuilders[element];
        // TODO(ajohnsen): Avoid usage of tearoffClasses.
        FletchClassBuilder tearoffClass =
            context.backend.tearoffClasses[function];
        commands
            ..add(new PushFromMap(MapId.classes, tearoffClass.classId))
            ..add(const PushNewInstance());
      } else if (constant.isConstructedObject) {
        ConstructedConstantValue value = constant;
        ClassElement classElement = value.type.element;
        // TODO(ajohnsen): Avoid usage of classBuilders.
        FletchClassBuilder classBuilder =
            context.backend.classBuilders[classElement];
        for (ConstantValue field in value.fields.values) {
          int fieldId = context.compiledConstants[field];
          commands.add(new PushFromMap(MapId.constants, fieldId));
        }
        commands
            ..add(new PushFromMap(MapId.classes, classBuilder.classId))
            ..add(const PushNewInstance());
      } else if (constant is FletchClassInstanceConstant) {
        commands
            ..add(new PushFromMap(MapId.classes, constant.classId))
            ..add(const PushNewInstance());
      } else {
        throw "Unsupported constant: ${constant.toStructuredString()}";
      }
      constants.add(new FletchConstant(id, MapId.constants));
      commands.add(new PopToMap(MapId.constants, id));
    });

    // Set super class for classes, now they are resolved.
    for (FletchClass klass in classes) {
      if (!klass.hasSuperclassId) continue;
      commands.add(new PushFromMap(MapId.classes, klass.classId));
      commands.add(new PushFromMap(MapId.classes, klass.superclassId));
      commands.add(const ChangeSuperClass());
      changes++;
    }

    // Change constants for the functions, now that classes and constants has
    // been added.
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
    if (!predecessorSystem.isEmpty) {
      for (FletchFunctionBuilder function in _newFunctions) {
        if (function.element == context.compiler.mainFunction) {
          FletchFunctionBase callMain =
              lookupFunctionByElement(
                  context.backend.fletchSystemLibrary.findLocal('callMain'));
          commands.add(new PushFromMap(MapId.methods, callMain.methodId));
          commands.add(new PushFromMap(MapId.methods, function.methodId));
          commands.add(new ChangeMethodLiteral(0));
          changes++;
        }
      }
    }

    commands.add(new CommitChanges(changes));

    classes = new List<FletchClass>.from(predecessorSystem.classes)
        ..addAll(classes);

    PersistentMap<int, FletchFunction> functionsById =
        predecessorSystem.functionsById;

    PersistentMap<Element, FletchFunction> functionsByElement =
        predecessorSystem.functionsByElement;

    for (FletchFunction function in _removedFunctions) {
      functionsById = functionsById.delete(function.methodId);
      Element element = function.element;
      if (element != null) {
        functionsByElement = functionsByElement.delete(element);
      }
    }

    for (FletchFunction function in functions) {
      functionsById = functionsById.insert(function.methodId, function);
    }

    _buildersByElement.forEach((element, builder) {
      functionsByElement = functionsByElement.insert(
          element,
          functionsById[builder.methodId],
          (oldValue, newValue) {
            throw "Unexpected element in predecessorSystem.";
          });
    });

    return new FletchSystem(
        functionsById,
        functionsByElement,
        classes,
        constants);
  }
}
