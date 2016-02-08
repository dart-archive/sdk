// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_class_builder;

import 'package:compiler/src/dart_types.dart';
import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/universe/selector.dart';
import 'package:persistent/persistent.dart';

import 'dartino_function_builder.dart';
import 'dartino_context.dart';
import 'dartino_backend.dart';

import '../dartino_system.dart';
import '../vm_commands.dart';

// TODO(ahe): Remove this import.
import '../incremental/dartino_compiler_incremental.dart' show
    IncrementalCompilationFailed;

import 'dartino_system_builder.dart' show
    SchemaChange;

import '../dartino_class.dart' show
    DartinoClass;

import '../dartino_class_base.dart' show
    DartinoClassBase;

abstract class DartinoClassBuilder extends DartinoClassBase {
  const DartinoClassBuilder(
      int classId,
      String name,
      ClassElement element,
      int fieldCount)
      : super(classId, name, element, fieldCount);

  DartinoClassBuilder get superclass;

  /**
   * Returns the number of instance fields of all the super classes of this
   * class.
   *
   * If this class has no super class (if it's Object), 0 is returned.
   */
  int get superclassFields => hasSuperClass ? superclass.fieldCount : 0;

  bool get hasSuperClass => superclass != null;

  void addToMethodTable(int selector, DartinoFunctionBase functionBase);
  void removeFromMethodTable(DartinoFunctionBase function);

  // Add a selector for is-tests. The selector is only to be hit with the
  // InvokeTest bytecode, as the function is not guraranteed to be valid.
  void addIsSelector(int selector);
  void createIsFunctionEntry(DartinoBackend backend, int arity);
  void updateImplicitAccessors(DartinoBackend backend);

  DartinoClass finalizeClass(
      DartinoContext context,
      List<VmCommand> commands);

  // The method table for a class is a mapping from Dartino's integer
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

class DartinoNewClassBuilder extends DartinoClassBuilder {
  final DartinoClassBuilder superclass;
  final bool isBuiltin;

  // The extra fields are synthetic fields not represented in any Dart source
  // code. They are used for the synthetic closure classes that are introduced
  // behind the scenes.
  final int extraFields;

  final Map<int, int> _implicitAccessorTable = <int, int>{};
  final Map<int, DartinoFunctionBase> _methodTable =
      <int, DartinoFunctionBase>{};

  DartinoNewClassBuilder(
      int classId,
      ClassElement element,
      DartinoClassBuilder superclass,
      this.isBuiltin,
      int extraFields)
      : superclass = superclass,
        extraFields = extraFields,
        super(classId, element?.name, element,
              computeFields(element, superclass, extraFields));

  static int computeFields(
      ClassElement element,
      DartinoClassBuilder superclass,
      int extraFields) {
    int count = extraFields;
    if (superclass != null) {
      count += superclass.fieldCount;
    }
    if (element != null) {
      element.implementation.forEachInstanceField((_, __) { count++; });
    }
    return count;
  }

  void addToMethodTable(int selector, DartinoFunctionBase functionBase) {
    _methodTable[selector] = functionBase;
  }

  void removeFromMethodTable(DartinoFunctionBase function) {
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
        DartinoFunctionBase function = _methodTable[selector];
        int functionId = function == null ? 0 : function.functionId;
        result = result.insert(selector, functionId);
      } else {
        result = result.insert(selector, _implicitAccessorTable[selector]);
      }
    }
    return result;
  }

  void updateImplicitAccessors(DartinoBackend backend) {
    _implicitAccessorTable.clear();
    // If we don't have an element (stub class), we don't have anything to
    // generate accessors for.
    if (element == null) return;
    // TODO(ajohnsen): Don't do this once dart2js can enqueue field getters in
    // CodegenEnqueuer.
    int fieldIndex = superclassFields;
    element.implementation.forEachInstanceField((enclosing, field) {
      var getter = new Selector.getter(field.memberName);
      int getterSelector = backend.context.toDartinoSelector(getter);
      _implicitAccessorTable[getterSelector] = backend.makeGetter(fieldIndex);

      if (!field.isFinal) {
        var setter = new Selector.setter(new Name(field.name, field.library));
        var setterSelector = backend.context.toDartinoSelector(setter);
        _implicitAccessorTable[setterSelector] = backend.makeSetter(fieldIndex);
      }

      fieldIndex++;
    });
  }

  void createIsFunctionEntry(DartinoBackend backend, int arity) {
    int dartinoSelector = backend.context.toDartinoIsSelector(
        backend.compiler.coreClasses.functionClass);
    addIsSelector(dartinoSelector);
    dartinoSelector = backend.context.toDartinoIsSelector(
        backend.compiler.coreClasses.functionClass, arity);
    addIsSelector(dartinoSelector);
  }

  DartinoClass finalizeClass(
      DartinoContext context,
      List<VmCommand> commands) {
    if (isBuiltin) {
      int nameId = context.getSymbolId(element.name);
      commands.add(new PushBuiltinClass(nameId, fieldCount));
    } else {
      commands.add(new PushNewClass(fieldCount));
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

    List<FieldElement> fieldsList = new List<FieldElement>(fieldCount);
    int index = 0;
    forEachField(element, (field) {
      fieldsList[index++] = field;
    });

    return new DartinoClass(
        classId,
        // TODO(ajohnsen): Take name in DartinoClassBuilder constructor.
        element == null ? '<internal>' : element.name,
        element,
        superclass == null ? -1 : superclass.classId,
        superclassFields,
        methodTable,
        fieldsList);
  }

  String toString() => "DartinoClassBuilder($element, $classId)";
}

class DartinoPatchClassBuilder extends DartinoClassBuilder {
  final DartinoClass klass;

  final DartinoClassBuilder superclass;

  final Map<int, int> _implicitAccessorTable = <int, int>{};

  final Map<int, DartinoFunctionBase> _newMethods =
      <int, DartinoFunctionBase>{};

  final Set<DartinoFunctionBase> _removedMethods =
      new Set<DartinoFunctionBase>();

  final List<FieldElement> _addedFields;

  final List<FieldElement> _removedFields;

  final List<int> _removedAccessors = <int>[];

  final int extraFields;

  DartinoPatchClassBuilder(
      DartinoClass klass,
      this.superclass,
      SchemaChange schemaChange)
      : this.klass = klass,
        this._addedFields =
            new List<FieldElement>.unmodifiable(schemaChange.addedFields),
        this._removedFields =
            new List<FieldElement>.unmodifiable(schemaChange.removedFields),
        this.extraFields = schemaChange.extraSuperFields,
        super(klass.classId, klass.name, klass.element, klass.fieldCount);

  List<FieldElement> get addedFields => _addedFields;
  List<FieldElement> get removedFields => _removedFields;

  void addToMethodTable(int selector, DartinoFunctionBase functionBase) {
    _newMethods[selector] = functionBase;
  }

  void removeFromMethodTable(DartinoFunctionBase function) {
    assert(function != null);
    _removedMethods.add(function);
  }

  void addIsSelector(int selector) {
    // TODO(ajohnsen): Implement.
  }

  void createIsFunctionEntry(DartinoBackend backend, int arity) {
    // TODO(ajohnsen): Implement.
  }

  void updateImplicitAccessors(DartinoBackend backend) {
    // If we don't have an element (stub class), we don't have anything to
    // generate accessors for.
    if (element == null) return;
    // TODO(ajohnsen): Don't do this once dart2js can enqueue field getters in
    // CodegenEnqueuer.
    int fieldIndex = superclassFields + extraFields;
    element.implementation.forEachInstanceField((enclosing, field) {
      var getter = new Selector.getter(new Name(field.name, field.library));
      int getterSelector = backend.context.toDartinoSelector(getter);
      _implicitAccessorTable[getterSelector] = backend.makeGetter(fieldIndex);

      if (!field.isFinal) {
        var setter = new Selector.setter(new Name(field.name, field.library));
        var setterSelector = backend.context.toDartinoSelector(setter);
        _implicitAccessorTable[setterSelector] = backend.makeSetter(fieldIndex);
      }

      fieldIndex++;
    });

    for (FieldElement field in _removedFields) {
      Selector getter =
          new Selector.getter(new Name(field.name, field.library));
      int getterSelector = backend.context.toDartinoSelector(getter);
      _removedAccessors.add(getterSelector);

      if (!field.isFinal) {
        Selector setter =
            new Selector.setter(new Name(field.name, field.library));
        int setterSelector = backend.context.toDartinoSelector(setter);
        _removedAccessors.add(setterSelector);
      }
    }
  }

  PersistentMap<int, int> computeMethodTable() {
    PersistentMap<int, int> methodTable = klass.methodTable;

    for (int selector in _removedAccessors) {
      methodTable = methodTable.delete(selector);
    }

    for (DartinoFunctionBase function in _removedMethods) {
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

    _newMethods.forEach((int selector, DartinoFunctionBase function) {
      methodTable = methodTable.insert(selector, function.functionId);
    });

    return methodTable;
  }

  DartinoClass finalizeClass(
      DartinoContext context,
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

    return new DartinoClass(
        classId,
        // TODO(ajohnsen): Take name in DartinoClassBuilder constructor.
        element == null ? '<internal>' : element.name,
        element,
        superclass == null ? -1 : superclass.classId,
        superclassFields + extraFields,
        methodTable,
        fieldsList);
  }

  bool computeSchemaChange(List<VmCommand> commands) {
    if (_addedFields.isEmpty && _removedFields.isEmpty) return false;

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
