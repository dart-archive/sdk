// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_system_builder;

import 'dart:typed_data';

import 'package:compiler/src/constants/values.dart' show
    ConstantValue,
    ConstructedConstantValue,
    FunctionConstantValue,
    IntConstantValue,
    ListConstantValue,
    MapConstantValue,
    StringConstantValue;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    ConstructorElement,
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
  final int classIdStart;

  final List<FletchFunctionBuilder> _newFunctions = <FletchFunctionBuilder>[];
  final Map<int, FletchClassBuilder> _newClasses = <int, FletchClassBuilder>{};
  final Map<ConstantValue, int> _newConstants = <ConstantValue, int>{};
  final Map<FletchFunctionBase, Map<CallStructure, FletchFunctionBuilder>>
      _newParameterStubs =
          <FletchFunctionBase, Map<CallStructure, FletchFunctionBuilder>>{};

  final List<FletchFunction> _removedFunctions = <FletchFunction>[];

  final Map<Element, FletchFunctionBuilder> _functionBuildersByElement =
      <Element, FletchFunctionBuilder>{};

  final Map<ClassElement, FletchClassBuilder> _classBuildersByElement =
      <ClassElement, FletchClassBuilder>{};

  final Map<ConstructorElement, FletchFunctionBuilder>
      _newConstructorInitializers =
          <ConstructorElement, FletchFunctionBuilder>{};

  // TODO(ajohnsen): By function/class?
  final Map<Element, List<FunctionElement>> _replaceUsage =
      <Element, List<FunctionElement>>{};

  final Map<int, int> _newTearoffsById = <int, int>{};

  final int maxInt64 = (1 << 63) - 1;
  final int minInt64 = -(1 << 63);

  FletchSystemBuilder(FletchSystem predecessorSystem)
      : this.predecessorSystem = predecessorSystem,
        this.functionIdStart = predecessorSystem.computeMaxFunctionId() + 1,
        this.classIdStart = predecessorSystem.computeMaxClassId() + 1;

  // TODO(ajohnsen): Remove and add a lookupConstant.
  Map<ConstantValue, int> getCompiledConstants() => _newConstants;

  void replaceUsage(Element element, FunctionElement usage) {
    _replaceUsage.putIfAbsent(element, () => []).add(usage);
  }

  FletchFunctionBuilder newFunctionBuilder(
      FletchFunctionKind kind,
      int arity,
      {String name,
       Element element,
       FunctionSignature signature,
       int memberOf,
       Element mapByElement}) {
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
    if (mapByElement != null) {
      _functionBuildersByElement[mapByElement] = builder;
    }
    return builder;
  }

  FletchFunctionBuilder newFunctionBuilderWithSignature(
      String name,
      Element element,
      FunctionSignature signature,
      int memberOf,
      {FletchFunctionKind kind: FletchFunctionKind.NORMAL,
       Element mapByElement}) {
    int arity = signature.parameterCount + (memberOf != null ? 1 : 0);
    return newFunctionBuilder(
          kind,
          arity,
          name: name,
          element: element,
          signature: signature,
          memberOf: memberOf,
          mapByElement: mapByElement);
  }

  FletchFunctionBase lookupFunction(int functionId) {
    if (functionId < functionIdStart) {
      return predecessorSystem.lookupFunctionById(functionId);
    } else {
      return lookupFunctionBuilder(functionId);
    }
  }

  FletchFunctionBuilder lookupFunctionBuilder(int functionId) {
    return _newFunctions[functionId - functionIdStart];
  }

  FletchFunctionBase lookupFunctionByElement(Element element) {
    FletchFunctionBase function = _functionBuildersByElement[element];
    if (function != null) return function;
    return predecessorSystem.lookupFunctionByElement(element);
  }

  FletchFunctionBuilder lookupFunctionBuilderByElement(Element element) {
    return _functionBuildersByElement[element];
  }

  FletchFunctionBase lookupConstructorInitializerByElement(
      ConstructorElement element) {
    assert(element.isImplementation);
    FletchFunctionBase function = _newConstructorInitializers[element];
    if (function != null) return function;
    return predecessorSystem.lookupConstructorInitializerByElement(element);
  }

  FletchFunctionBuilder newConstructorInitializer(ConstructorElement element) {
    assert(element.isImplementation);
    FletchFunctionBuilder builder = newFunctionBuilderWithSignature(
        element.name,
        element,
        element.functionSignature,
        null,
        kind: FletchFunctionKind.INITIALIZER_LIST);
    _newConstructorInitializers[element] = builder;
    return builder;
  }

  int lookupTearOffById(int functionId) {
    int id = _newTearoffsById[functionId];
    if (id != null) return id;
    return predecessorSystem.lookupTearOffById(functionId);
  }

  FletchFunctionBuilder newTearOff(FletchFunctionBase function, int classId) {
    FletchFunctionBuilder builder = newFunctionBuilderWithSignature(
        'call',
        null,
        function.signature,
        classId);
    _newTearoffsById[function.functionId] = builder.functionId;
    return builder;
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
    if (element != null) {
      FletchClass klass = predecessorSystem.lookupClassByElement(element);
      if (klass != null) {
        FletchClassBuilder builder = new FletchPatchClassBuilder(
            klass, superclass);
        _newClasses[klass.classId] = builder;
        _classBuildersByElement[element] = builder;
        return builder;
      }
    }

    int nextClassId = classIdStart + _newClasses.length;
    FletchClassBuilder builder = new FletchNewClassBuilder(
        nextClassId,
        element,
        superclass,
        isBuiltin,
        extraFields);
    _newClasses[nextClassId] = builder;
    if (element != null) _classBuildersByElement[element] = builder;
    return builder;
  }

  FletchClass lookupClass(int classId) {
    return predecessorSystem.classesById[classId];
  }

  FletchClassBuilder lookupClassBuilder(int classId) {
    return _newClasses[classId];
  }

  FletchClassBuilder lookupClassBuilderByElement(ClassElement element) {
    return _classBuildersByElement[element];
  }

  Iterable<FletchClassBuilder> getNewClasses() => _newClasses.values;

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
    // TODO(ajohnsen): Consider if the incremental compiler should be aware of
    // callMain, when detecting changes.
    FunctionElement callMain =
        context.backend.fletchSystemLibrary.findLocal('callMain');
    replaceUsage(callMain, context.compiler.mainFunction);

    int changes = 0;

    // Remove all removed FletchFunctions.
    for (FletchFunction function in _removedFunctions) {
      commands.add(new RemoveFromMap(MapId.methods, function.functionId));
    }

    // Create all new FletchFunctions.
    List<FletchFunction> functions = <FletchFunction>[];
    for (FletchFunctionBuilder builder in _newFunctions) {
      context.compiler.withCurrentElement(builder.element, () {
        functions.add(builder.finalizeFunction(context, commands));
      });
    }

    // Create all new FletchClasses.
    List<FletchClass> classes = <FletchClass>[];
    for (FletchClassBuilder builder in _newClasses.values) {
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
          commands.add(new PushFromMap(MapId.methods, initializer.functionId));
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
      void addList(List<ConstantValue> list, bool isByteList) {
        for (ConstantValue entry in list) {
          int entryId = context.compiledConstants[entry];
          commands.add(new PushFromMap(MapId.constants, entryId));
          if (entry.isInt) {
            IntConstantValue constant = entry;
            int value = constant.primitiveValue;
            if (value & 0xFF == value) continue;
          }
          isByteList = false;
        }
        if (isByteList) {
          // TODO(ajohnsen): The PushConstantByteList command could take a
          // paylod with the data content.
          commands.add(new PushConstantByteList(list.length));
        } else {
          commands.add(new PushConstantList(list.length));
        }
      }

      if (constant.isInt) {
        var value = constant.primitiveValue;
        if (value > maxInt64 || value < minInt64) {
          assert(const bool.fromEnvironment('fletch.enable-bigint'));
          bool negative = value < 0;
          value = negative ? -value : value;
          var parts = new List();
          while (value != 0) {
            parts.add(value & 0xffffffff);
            value >>= 32;
          }

          // TODO(ajohnsen): Avoid usage of builders (should be FletchClass).
          FletchClassBuilder bigintClassBuilder =
              _classBuildersByElement[context.backend.bigintClass];
          FletchClassBuilder uint32DigitsClassBuilder =
              _classBuildersByElement[context.backend.uint32DigitsClass];

          commands.add(new PushNewBigInteger(
              negative,
              parts,
              MapId.classes,
              bigintClassBuilder.classId,
              uint32DigitsClassBuilder.classId));
        } else {
          commands.add(new PushNewInteger(constant.primitiveValue));
        }
      } else if (constant.isDouble) {
        commands.add(new PushNewDouble(constant.primitiveValue));
      } else if (constant.isTrue) {
        commands.add(new PushBoolean(true));
      } else if (constant.isFalse) {
        commands.add(new PushBoolean(false));
      } else if (constant.isNull) {
        commands.add(const PushNull());
      } else if (constant.isString) {
        Iterable<int> list = constant.primitiveValue.slowToString().codeUnits;
        if (list.any((codeUnit) => codeUnit >= 256)) {
          commands.add(new PushNewTwoByteString(new Uint16List.fromList(list)));
        } else {
          commands.add(new PushNewOneByteString(new Uint8List.fromList(list)));
        }
      } else if (constant.isList) {
        addList(constant.entries, true);
      } else if (constant.isMap) {
        MapConstantValue value = constant;
        addList(value.keys, false);
        addList(value.values, false);
        commands.add(new PushConstantMap(value.length * 2));
      } else if (constant.isFunction) {
        FunctionConstantValue value = constant;
        FunctionElement element = value.element;
        FletchFunctionBase function = lookupFunctionByElement(element);
        int tearoffId = lookupTearOffById(function.functionId);
        FletchFunctionBase tearoff = lookupFunction(tearoffId);
        commands
            ..add(new PushFromMap(MapId.classes, tearoff.memberOf))
            ..add(const PushNewInstance());
      } else if (constant.isConstructedObject) {
        ConstructedConstantValue value = constant;
        ClassElement classElement = value.type.element;
        // TODO(ajohnsen): Avoid usage of builders (should be FletchClass).
        FletchClassBuilder classBuilder = _classBuildersByElement[classElement];
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
      } else if (constant.isType) {
        // TODO(kasperl): Implement proper support for class literals. At this
        // point, we've already issues unimplemented errors for the individual
        // accesses to the class literals, so we just let the class literal
        // turn into null in the runtime.
        commands.add(const PushNull());
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
            ..add(new PushFromMap(MapId.methods, function.functionId))
            ..add(new PushFromMap(constant.mapId, constant.id))
            ..add(new ChangeMethodLiteral(i));
        changes++;
      }
    }

    // Compute all scheme changes.
    for (FletchClassBuilder builder in _newClasses.values) {
      if (builder.computeSchemaChange(commands)) changes++;
    }

    List<FletchFunction> changedFunctions = <FletchFunction>[];
    for (Element element in _replaceUsage.keys) {
      // Don't modify already replaced elements.
      if (lookupFunctionBuilderByElement(element) != null) continue;

      FletchFunction function =
          predecessorSystem.lookupFunctionByElement(element);
      // Due to false positive, the element can be uncompiled.
      if (function == null) continue;

      bool constantsChanged = false;
      List<FletchConstant> constants = function.constants.toList();
      for (int i = 0; i < constants.length; i++) {
        FletchConstant constant = constants[i];
        if (constant.mapId != MapId.methods) continue;
        for (var usage in _replaceUsage[element]) {
          FletchFunction oldFunction =
              predecessorSystem.lookupFunctionByElement(usage);
          if (oldFunction == null) continue;
          if (oldFunction.functionId != constant.id) continue;
          FletchFunctionBuilder newFunction =
              lookupFunctionBuilderByElement(usage);

          // If the method didn't really change, ignore.
          if (newFunction == null) continue;

          constant = new FletchConstant(newFunction.functionId, MapId.methods);
          commands
              ..add(new PushFromMap(MapId.methods, function.functionId))
              ..add(new PushFromMap(constant.mapId, constant.id))
              ..add(new ChangeMethodLiteral(i));
          constants[i] = constant;
          constantsChanged = true;
          changes++;
          break;
        }
      }

      if (constantsChanged) {
        changedFunctions.add(function.withReplacedConstants(constants));
      }
    }

    commands.add(new CommitChanges(changes));

    PersistentMap<int, FletchClass> classesById = predecessorSystem.classesById;
    PersistentMap<ClassElement, FletchClass> classesByElement =
        predecessorSystem.classesByElement;

    for (FletchClass klass in classes) {
      classesById = classesById.insert(klass.classId, klass);
      if (klass.element != null) {
        classesByElement = classesByElement.insert(klass.element, klass);
      }
    }

    PersistentMap<int, FletchFunction> functionsById =
        predecessorSystem.functionsById;
    PersistentMap<Element, FletchFunction> functionsByElement =
        predecessorSystem.functionsByElement;

    for (FletchFunction function in changedFunctions) {
      assert(functionsById[function.functionId] != null);
      functionsById = functionsById.insert(function.functionId, function);
      Element element = function.element;
      if (element != null) {
        assert(functionsByElement[element] != null);
        functionsByElement = functionsByElement.insert(element, function);
      }
    }

    for (FletchFunction function in _removedFunctions) {
      functionsById = functionsById.delete(function.functionId);
      Element element = function.element;
      if (element != null) {
        functionsByElement = functionsByElement.delete(element);
      }
    }

    for (FletchFunction function in functions) {
      functionsById = functionsById.insert(function.functionId, function);
    }

    _functionBuildersByElement.forEach((element, builder) {
      functionsByElement = functionsByElement.insert(
          element,
          functionsById[builder.functionId],
          (oldValue, newValue) {
            throw "Unexpected element in predecessorSystem.";
          });
    });

    PersistentMap<ConstructorElement, FletchFunction>
        constructorInitializersByElement =
            predecessorSystem.constructorInitializersByElement;

    _newConstructorInitializers.forEach((element, builder) {
      constructorInitializersByElement =
          constructorInitializersByElement.insert(
              element, functionsById[builder.functionId]);
    });

    PersistentMap<int, int> tearoffsById = predecessorSystem.tearoffsById;
    _newTearoffsById.forEach((int functionId, int stubId) {
      tearoffsById = tearoffsById.insert(functionId, stubId);
    });

    return new FletchSystem(
        functionsById,
        functionsByElement,
        constructorInitializersByElement,
        tearoffsById,
        classesById,
        classesByElement,
        constants);
  }
}
