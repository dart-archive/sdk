// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_system;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    ConstructorElement,
    Element,
    FieldElement,
    FunctionSignature;

import 'package:compiler/src/universe/call_structure.dart' show
    CallStructure;

import 'package:persistent/persistent.dart' show
    PersistentMap;

import 'bytecodes.dart';
import 'vm_commands.dart';

import 'src/dartino_selector.dart' show
    DartinoSelector;

import 'src/dartino_system_printer.dart' show
    DartinoSystemPrinter;

import 'dartino_class.dart' show
    DartinoClass;

enum DartinoFunctionKind {
  NORMAL,
  LAZY_FIELD_INITIALIZER,
  INITIALIZER_LIST,
  PARAMETER_STUB,
  ACCESSOR
}

// TODO(ajohnsen): Move to separate file.
class DartinoConstant {
  final int id;
  final MapId mapId;
  const DartinoConstant(this.id, this.mapId);

  String toString() => "DartinoConstant($id, $mapId)";
}

// TODO(ajohnsen): Move to separate file.
abstract class DartinoFunctionBase {
  final int functionId;
  final DartinoFunctionKind kind;
  // TODO(ajohnsen): Merge with function signature?
  final int arity;
  // TODO(ajohnsen): Remove name?
  final String name;
  final Element element;

  /**
   * The signature of the DartinoFunctionBuilder.
   *
   * Some compiled functions does not have a signature (for example, generated
   * accessors).
   */
  final FunctionSignature signature;
  final int memberOf;

  const DartinoFunctionBase(
      this.functionId,
      this.kind,
      this.arity,
      this.name,
      this.element,
      this.signature,
      this.memberOf);

  bool get isInstanceMember => memberOf != null;
  bool get isInternal => element == null;

  bool get isLazyFieldInitializer {
    return kind == DartinoFunctionKind.LAZY_FIELD_INITIALIZER;
  }

  bool get isInitializerList {
    return kind == DartinoFunctionKind.INITIALIZER_LIST;
  }

  bool get isAccessor {
    return kind == DartinoFunctionKind.ACCESSOR;
  }

  bool get isParameterStub {
    return kind == DartinoFunctionKind.PARAMETER_STUB;
  }

  bool get isConstructor => element != null && element.isConstructor;

  String verboseToString();
}

// TODO(ajohnsen): Move to separate file.
class DartinoFunction extends DartinoFunctionBase {
  final List<Bytecode> bytecodes;
  final List<DartinoConstant> constants;

  const DartinoFunction(
      int functionId,
      DartinoFunctionKind kind,
      int arity,
      String name,
      Element element,
      FunctionSignature signature,
      this.bytecodes,
      this.constants,
      int memberOf)
      : super(functionId, kind, arity, name, element, signature, memberOf);

  DartinoFunction withReplacedConstants(List<DartinoConstant> constants) {
    return new DartinoFunction(
        functionId,
        kind,
        arity,
        name,
        element,
        signature,
        bytecodes,
        constants,
        memberOf);
  }

  /// Represents a function we have lost track off, for example, -1 in a
  /// backtrace from the Dartino VM.
  const DartinoFunction.missing()
    : this(
        -1, DartinoFunctionKind.NORMAL, 0, "<missing>", null, null,
        const <Bytecode>[], const <DartinoConstant>[], null);

  String toString() {
    StringBuffer buffer = new StringBuffer();
    buffer.write("DartinoFunction($functionId, '$name'");
    if (isInstanceMember) {
      buffer.write(", memberOf=$memberOf");
    }
    buffer.write(")");
    return buffer.toString();
  }

  String verboseToString() {
    StringBuffer sb = new StringBuffer();

    sb.writeln("Function $functionId, Arity=$arity");
    sb.writeln("Constants:");
    for (int i = 0; i < constants.length; i++) {
      DartinoConstant constant = constants[i];
      sb.writeln("  #$i: $constant");
    }

    sb.writeln("Bytecodes:");
    Bytecode.prettyPrint(sb, bytecodes);

    return '$sb';
  }
}

class ParameterStubSignature {
  final int functionId;
  final CallStructure callStructure;

  const ParameterStubSignature(this.functionId, this.callStructure);

  int get hashCode => functionId ^ callStructure.hashCode;

  bool operator==(other) {
    return other is ParameterStubSignature &&
      other.functionId == functionId &&
      other.callStructure == callStructure;
  }
}

class DartinoSystem {
  // functionsByElement is a subset of functionsById: Some functions do not
  // have an element reference.
  final PersistentMap<int, DartinoFunction> functionsById;
  final PersistentMap<Element, DartinoFunction> functionsByElement;

  final PersistentMap<ConstructorElement, DartinoFunction>
      constructorInitializersByElement;

  final PersistentMap<FieldElement, int> lazyFieldInitializersByElement;

  final PersistentMap<int, int> tearoffsById;

  // classesByElement is a subset of classesById: Some classes do not
  // have an element reference.
  final PersistentMap<int, DartinoClass> classesById;
  final PersistentMap<ClassElement, DartinoClass> classesByElement;

  final PersistentMap<int, DartinoConstant> constantsById;
  final PersistentMap<ConstantValue, DartinoConstant> constantsByValue;

  final PersistentMap<int, String> symbolByDartinoSelectorId;

  final PersistentMap<int, int> gettersByFieldIndex;

  final PersistentMap<int, int> settersByFieldIndex;

  final PersistentMap<ParameterStubSignature, DartinoFunction> parameterStubs;

  const DartinoSystem(
      this.functionsById,
      this.functionsByElement,
      this.constructorInitializersByElement,
      this.lazyFieldInitializersByElement,
      this.tearoffsById,
      this.classesById,
      this.classesByElement,
      this.constantsById,
      this.constantsByValue,
      this.symbolByDartinoSelectorId,
      this.gettersByFieldIndex,
      this.settersByFieldIndex,
      this.parameterStubs);

  bool get isEmpty => functionsById.isEmpty;

  String lookupSymbolBySelector(int dartinoSelector) {
    return symbolByDartinoSelectorId[DartinoSelector.decodeId(dartinoSelector)];
  }

  DartinoFunction lookupFunctionById(int functionId) {
    return functionsById[functionId];
  }

  DartinoFunction lookupFunctionByElement(Element element) {
    return functionsByElement[element];
  }

  Iterable<DartinoFunction> functionsWhere(bool f(DartinoFunction function)) {
    return functionsById.values.where(f);
  }

  DartinoConstant lookupConstantById(int constantId) {
    return constantsById[constantId];
  }

  DartinoConstant lookupConstantByValue(ConstantValue value) {
    return constantsByValue[value];
  }

  DartinoFunction lookupConstructorInitializerByElement(
      ConstructorElement element) {
    return constructorInitializersByElement[element];
  }

  int lookupLazyFieldInitializerByElement(FieldElement field) {
    return lazyFieldInitializersByElement[field];
  }

  /// Map from the ID of a [DartinoFunction] to the ID of its corresponding
  /// tear-off [DartinoFunction].
  ///
  /// To obtain the tear-off corresponding to an [Element], look up the
  /// function in [functionsByElement].
  int lookupTearOffById(int functionId) => tearoffsById[functionId];

  /// Instance field getters can be reused between classes. This method returns
  /// a getter that gets the field at [fieldIndex]. Returns `null` if no such
  /// getter exists.
  int lookupGetterByFieldIndex(int fieldIndex) {
    return gettersByFieldIndex[fieldIndex];
  }

  /// Instance field setters can be reused between classes. This method returns
  /// a setter that sets the field at [fieldIndex]. Returns `null` if no such
  /// setter exists.
  int lookupSetterByFieldIndex(int fieldIndex) {
    return settersByFieldIndex[fieldIndex];
  }

  DartinoClass lookupClassById(int classId) {
    return classesById[classId];
  }

  DartinoClass lookupClassByElement(ClassElement element) {
    return classesByElement[element];
  }

  DartinoFunction lookupParameterStub(ParameterStubSignature signature) {
    return parameterStubs[signature];
  }

  int computeMaxFunctionId() {
    return functionsById.keys.fold(-1, (x, y) => x > y ? x : y);
  }

  int computeMaxClassId() {
    return classesById.keys.fold(-1, (x, y) => x > y ? x : y);
  }

  String toDebugString(Uri base) {
    return new DartinoSystemPrinter(this, base).generateDebugString();
  }
}

class DartinoDelta {
  final DartinoSystem system;
  final DartinoSystem predecessorSystem;
  final List<VmCommand> commands;

  const DartinoDelta(this.system, this.predecessorSystem, this.commands);
}
