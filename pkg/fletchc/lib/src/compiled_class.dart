// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.compiled_class;

import 'package:compiler/src/dart_types.dart';
import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/universe/universe.dart';

import 'compiled_function.dart' show
    CompiledFunction;

import 'fletch_backend.dart';

class CompiledClass {
  final int id;
  final ClassElement element;
  final CompiledClass superclass;

  // The extra fields are synthetic fields not represented in any Dart source
  // code. They are used for the synthetic closure classes that are introduced
  // behind the scenes.
  final int extraFields;

  // TODO(kasperl): Hide these tables and go through a proper API to define
  // and lookup methods.
  final Map<int, int> implicitAccessorTable = <int, int>{};
  final Map<int, CompiledFunction> methodTable = <int, CompiledFunction>{};

  CompiledClass(this.id, this.element, this.superclass, {this.extraFields: 0});

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

  void addToMethodTable(int selector, CompiledFunction compiledFunction) {
    methodTable[selector] = compiledFunction;
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
  Map<int, int> computeMethodTable(FletchBackend backend) {
    Map<int, int> result = <int, int>{};
    List<int> selectors = implicitAccessorTable.keys.toList()
        ..addAll(methodTable.keys)
        ..sort();
    for (int selector in selectors) {
      if (methodTable.containsKey(selector)) {
        CompiledFunction function = methodTable[selector];
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
    for (CompiledClass current = superclass;
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

  void createIsFunctionEntry(FletchBackend backend) {
    int fletchSelector = backend.context.toFletchIsSelector(
        backend.compiler.functionClass);
    addIsSelector(fletchSelector);
  }

  String toString() => "CompiledClass(${element.name}, $id)";
}
