// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_class_builder;

import 'package:compiler/src/dart_types.dart';
import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/universe/selector.dart';
import 'package:persistent/persistent.dart';

import 'fletch_function_builder.dart';
import 'fletch_context.dart';
import 'fletch_backend.dart';

import '../fletch_system.dart';
import '../vm_commands.dart';

// TODO(ahe): Remove this import.
import '../incremental/fletchc_incremental.dart' show
    IncrementalCompilationFailed;

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

  void addToMethodTable(int selector, FletchFunctionBase functionBase);
  void removeFromMethodTable(FletchFunctionBase function);

  void addField(FieldElement field);
  void removeField(FieldElement field);

  // Add a selector for is-tests. The selector is only to be hit with the
  // InvokeTest bytecode, as the function is not guraranteed to be valid.
  void addIsSelector(int selector);
  void createIsFunctionEntry(FletchBackend backend, int arity);
  void updateImplicitAccessors(FletchBackend backend);

  FletchClass finalizeClass(
      FletchContext context,
      List<VmCommand> commands);

  // The method table for a class is a mapping from Fletch's integer
  // selectors to method ids. It contains all methods defined for a
  // class including the implicit accessors. The returned map is not sorted.
  // TODO(ajohnsen): Remove once not used by feature_test anymore.
  PersistentMap<int, int> computeMethodTable();

  bool computeSchemaChange(List<VmCommand> commands) {
    return false;
  }
}

void forEachField(ClassElement c, void action(FieldElement field)) {
  List classes = [];
  while (c != null) {
    classes.add(c);
    c = c.superclass;
  }
  for (int i = classes.length - 1; i >= 0; i--) {
    classes[i].implementation.forEachInstanceField((_, FieldElement field) {
      action(field);
    });
  }
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

  void addToMethodTable(int selector, FletchFunctionBase functionBase) {
    _methodTable[selector] = functionBase;
  }

  void addField(FieldElement field) {
    throw new StateError("Fields should not be added to a new class.");
  }

  void removeField(FieldElement field) {
    // TODO(ahe): Change this to a StateError when bug in incremental compiler
    // is fixed (tested by super_is_parameter).
    throw new IncrementalCompilationFailed(
        "Can't remove a field ($field) from a new class ($element)");
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

  void updateImplicitAccessors(FletchBackend backend) {
    _implicitAccessorTable.clear();
    // If we don't have an element (stub class), we don't have anything to
    // generate accessors for.
    if (element == null) return;
    // TODO(ajohnsen): Don't do this once dart2js can enqueue field getters in
    // CodegenEnqueuer.
    int fieldIndex = superclassFields;
    element.implementation.forEachInstanceField((enclosing, field) {
      var getter = new Selector.getter(field.memberName);
      int getterSelector = backend.context.toFletchSelector(getter);
      _implicitAccessorTable[getterSelector] = backend.makeGetter(fieldIndex);

      if (!field.isFinal) {
        var setter = new Selector.setter(new Name(field.name, field.library));
        var setterSelector = backend.context.toFletchSelector(setter);
        _implicitAccessorTable[setterSelector] = backend.makeSetter(fieldIndex);
      }

      fieldIndex++;
    });
  }

  void createIsFunctionEntry(FletchBackend backend, int arity) {
    int fletchSelector = backend.context.toFletchIsSelector(
        backend.compiler.coreClasses.functionClass);
    addIsSelector(fletchSelector);
    fletchSelector = backend.context.toFletchIsSelector(
        backend.compiler.coreClasses.functionClass, arity);
    addIsSelector(fletchSelector);
  }

  FletchClass finalizeClass(
      FletchContext context,
      List<VmCommand> commands) {
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

    List<FieldElement> fieldsList = new List<FieldElement>(fields);
    int index = 0;
    forEachField(element, (field) {
      fieldsList[index++] = field;
    });

    return new FletchClass(
        classId,
        // TODO(ajohnsen): Take name in FletchClassBuilder constructor.
        element == null ? '<internal>' : element.name,
        element,
        superclass == null ? -1 : superclass.classId,
        superclassFields,
        methodTable,
        fieldsList);
  }

  String toString() => "FletchClassBuilder($element, $classId)";
}

class FletchPatchClassBuilder extends FletchClassBuilder {
  final FletchClass klass;
  final FletchClassBuilder superclass;

  final Map<int, int> _implicitAccessorTable = <int, int>{};
  final Map<int, FletchFunctionBase> _newMethods = <int, FletchFunctionBase>{};
  final Set<FletchFunctionBase> _removedMethods = new Set<FletchFunctionBase>();
  final Set<FieldElement> _removedFields = new Set<FieldElement>();
  final List<int> _removedAccessors = <int>[];
  bool _fieldsChanged = false;

  // TODO(ajohnsen): Reconsider bookkeeping of extra fields (this is really only
  // extra super-class fields).
  int extraFields = 0;

  // TODO(ajohnsen): Can the element change?
  FletchPatchClassBuilder(this.klass, this.superclass);

  int get classId => klass.classId;
  ClassElement get element => klass.element;
  int get fields => klass.fields.length;

  void addToMethodTable(int selector, FletchFunctionBase functionBase) {
    _newMethods[selector] = functionBase;
  }

  void removeFromMethodTable(FletchFunctionBase function) {
    assert(function != null);
    _removedMethods.add(function);
  }

  void removeField(FieldElement field) {
    if (field.enclosingClass != element) extraFields--;
    _fieldsChanged = true;
    _removedFields.add(field);
  }

  void addField(FieldElement field) {
    if (field.enclosingClass != element) extraFields++;
    _fieldsChanged = true;
  }

  void addIsSelector(int selector) {
    // TODO(ajohnsen): Implement.
  }

  void createIsFunctionEntry(FletchBackend backend, int arity) {
    // TODO(ajohnsen): Implement.
  }

  void updateImplicitAccessors(FletchBackend backend) {
    // If we don't have an element (stub class), we don't have anything to
    // generate accessors for.
    if (element == null) return;
    // TODO(ajohnsen): Don't do this once dart2js can enqueue field getters in
    // CodegenEnqueuer.
    int fieldIndex = superclassFields + extraFields;
    element.implementation.forEachInstanceField((enclosing, field) {
      var getter = new Selector.getter(new Name(field.name, field.library));
      int getterSelector = backend.context.toFletchSelector(getter);
      _implicitAccessorTable[getterSelector] = backend.makeGetter(fieldIndex);

      if (!field.isFinal) {
        var setter = new Selector.setter(new Name(field.name, field.library));
        var setterSelector = backend.context.toFletchSelector(setter);
        _implicitAccessorTable[setterSelector] = backend.makeSetter(fieldIndex);
      }

      fieldIndex++;
    });

    for (FieldElement field in _removedFields) {
      Selector getter =
          new Selector.getter(new Name(field.name, field.library));
      int getterSelector = backend.context.toFletchSelector(getter);
      _removedAccessors.add(getterSelector);

      if (!field.isFinal) {
        Selector setter =
            new Selector.setter(new Name(field.name, field.library));
        int setterSelector = backend.context.toFletchSelector(setter);
        _removedAccessors.add(setterSelector);
      }
    }
  }

  PersistentMap<int, int> computeMethodTable() {
    PersistentMap<int, int> methodTable = klass.methodTable;

    for (int selector in _removedAccessors) {
      methodTable = methodTable.delete(selector);
    }

    for (FletchFunctionBase function in _removedMethods) {
      methodTable.forEachKeyValue((int selector, int functionId) {
        if (functionId == function.functionId) {
          methodTable = methodTable.delete(selector);
        }
      });
    }

    // TODO(ajohnsen): Generate this from add/remove field operations.
    _implicitAccessorTable.forEach((int selector, int functionId) {
      methodTable = methodTable.insert(selector, functionId);
    });

    _newMethods.forEach((int selector, FletchFunctionBase function) {
      methodTable = methodTable.insert(selector, function.functionId);
    });

    return methodTable;
  }

  FletchClass finalizeClass(
      FletchContext context,
      List<VmCommand> commands) {
    // TODO(ajohnsen): We need to figure out when to do this. It should be after
    // we have updated class fields, but before we hit 'computeSystem'.
    updateImplicitAccessors(context.backend);

    commands.add(new PushFromMap(MapId.classes, classId));

    PersistentMap<int, int> methodTable = computeMethodTable();
    for (int selector in methodTable.keys.toList()..sort()) {
      int functionId = methodTable[selector];
      commands.add(new PushNewInteger(selector));
      commands.add(new PushFromMap(MapId.methods, functionId));
    }
    commands.add(new ChangeMethodTable(methodTable.length));

    List<FieldElement> fieldsList = <FieldElement>[];
    forEachField(element, (field) { fieldsList.add(field); });

    return new FletchClass(
        classId,
        // TODO(ajohnsen): Take name in FletchClassBuilder constructor.
        element == null ? '<internal>' : element.name,
        element,
        superclass == null ? -1 : superclass.classId,
        superclassFields + extraFields,
        methodTable,
        fieldsList);
  }

  bool computeSchemaChange(List<VmCommand> commands) {
    if (!_fieldsChanged) return false;

    // TODO(ajohnsen): Don't recompute this list.
    List<FieldElement> afterFields = <FieldElement>[];
    forEachField(element, (field) { afterFields.add(field); });

    // TODO(ajohnsen): Handle sub/super classes.
    int numberOfClasses = 1;
    commands.add(new PushFromMap(MapId.classes, classId));

    // Then we push a transformation mapping that tells the runtime system how
    // to build the values for the first part of all instances of the classes.
    // Pre-existing fields that fall after the mapped part will be copied with
    // no changes.
    const VALUE_FROM_ELSEWHERE = 0;
    const VALUE_FROM_OLD_INSTANCE = 1;
    for (int i = 0; i < afterFields.length; i++) {
      FieldElement field = afterFields[i];
      int beforeIndex = klass.fields.indexOf(field);
      if (beforeIndex >= 0) {
        commands.add(const PushNewInteger(VALUE_FROM_OLD_INSTANCE));
        commands.add(new PushNewInteger(beforeIndex));
      } else {
        commands.add(const PushNewInteger(VALUE_FROM_ELSEWHERE));
        commands.add(const PushNull());
      }
    }
    commands.add(new PushNewArray(afterFields.length * 2));

    // Finally, ask the runtime to change the schemas!
    int fieldCountDelta = afterFields.length - klass.fields.length;
    commands.add(new ChangeSchemas(numberOfClasses, fieldCountDelta));

    return true;
  }
}
