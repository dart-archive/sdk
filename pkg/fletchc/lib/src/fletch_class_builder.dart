// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_class_builder;

import 'package:compiler/src/dart_types.dart';
import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/universe/universe.dart';

import 'fletch_function_builder.dart';
import 'fletch_context.dart';
import 'fletch_backend.dart';

import '../fletch_system.dart';
import '../commands.dart';

class FletchClassBuilder {
  final int classId;
  final ClassElement element;
  final FletchClassBuilder superclass;
  final bool isBuiltin;

  // The extra fields are synthetic fields not represented in any Dart source
  // code. They are used for the synthetic closure classes that are introduced
  // behind the scenes.
  final int extraFields;

  // TODO(kasperl): Hide these tables and go through a proper API to define
  // and lookup methods.
  final Map<int, int> implicitAccessorTable = <int, int>{};
  final Map<int, FletchFunctionBuilder> methodTable =
      <int, FletchFunctionBuilder>{};

  FletchClassBuilder(
      this.classId,
      this.element,
      this.superclass,
      this.isBuiltin,
      this.extraFields);

  /**
   * Returns the number of instance fields of all the super classes of this
   * class.
   *
   * If this class has no super class (if it's Object), 0 is returned.
   */
  int get superclassFields => hasSuperClass ? superclass.fields : 0;

  bool get hasSuperClass => superclass != null;

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
    methodTable[selector] = functionBuilder;
  }

  // Add a selector for is-tests. The selector is only to be hit with the
  // InvokeTest bytecode, as the function is not guraranteed to be valid.
  void addIsSelector(int selector) {
    // TODO(ajohnsen): 'null' is a placeholder. Generate dummy function?
    methodTable[selector] = null;
  }

  // The method table for a class is a mapping from Fletch's integer
  // selectors to method ids. It contains all methods defined for a
  // class including the implicit accessors.
  Map<int, int> computeMethodTable() {
    Map<int, int> result = <int, int>{};
    List<int> selectors = implicitAccessorTable.keys.toList()
        ..addAll(methodTable.keys)
        ..sort();
    for (int selector in selectors) {
      if (methodTable.containsKey(selector)) {
        FletchFunctionBuilder function = methodTable[selector];
        result[selector] = function == null ? 0 : function.methodId;
      } else {
        result[selector] = implicitAccessorTable[selector];
      }
    }
    return result;
  }

  void createImplicitAccessors(FletchBackend backend) {
    implicitAccessorTable.clear();
    // If we don't have an element (stub class), we don't have anything to
    // generate accessors for.
    if (element == null) return;
    // TODO(ajohnsen): Don't do this once dart2js can enqueue field getters in
    // CodegenEnqueuer.
    int fieldIndex = superclassFields;
    element.implementation.forEachInstanceField((enclosing, field) {
      var getter = new Selector.getter(field.name, field.library);
      int getterSelector = backend.context.toFletchSelector(getter);
      implicitAccessorTable[getterSelector] = backend.makeGetter(fieldIndex);

      if (!field.isFinal) {
        var setter = new Selector.setter(field.name, field.library);
        var setterSelector = backend.context.toFletchSelector(setter);
        implicitAccessorTable[setterSelector] = backend.makeSetter(fieldIndex);
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

    Map<int, int> methodTable = computeMethodTable();
    methodTable.forEach((int selector, int methodId) {
      commands.add(new PushNewInteger(selector));
      commands.add(new PushFromMap(MapId.methods, methodId));
    });
    commands.add(new ChangeMethodTable(methodTable.length));

    return new FletchClass(
        classId,
        // TODO(ajohnsen): Take name in FletchClassBuilder constructor.
        element == null ? '<internal>' : element.name,
        element,
        superclass == null ? -1 : superclass.classId,
        fields,
        superclassFields);
  }

  String toString() => "FletchClassBuilder(${element.name}, $classId)";
}
