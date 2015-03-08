// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.model;

import 'dart:mirrors' as mirrors;

/**
 * A marker object representing reusing an existing element.
 */
final Object REUSE_EXISTING = new Object();

/**
 * Indirection from the class mirror. This allows us to adapt the interface
 * here as needed.
 */
class ClassMirror implements mirrors.ClassMirror {
  mirrors.ClassMirror _raw;

  Map<Symbol, mirrors.DeclarationMirror> get declarations => _raw.declarations;

  mirrors.InstanceMirror getField(Symbol fieldName) => _raw.getField(fieldName);

  bool get hasReflectedType => _raw.hasReflectedType;

  Map<Symbol, mirrors.MethodMirror> get instanceMembers => _raw.instanceMembers;

  bool get isAbstract => _raw.isAbstract;

  bool isAssignableTo(mirrors.TypeMirror other) => _raw.isAssignableTo(other);

  bool get isEnum => _raw.isEnum;

  bool get isOriginalDeclaration => _raw.isOriginalDeclaration;

  bool get isPrivate => _raw.isPrivate;

  bool isSubclassOf(mirrors.ClassMirror other) => _raw.isSubclassOf(other);

  bool isSubtypeOf(mirrors.TypeMirror other) => _raw.isSubtypeOf(other);

  bool get isTopLevel => _raw.isTopLevel;

  mirrors.SourceLocation get location => _raw.location;

  mirrors.ClassMirror get mixin => _raw.mixin;

  List<mirrors.InstanceMirror> get metadata => _raw.metadata;

  mirrors.ClassMirror get superclass => _raw.superclass;

  List<mirrors.ClassMirror> get superinterfaces => _raw.superinterfaces;

  List<mirrors.TypeMirror> get typeArguments => _raw.typeArguments;

  List<mirrors.TypeVariableMirror> get typeVariables => _raw.typeVariables;

  mirrors.TypeMirror get originalDeclaration => _raw.originalDeclaration;

  mirrors.DeclarationMirror get owner => _raw.owner;

  Symbol get qualifiedName => _raw.qualifiedName;

  Type get reflectedType => _raw.reflectedType;

  Symbol get simpleName => _raw.simpleName;

  Map<Symbol, mirrors.MethodMirror> get staticMembers => _raw.staticMembers;

  mirrors.InstanceMirror newInstance(
    Symbol constructorName,
    List positionalArguments,
    [Map<Symbol, dynamic> namedArguments]) {
    throw ("Not implemented here.");
  }

  mirrors.InstanceMirror invoke(
    Symbol memberName,
    List positionalArguments,
    [Map<Symbol, dynamic> namedArguments]) {
    throw ("Not implemented here.");
  }

  mirrors.InstanceMirror setField(Symbol fieldName, Object value) {
    throw ("Not implemented here.");
  }

  ClassBuilder get builder {
    return new ClassBuilder(this);
  }

}

/**
 * [ClassBuilder] represents a set of changes to be previewed or applied
 * to a class.
 */
class ClassBuilder {
  /**
   * Should the entire class be deleted?
   */
  bool deleteClass = false;

  /**
   * The class mirror that this builder was derived from.
   */
  final ClassMirror original;

  /**
   * The definition of the change to signature of the class
   * An empty string implies no change.
   */
  String signatureDeclaration = "";

  /**
   * A map of changes to be applied to the instance members.
   * The changes are of the form name -> declaration.
   * The declarations may be either a string representing the new form or
   * REUSE_EXISTING.
   * If a name isn't included in the map, the associated entity will be
   * deleted when the change is applied.
   */
  final Map<String, Object> instanceMembers = {};

  /**
   * A map of changes to be applied to the static members.
   * The changes are of the form name -> declaration.
   * The declarations may be either a string representing the new form or
   * REUSE_EXISTING.
   * If a name isn't included in the map, the associated entity will be
   * deleted when the change is applied.
   */
  final Map<String, Object> staticMembers = {};

  /**
   * A map of changes to be applied to the fields.
   * The changes are of the form name -> declaration.
   * The declarations may be either a string representing the new form or
   * REUSE_EXISTING.
   * If a name isn't included in the map, the associated entity will be
   * deleted when the change is applied.
   */
  final Map<String, Object> fields = {};

  ClassBuilder(this.original) {
    // TODO(lukechurch): Populate the instance members and static maps with
    // REUSE_EXISTING.
  }
}
