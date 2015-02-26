// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(johnniwinther): Temporarily copied from analyzer2dart. Merge when
// we shared code with the analyzer and this semantic visitor is complete.

/**
 * Code for classifying the semantics of identifiers appearing in a Dart file.
 */
library dart2js.access_semantics;

import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/tree/tree.dart';
import 'package:compiler/src/universe/universe.dart';

/**
 * Enum representing the different kinds of destinations which a property
 * access or method or function invocation might refer to.
 */
enum AccessKind {
  /**
   * The destination of the access is an instance method, property, or field
   * of a class, and thus must be determined dynamically.
   */
  DYNAMIC_PROPERTY,

  /**
   * The destination of the access is a function that is defined locally within
   * an enclosing function or method.
   */
  LOCAL_FUNCTION,

  /**
   * The destination of the access is a variable that is defined locally within
   * an enclosing function or method.
   */
  LOCAL_VARIABLE,

  /**
   * The destination of the access is a variable that is defined as a parameter
   * to an enclosing function or method.
   */
  PARAMETER,

  /**
   * The destination of the access is a field that is defined statically within
   * a class, or a top level variable within a library.
   */
  STATIC_FIELD,

  /**
   * The destination of the access is a method that is defined statically
   * within a class, or at top level within a library.
   */
  STATIC_METHOD,

  /**
   * The destination of the access is a property getter that is defined
   * statically within a class, or at top level within a library.
   */
  STATIC_GETTER,

  /**
   * The destination of the access is a property setter that is defined
   * statically within a class, or at top level within a library.
   */
  STATIC_SETTER,

  /**
   * The destination of the access is a field that is defined statically within
   * a class, or a top level variable within a library.
   */
  TOPLEVEL_FIELD,

  /**
   * The destination of the access is a method that is defined statically
   * within a class, or at top level within a library.
   */
  TOPLEVEL_METHOD,

  /**
   * The destination of the access is a property getter that is defined
   * statically within a class, or at top level within a library.
   */
  TOPLEVEL_GETTER,

  /**
   * The destination of the access is a property setter that is defined
   * statically within a class, or at top level within a library.
   */
  TOPLEVEL_SETTER,

  /**
   * The destination of the access is a toplevel class, or mixin application.
   */
  CLASS_TYPE_LITERAL,

  /**
   * The destination of the access is a function typedef.
   */
  TYPEDEF_TYPE_LITERAL,

  /**
   * The destination of the access is the built-in type "dynamic".
   */
  DYNAMIC_TYPE_LITERAL,

  /**
   * The destination of the access is a type parameter of the enclosing class.
   */
  TYPE_PARAMETER_TYPE_LITERAL,

  /**
   * The destination of the access is a (complex) expression. For instance the
   * function expression `(){}` in the function expression invocation `(){}()`.
   */
  EXPRESSION,

  /**
   * The destination of the access is `this` of the enclosing class.
   */
  THIS,

  /**
   * The destination of the access is a property on the enclosing class.
   */
  THIS_PROPERTY,

  /**
   * The destination of the access is a field of the super class of the
   * enclosing class.
   */
  SUPER_FIELD,

  /**
   * The destination of the access is a method of the super class of the
   * enclosing class.
   */
  SUPER_METHOD,

  /**
   * The destination of the access is a getter of the super class of the
   * enclosing class.
   */
  SUPER_GETTER,

  /**
   * The destination of the access is a setter of the super class of the
   * enclosing class.
   */
  SUPER_SETTER,

  /// Compound access where read and write access different elements.
  /// See [CompoundAccessKind].
  COMPOUND,
}

enum CompoundAccessKind {
  /// Read from a static getter and write to static setter.
  STATIC_GETTER_SETTER,
  /// Read from a static method (closurize) and write to static setter.
  STATIC_METHOD_SETTER,

  /// Read from a top level getter and write to a top level setter.
  TOPLEVEL_GETTER_SETTER,
  /// Read from a top level method (closurize) and write to top level setter.
  TOPLEVEL_METHOD_SETTER,

  /// Read from one superclass field and write to another.
  SUPER_FIELD_FIELD,
  /// Read from a superclass field and write to a superclass setter.
  SUPER_FIELD_SETTER,
  /// Read from a superclass getter and write to a superclass setter.
  SUPER_GETTER_SETTER,
  /// Read from a superclass method (closurize) and write to a superclass
  /// setter.
  SUPER_METHOD_SETTER,
  /// Read from a superclass getter and write to a superclass field.
  SUPER_GETTER_FIELD,
}

/**
 * Data structure used to classify the semantics of a property access or method
 * or function invocation.
 */
class AccessSemantics {
  /**
   * The kind of access.
   */
  final AccessKind kind;

  /**
   * The element being accessed, if statically known.  This will be null if
   * [kind] is DYNAMIC or if the element is undefined (e.g. an attempt to
   * access a non-existent static method in a class).
   */
  final Element element;

  /**
   * The class containing the element being accessed, if this is a static
   * reference to an element in a class.  This will be null if [kind] is
   * DYNAMIC, LOCAL_FUNCTION, LOCAL_VARIABLE, PARAMETER, TOPLEVEL_CLASS, or
   * TYPE_PARAMETER, or if the element being accessed is defined at toplevel
   * within a library.
   *
   * Note: it is possible for [classElement] to be non-null and for [element]
   * to be null; for example this occurs if the element being accessed is a
   * non-existent static method or field inside an existing class.
   */
  final ClassElement classElement;

  // TODO(paulberry): would it also be useful to store the libraryElement?

  /**
   * When [kind] is DYNAMIC, the expression whose runtime type determines the
   * class in which [identifier] should be looked up.  Null if the expression
   * is implicit "this".
   *
   * When [kind] is not DYNAMIC, this field is always null.
   */
  final /*Expression*/ target;

  AccessSemantics.dynamicProperty(this.target)
      : kind = AccessKind.DYNAMIC_PROPERTY,
        element = null,
        classElement = null;

  AccessSemantics.localFunction(this.element)
      : kind = AccessKind.LOCAL_FUNCTION,
        classElement = null,
        target = null;

  AccessSemantics.localVariable(this.element)
      : kind = AccessKind.LOCAL_VARIABLE,
        classElement = null,
        target = null;

  AccessSemantics.parameter(this.element)
      : kind = AccessKind.PARAMETER,
        classElement = null,
        target = null;

  AccessSemantics.staticField(this.element, this.classElement)
      : kind = AccessKind.STATIC_FIELD,
        target = null;

  AccessSemantics.staticMethod(this.element, this.classElement)
      : kind = AccessKind.STATIC_METHOD,
        target = null;

  AccessSemantics.staticGetter(this.element, this.classElement)
      : kind = AccessKind.STATIC_GETTER,
        target = null;

  AccessSemantics.staticSetter(this.element, this.classElement)
      : kind = AccessKind.STATIC_SETTER,
        target = null;

  AccessSemantics.topLevelField(this.element)
      : kind = AccessKind.TOPLEVEL_FIELD,
        target = null,
        classElement = null;

  AccessSemantics.topLevelMethod(this.element)
      : kind = AccessKind.TOPLEVEL_METHOD,
        target = null,
        classElement = null;

  AccessSemantics.topLevelGetter(this.element)
      : kind = AccessKind.TOPLEVEL_GETTER,
        target = null,
        classElement = null;

  AccessSemantics.topLevelSetter(this.element)
      : kind = AccessKind.TOPLEVEL_SETTER,
        target = null,
        classElement = null;

  AccessSemantics.classTypeLiteral(this.element)
      : kind = AccessKind.CLASS_TYPE_LITERAL,
        classElement = null,
        target = null;

  AccessSemantics.typedefTypeLiteral(this.element)
      : kind = AccessKind.TYPEDEF_TYPE_LITERAL,
        classElement = null,
        target = null;

  AccessSemantics.dynamicTypeLiteral()
      : kind = AccessKind.DYNAMIC_TYPE_LITERAL,
        element = null,
        classElement = null,
        target = null;

  AccessSemantics.typeParameterTypeLiteral(this.element)
      : kind = AccessKind.TYPE_PARAMETER_TYPE_LITERAL,
        classElement = null,
        target = null;

  AccessSemantics.expression()
      : kind = AccessKind.EXPRESSION,
        element = null,
        classElement = null,
        target = null;

  AccessSemantics.thisAccess()
      : kind = AccessKind.THIS,
        element = null,
        classElement = null,
        target = null;

  AccessSemantics.thisProperty()
      : kind = AccessKind.THIS_PROPERTY,
        element = null,
        classElement = null,
        target = null;

  AccessSemantics.superField(this.element)
      : kind = AccessKind.SUPER_FIELD,
        classElement = null,
        target = null;

  AccessSemantics.superMethod(this.element)
      : kind = AccessKind.SUPER_METHOD,
        classElement = null,
        target = null;

  AccessSemantics.superGetter(this.element)
      : kind = AccessKind.SUPER_GETTER,
        classElement = null,
        target = null;

  AccessSemantics.superSetter(this.element)
      : kind = AccessKind.SUPER_SETTER,
        classElement = null,
        target = null;

  AccessSemantics._compound(this.element, this.classElement)
      : this.kind = AccessKind.COMPOUND,
        this.target = null;

  String toString() {
    StringBuffer sb = new StringBuffer();
    sb.write('AccessSemantics[');
    sb.write('kind=$kind,');
    if (element != null) {
      sb.write('element=');
      if (classElement != null) {
        sb.write('${classElement.name}.');
      }
      sb.write('${element}');
    }
    sb.write(']');
    return sb.toString();
  }
}

class CompoundAccessSemantics extends AccessSemantics {
  final CompoundAccessKind compoundAccessKind;
  final Element getter;

  CompoundAccessSemantics(this.compoundAccessKind,
                          this.getter,
                          Element setter,
                          {ClassElement classElement})
      : super._compound(setter, classElement);

  Element get setter => element;
}
