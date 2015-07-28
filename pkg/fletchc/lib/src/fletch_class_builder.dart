// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_class_builder;

import 'package:compiler/src/dart_types.dart';
import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/universe/universe.dart';
import 'package:persistent/persistent.dart';

import 'fletch_function_builder.dart';
import 'fletch_context.dart';
import 'fletch_backend.dart';

import '../fletch_system.dart';
import '../commands.dart';

abstract class FletchClassBuilder {
  int get classId;
  ClassElement get element;
  FletchClassBuilder get superclass;
  int get fields;

  /**
   * Returns the number of instance fields of all the super classes of this
   * class.
   *
   * If this class has no super class (if it's Object), 0 is returned.
   */
  int get superclassFields => hasSuperClass ? superclass.fields : 0;

  bool get hasSuperClass => superclass != null;

  void addToMethodTable(int selector, FletchFunctionBuilder functionBuilder);
  void removeFromMethodTable(FletchFunctionBase function);

  // Add a selector for is-tests. The selector is only to be hit with the
  // InvokeTest bytecode, as the function is not guraranteed to be valid.
  void addIsSelector(int selector);
  void createIsFunctionEntry(FletchBackend backend, int arity);
  void createImplicitAccessors(FletchBackend backend);
  void createIsEntries(FletchBackend backend);

  FletchClass finalizeClass(FletchContext context, List<Command> commands);

  // The method table for a class is a mapping from Fletch's integer
  // selectors to method ids. It contains all methods defined for a
  // class including the implicit accessors. The returned map is not sorted.
  // TODO(ajohnsen): Remove once not used by feature_test anymore.
  PersistentMap<int, int> computeMethodTable();
}

class FletchNewClassBuilder extends FletchClassBuilder {
  final int classId;
  final ClassElement element;
  final FletchClassBuilder superclass;
  final bool isBuiltin;

  // The extra fields are synthetic fields not represented in any Dart source
  // code. They are used for the synthetic closure classes that are introduced
  // behind the scenes.
  final int extraFields;

  final Map<int, int> _implicitAccessorTable = <int, int>{};
  final Map<int, FletchFunctionBase> _methodTable = <int, FletchFunctionBase>{};

  FletchNewClassBuilder(
      this.classId,
      this.element,
      this.superclass,
      this.isBuiltin,
      this.extraFields);

  int get fields {
    int count = superclassFields + extraFields;
    if (element != null) {
      // TODO(kasperl): Once we change compiled class to be immutable, we
      // should cache the field count.
      element.implementation.forEachInstanceField((_, __) { count++; });
    }
    return count;
  }

  void addToMethodTable(int selector, FletchFunctionBuilder functionBuilder) {
    _methodTable[selector] = functionBuilder;
  }

  void removeFromMethodTable(FletchFunctionBase function) {
    throw new StateError("Methods should not be removed from a new class.");
  }

  void addIsSelector(int selector) {
    // TODO(ajohnsen): 'null' is a placeholder. Generate dummy function?
    _methodTable[selector] = null;
  }

  PersistentMap<int, int> computeMethodTable() {
    PersistentMap<int, int> result = new PersistentMap<int, int>();
    List<int> selectors = _implicitAccessorTable.keys.toList()
        ..addAll(_methodTable.keys);
    for (int selector in selectors) {
      if (_methodTable.containsKey(selector)) {
        FletchFunctionBase function = _methodTable[selector];
        int functionId = function == null ? 0 : function.functionId;
        result = result.insert(selector, functionId);
      } else {
        result = result.insert(selector, _implicitAccessorTable[selector]);
      }
    }
    return result;
  }

  void createImplicitAccessors(FletchBackend backend) {
    _implicitAccessorTable.clear();
    // If we don't have an element (stub class), we don't have anything to
    // generate accessors for.
    if (element == null) return;
    // TODO(ajohnsen): Don't do this once dart2js can enqueue field getters in
    // CodegenEnqueuer.
    int fieldIndex = superclassFields;
    element.implementation.forEachInstanceField((enclosing, field) {
      var getter = new Selector.getter(field.name, field.library);
      int getterSelector = backend.context.toFletchSelector(getter);
      _implicitAccessorTable[getterSelector] = backend.makeGetter(fieldIndex);

      if (!field.isFinal) {
        var setter = new Selector.setter(field.name, field.library);
        var setterSelector = backend.context.toFletchSelector(setter);
        _implicitAccessorTable[setterSelector] = backend.makeSetter(fieldIndex);
      }

      fieldIndex++;
    });
  }

  void createIsEntries(FletchBackend backend) {
    if (element == null) return;

    Set superclasses = new Set();
    for (FletchClassBuilder current = superclass;
         current != null;
         current = current.superclass) {
      superclasses.add(current.element);
    }

    void createFor(ClassElement classElement) {
      if (superclasses.contains(classElement)) return;
      int fletchSelector = backend.context.toFletchIsSelector(classElement);
      addIsSelector(fletchSelector);
    }

    // Create for the current element.
    createFor(element);

    // Add all types related to 'implements'.
    for (InterfaceType interfaceType in element.interfaces) {
      createFor(interfaceType.element);
      for (DartType type in interfaceType.element.allSupertypes) {
        createFor(type.element);
      }
    }
  }

  void createIsFunctionEntry(FletchBackend backend, int arity) {
    int fletchSelector = backend.context.toFletchIsSelector(
        backend.compiler.functionClass);
    addIsSelector(fletchSelector);
    fletchSelector = backend.context.toFletchIsSelector(
        backend.compiler.functionClass, arity);
    addIsSelector(fletchSelector);
  }

  FletchClass finalizeClass(FletchContext context, List<Command> commands) {
    if (isBuiltin) {
      int nameId = context.getSymbolId(element.name);
      commands.add(new PushBuiltinClass(nameId, fields));
    } else {
      commands.add(new PushNewClass(fields));
    }

    commands.add(const Dup());
    commands.add(new PopToMap(MapId.classes, classId));

    PersistentMap<int, int> methodTable = computeMethodTable();
    for (int selector in methodTable.keys.toList()..sort()) {
      int functionId = methodTable[selector];
      commands.add(new PushNewInteger(selector));
      commands.add(new PushFromMap(MapId.methods, functionId));
    }
    commands.add(new ChangeMethodTable(methodTable.length));

    return new FletchClass(
        classId,
        // TODO(ajohnsen): Take name in FletchClassBuilder constructor.
        element == null ? '<internal>' : element.name,
        element,
        superclass == null ? -1 : superclass.classId,
        fields,
        superclassFields,
        methodTable);
  }

  String toString() => "FletchClassBuilder($element, $classId)";
}

class FletchPatchClassBuilder extends FletchClassBuilder {
  final FletchClass klass;
  final FletchClassBuilder superclass;

  final Map<int, FletchFunctionBase> _newMethods = <int, FletchFunctionBase>{};
  final Set<FletchFunctionBase> _removedMethods = new Set<FletchFunctionBase>();

  // TODO(ajohnsen): Can the element change?
  FletchPatchClassBuilder(this.klass, this.superclass);

  int get classId => klass.classId;
  ClassElement get element => klass.element;
  int get fields => klass.fields;

  void addToMethodTable(int selector, FletchFunctionBuilder functionBuilder) {
    _newMethods[selector] = functionBuilder;
  }

  void removeFromMethodTable(FletchFunctionBase function) {
    _removedMethods.add(function);
  }

  void addIsSelector(int selector) {
    // TODO(ajohnsen): Implement.
  }

  void createIsFunctionEntry(FletchBackend backend, int arity) {
    // TODO(ajohnsen): Implement.
  }

  void createImplicitAccessors(FletchBackend backend) {
    // TODO(ajohnsen): Implement.
  }

  void createIsEntries(FletchBackend backend) {
    // TODO(ajohnsen): Implement.
  }

  PersistentMap<int, int> computeMethodTable() {
    PersistentMap<int, int> methodTable = klass.methodTable;

    for (FletchFunctionBase function in _removedMethods) {
      methodTable.forEachKeyValue((int selector, int functionId) {
        if (functionId == function.functionId) {
          methodTable = methodTable.delete(selector);
        }
      });
    }

    _newMethods.forEach((int selector, FletchFunctionBase function) {
      methodTable = methodTable.insert(selector, function.functionId);
    });

    return methodTable;
  }

  FletchClass finalizeClass(FletchContext context, List<Command> commands) {
    commands.add(new PushFromMap(MapId.classes, classId));

    PersistentMap<int, int> methodTable = computeMethodTable();
    for (int selector in methodTable.keys.toList()..sort()) {
      int functionId = methodTable[selector];
      commands.add(new PushNewInteger(selector));
      commands.add(new PushFromMap(MapId.methods, functionId));
    }
    commands.add(new ChangeMethodTable(methodTable.length));

    return new FletchClass(
        classId,
        // TODO(ajohnsen): Take name in FletchClassBuilder constructor.
        element == null ? '<internal>' : element.name,
        element,
        superclass == null ? -1 : superclass.classId,
        fields,
        superclassFields,
        methodTable);
  }
}
