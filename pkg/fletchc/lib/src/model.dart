// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.model;

import 'dart:mirrors' as mirrors;

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
   * The definition of the change to the header of the class
   * An empty string implies no change.
   * for example: "class Foo extends Bar"
   */
  String classHeader = "";

  /**
   * A map of how the instance members of [original] should
   * look after this builder has been applied.
   */
  final Map<String, MirrorBuilder> instanceMembers = {};

  /**
   * A map of how the static members of [original] should
   * look after this builder has been applied.
   */
  final Map<String, MirrorBuilder> staticMembers = {};

  /**
   * A map of how the fields of [original] should
   * look after this builder has been applied.
   */
  final Map<String, MirrorBuilder> fields = {};

  ClassBuilder(this.original) {

    // Setup with no changes by default.

    original.staticMembers.forEach((symbol, methodMirror) {
      String name = mirrors.MirrorSystem.getName(symbol);
      staticMembers.putIfAbsent(
        name, () => new MirrorBuilder.fromMirror(methodMirror));
    });

    original.instanceMembers.forEach((symbol, methodMirror) {
      String name = mirrors.MirrorSystem.getName(symbol);
      staticMembers.putIfAbsent(
        name, () => new MirrorBuilder.fromMirror(methodMirror));
    });

    // TODO(lukechurch): Do the same thing for fields.
  }

  /**
   * Construct a new class from [classHeader].
   */
  ClassBuilder.fromEmpty(this.classHeader) : original = null;
}

/**
 * Used to assemble a change to a [ClassBuilder].
 */
class MirrorBuilder {
  final String newSource;
  final mirrors.DeclarationMirror reuseFrom;

  /**
   * Represents a replacement of the implementation of a declaration with
   * a new version from [newSource].
   */
  MirrorBuilder.fromSource(this.newSource)
    : this.reuseFrom = null;

  /**
   * Represents reusing the implementation from [reuseFrom].
   */
  MirrorBuilder.fromMirror(this.reuseFrom)
    : this.newSource = null;

  bool get hasSource => newSource != null;
  bool get isReusing => reuseFrom != null;
}

