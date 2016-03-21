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

import '../dartino_system.dart';
import '../vm_commands.dart';

// TODO(ahe): Remove this import.
import '../incremental/dartino_compiler_incremental.dart' show
    IncrementalCompilationFailed;

import 'dartino_system_builder.dart' show
    DartinoSystemBuilder,
    SchemaChange;

import '../dartino_class.dart' show
    DartinoClass;

import '../dartino_class_base.dart' show
    DartinoClassBase;

import '../dartino_field.dart' show
    DartinoField;

import 'element_utils.dart' show
    computeFields;

abstract class DartinoClassBuilder extends DartinoClassBase {
  final DartinoSystemBuilder builder;

  const DartinoClassBuilder(
      int classId,
      String name,
      ClassElement element,
      int fieldCount,
      this.builder)
      : super(classId, name, element, fieldCount);

  factory DartinoClassBuilder.newClass(
      int classId,
      ClassElement element,
      DartinoClassBase superclass,
      bool isBuiltin,
      List<DartinoField> extraFields,
      DartinoSystemBuilder builder) {
    List<DartinoField> mixedInFields = extraFields;
    if (element != null) {
      // Make a copy to avoid modifying caller's list.
      mixedInFields = new List<DartinoField>.from(extraFields)
          ..addAll(
              computeFields(element, asMixin: true).map(
                  (FieldElement field) => new DartinoField(field)));
    }
    String name = element?.name;
    if (name == null) {
      name = "<subclass of ${superclass.name}>";
    }
    int fieldCount = mixedInFields.length;
    if (superclass != null) {
      fieldCount += superclass.fieldCount;
    }
    return new DartinoNewClassBuilder(
        classId, element, name, superclass, isBuiltin, fieldCount,
        mixedInFields, builder)
        ..validate();
  }

  factory DartinoClassBuilder.patch(
      DartinoClass klass,
      DartinoClassBase superclass,
      SchemaChange schemaChange,
      DartinoSystemBuilder builder) {
    List<DartinoField> mixedInFields = klass.mixedInFields;
    return
        new DartinoPatchClassBuilder(klass, superclass, schemaChange, builder)
        ..validate();
  }

  DartinoClassBase get superclass;
  int get superclassId => hasSuperClass ? superclass.classId : -1;

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
  void createIsFunctionEntry(ClassElement functionClass, int arity);
  void updateImplicitAccessors();

  DartinoClass finalizeClass(List<VmCommand> commands);

  // The method table for a class is a mapping from Dartino's integer
  // selectors to method ids. It contains all methods defined for a
  // class including the implicit accessors. The returned map is not sorted.
  // TODO(ajohnsen): Remove once not used by feature_test anymore.
  PersistentMap<int, int> computeMethodTable();

  bool computeSchemaChange(List<VmCommand> commands) {
    return false;
  }

  void validate();
}

class DartinoNewClassBuilder extends DartinoClassBuilder {
  final DartinoClassBase superclass;
  final bool isBuiltin;

  final List<DartinoField> mixedInFields;

  final Map<int, int> _implicitAccessorTable = <int, int>{};
  final Map<int, DartinoFunctionBase> _methodTable =
      <int, DartinoFunctionBase>{};

  DartinoNewClassBuilder(
      int classId,
      ClassElement element,
      String name,
      this.superclass,
      this.isBuiltin,
      int fieldCount,
      this.mixedInFields,
      DartinoSystemBuilder builder)
      : super(classId, name, element, fieldCount, builder);

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

  void updateImplicitAccessors() {
    _implicitAccessorTable.clear();
    // TODO(ajohnsen): Don't do this once dart2js can enqueue field getters in
    // CodegenEnqueuer.
    int fieldIndex = superclassFields - 1;
    for (DartinoField dartinoField in mixedInFields) {
      fieldIndex++;
      if (dartinoField.isBoxed) continue;
      FieldElement field = dartinoField.element;
      int getterSelector = builder.toDartinoGetterSelector(field.memberName);
      _implicitAccessorTable[getterSelector] =
          builder.getGetterByFieldIndex(fieldIndex);

      if (!field.isFinal) {
        int setterSelector = builder.toDartinoSetterSelector(field.memberName);
        _implicitAccessorTable[setterSelector] =
            builder.getSetterByFieldIndex(fieldIndex);
      }
    }
  }

  void createIsFunctionEntry(ClassElement functionClass, int arity) {
    int dartinoSelector = builder.toDartinoIsSelector(functionClass);
    addIsSelector(dartinoSelector);
    dartinoSelector = builder.toDartinoIsSelector(functionClass, arity);
    addIsSelector(dartinoSelector);
  }

  DartinoClass finalizeClass(List<VmCommand> commands) {
    if (isBuiltin) {
      int nameId = builder.getSymbolId(element.name);
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
    return new DartinoClass.validated(
        classId,
        // TODO(ajohnsen): Take name in DartinoClassBuilder constructor.
        element == null ? '<internal>' : element.name,
        element,
        superclass == null ? -1 : superclass.classId,
        superclassFields,
        methodTable,
        mixedInFields);
  }

  void validate() {
    assert(element == null || fieldCount == computeFields(element).length);
  }

  String toString() => "DartinoNewClassBuilder($element, $classId)";
}

class DartinoPatchClassBuilder extends DartinoClassBuilder {
  final DartinoClass klass;

  final DartinoClassBase superclass;

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
      SchemaChange schemaChange,
      DartinoSystemBuilder builder)
      : this.klass = klass,
        this._addedFields =
            new List<FieldElement>.unmodifiable(schemaChange.addedFields),
        this._removedFields =
            new List<FieldElement>.unmodifiable(schemaChange.removedFields),
        this.extraFields = schemaChange.extraSuperFields,
        super(klass.classId, klass.name, klass.element,
              klass.element == null
                  ? klass.fieldCount : computeFields(klass.element).length,
              builder);

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

  void createIsFunctionEntry(ClassElement functionClass, int arity) {
    // TODO(ajohnsen): Implement.
  }

  void updateImplicitAccessors() {
    _implicitAccessorTable.clear();
    // If we don't have an element (stub class), we don't have anything to
    // generate accessors for.
    if (element == null) return;
    // TODO(ajohnsen): Don't do this once dart2js can enqueue field getters in
    // CodegenEnqueuer.
    int fieldIndex = superclassFields;
    element.implementation.forEachInstanceField((enclosing, field) {
      int getterSelector = builder.toDartinoGetterSelector(field.memberName);
      int getter = builder.getGetterByFieldIndex(fieldIndex);
      assert(_implicitAccessorTable[getterSelector] == null);
      _implicitAccessorTable[getterSelector] = getter;
      if (!field.isFinal) {
        int setterSelector = builder.toDartinoSetterSelector(field.memberName);
        int setter = builder.getSetterByFieldIndex(fieldIndex);
        assert(_implicitAccessorTable[setterSelector] == null);
        _implicitAccessorTable[setterSelector] = setter;
      }

      fieldIndex++;
    });

    for (FieldElement field in _removedFields) {
      _removedAccessors.add(builder.toDartinoGetterSelector(field.memberName));
      if (!field.isFinal) {
        _removedAccessors.add(
            builder.toDartinoSetterSelector(field.memberName));
      }
    }
    assert(validateImplicitAccessors());
  }

  bool validateImplicitAccessors() {
    bool result = true;
    int fieldIndex = 0;
    for (FieldElement field in computeFields(element)) {
      int getterSelector = builder.toDartinoGetterSelector(field.memberName);
      int expectedGetter = builder.getGetterByFieldIndex(fieldIndex);
      int actualGetter = _implicitAccessorTable[getterSelector];
      if (element.enclosingClass == field.enclosingClass &&
          expectedGetter != actualGetter) {
        print("Internal error: implicit getter for $field ($fieldIndex) "
              "is $actualGetter ($getterSelector).");
        result = false;
      }

      if (!field.isFinal) {
        int setterSelector = builder.toDartinoSetterSelector(field.memberName);
        int expectedSetter = builder.getSetterByFieldIndex(fieldIndex);
        int actualSetter = _implicitAccessorTable[setterSelector];
        if (element.enclosingClass == field.enclosingClass &&
            expectedSetter != actualSetter) {
          print("Internal error: implicit setter for $field ($fieldIndex) "
                "is $actualSetter ($setterSelector).");
          result = false;
        }
      }
      fieldIndex++;
    }
    return result;
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

  DartinoClass finalizeClass(List<VmCommand> commands) {
    // TODO(ajohnsen): We need to figure out when to do this. It should be after
    // we have updated class fields, but before we hit 'computeSystem'.
    updateImplicitAccessors();

    commands.add(new PushFromMap(MapId.classes, classId));

    PersistentMap<int, int> methodTable = computeMethodTable();
    for (int selector in methodTable.keys.toList()..sort()) {
      int functionId = methodTable[selector];
      commands.add(new PushNewInteger(selector));
      commands.add(new PushFromMap(MapId.methods, functionId));
    }
    commands.add(new ChangeMethodTable(methodTable.length));

    Iterable<DartinoField> existingFields = klass.mixedInFields.where(
        (DartinoField field) => !_removedFields.contains(field.element));
    Iterable<DartinoField> myAddedFields = _addedFields
        .where((FieldElement field) => field.enclosingClass == klass.element)
        .map((FieldElement field) => new DartinoField(field));

    List<DartinoField> mixedInFields =
        new List<DartinoField>.from(existingFields)..addAll(myAddedFields);

    return new DartinoClass.validated(
        classId, klass.name, element,
        superclass == null ? -1 : superclass.classId, superclassFields,
        methodTable, mixedInFields);
  }

  bool computeSchemaChange(List<VmCommand> commands) {
    if (_addedFields.isEmpty && _removedFields.isEmpty) return false;

    // TODO(ajohnsen): Don't recompute this list.
    List<FieldElement> afterFields = computeFields(element);

    // TODO(ajohnsen): Handle sub/super classes.
    int numberOfClasses = 1;
    commands.add(new PushFromMap(MapId.classes, classId));

    // Then we push a transformation mapping that tells the runtime system how
    // to build the values for the first part of all instances of the classes.
    // Pre-existing fields that fall after the mapped part will be copied with
    // no changes.
    const VALUE_FROM_ELSEWHERE = 0;
    const VALUE_FROM_OLD_INSTANCE = 1;
    List<DartinoField> beforeFields =
        builder.predecessorSystem.computeAllFields(klass);
    for (int i = 0; i < afterFields.length; i++) {
      FieldElement field = afterFields[i];
      int beforeIndex = beforeFields.indexOf(new DartinoField(field));
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
    int fieldCountDelta = afterFields.length - beforeFields.length;
    commands.add(new ChangeSchemas(numberOfClasses, fieldCountDelta));

    return true;
  }

  void validate() {
    if (element == null) return;
    List<FieldElement> fields = computeFields(element);
    if (fieldCount != fields.length) {
      throw """$this $fieldCount != ${fields.length}
fields: $fields
addedFields: $addedFields
removedFields: $removedFields
""";
    }
    int mixinFieldCount = 0;
    for (FieldElement field in fields) {
      if (field.enclosingClass.declaration == element.declaration) {
        mixinFieldCount++;
      }
    }
    if (fieldCount - mixinFieldCount != superclassFields) {
      throw """$fieldCount - $mixinFieldCount != $superclassFields
fields: $fields
""";
    }
  }

  String toString() => "DartinoPatchClassBuilder($element, $classId)";
}
