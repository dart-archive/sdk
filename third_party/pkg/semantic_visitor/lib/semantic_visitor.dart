// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart2js.semantics_visitor;

import 'access_semantics.dart';
import 'send_structure.dart';
import 'operators.dart';

import 'package:compiler/src/resolution/resolution.dart';
import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/tree/tree.dart';
import 'package:compiler/src/universe/universe.dart';
import 'package:compiler/src/util/util.dart' show
    Spannable,
    SpannableAssertionFailure;
import 'package:compiler/src/dart_types.dart';


enum SendStructureKind {
  GET,
  SET,
  INVOKE,
  UNARY,
  NOT,
  BINARY,
  EQ,
  NOT_EQ,
  COMPOUND,
  INDEX_SET,
  COMPOUND_INDEX_SET,
  PREFIX,
  POSTFIX,
}

abstract class SendResolverMixin {
  TreeElements get elements;

  internalError(Spannable spannable, String message);

  AccessSemantics handleStaticallyResolvedAccess(Send node,
                                                 Element element,
                                                 Element getter) {
    if (element.isParameter) {
      return new AccessSemantics.parameter(element);
    } else if (element.isLocal) {
      if (element.isFunction) {
        return new AccessSemantics.localFunction(element);
      } else {
        return new AccessSemantics.localVariable(element);
      }
    } else if (element.isStatic) {
      if (element.isField) {
        return new AccessSemantics.staticField(element, element.enclosingClass);
      } else if (element.isGetter) {
        return new AccessSemantics.staticGetter(
            element,
            element.enclosingClass);
      } else if (element.isSetter) {
        if (getter != null) {
          CompoundAccessKind accessKind;
          if (getter.isGetter) {
            accessKind = CompoundAccessKind.STATIC_GETTER_SETTER;
          } else {
            accessKind = CompoundAccessKind.STATIC_METHOD_SETTER;
          }
          return new CompoundAccessSemantics(
              accessKind, getter, element,
              classElement: element.enclosingClass);
        } else {
          return new AccessSemantics.staticSetter(
              element,
              element.enclosingClass);
        }
      } else {
        return new AccessSemantics.staticMethod(
            element,
            element.enclosingClass);
      }
    } else if (element.isTopLevel) {
      if (element.isField) {
        return new AccessSemantics.topLevelField(element);
      } else if (element.isGetter) {
        return new AccessSemantics.topLevelGetter(element);
      } else if (element.isSetter) {
        if (getter != null) {
          CompoundAccessKind accessKind;
          if (getter.isGetter) {
            accessKind = CompoundAccessKind.TOPLEVEL_GETTER_SETTER;
          } else {
            accessKind = CompoundAccessKind.TOPLEVEL_METHOD_SETTER;
          }
          return new CompoundAccessSemantics(
              accessKind, getter, element);
        } else {
          return new AccessSemantics.topLevelSetter(element);
        }
      } else {
        return new AccessSemantics.topLevelMethod(element);
      }
    } else {
      return internalError(
          node, "Unhandled resolved property access: $element");
    }
  }


  SendStructure computeSendStructure(Send node) {
    if (elements.isAssert(node)) {
      return const AssertStructure();
    }

    AssignmentOperator assignmentOperator;
    UnaryOperator unaryOperator;
    BinaryOperator binaryOperator;
    IncDecOperator incDecOperator;

    if (node.isOperator) {
      String operatorText = node.selector.asOperator().source;
      if (operatorText == 'is') {
        if (node.isIsNotCheck) {
          return new IsNotStructure(
              elements.getType(node.arguments.single.asSend().receiver));
        } else {
          return new IsStructure(elements.getType(node.arguments.single));
        }
      } else if (operatorText == 'as') {
        return new AsStructure(elements.getType(node.arguments.single));
      } else if (operatorText == '&&') {
        return const LazyAndStructure();
      } else if (operatorText == '||') {
        return const LazyOrStructure();
      }
    }

    SendStructureKind kind;

    if (node.asSendSet() != null) {
      SendSet sendSet = node.asSendSet();
      String operatorText = sendSet.assignmentOperator.source;
      if (sendSet.isPrefix || sendSet.isPostfix) {
        kind = sendSet.isPrefix
            ? SendStructureKind.PREFIX
            : SendStructureKind.POSTFIX;
        incDecOperator = IncDecOperator.parse(operatorText);
        if (incDecOperator == null) {
          return internalError(
              node, "No inc/dec operator for '$operatorText'.");
        }
      } else {
        assignmentOperator = AssignmentOperator.parse(operatorText);
        if (assignmentOperator != null) {
          switch (assignmentOperator.kind) {
          case AssignmentOperatorKind.ASSIGN:
            kind = SendStructureKind.SET;
            break;
          default:
            kind = SendStructureKind.COMPOUND;
          }
        } else {
          return internalError(
              node, "No assignment operator for '$operatorText'.");
        }
      }
    } else if (!node.isPropertyAccess) {
      kind = SendStructureKind.INVOKE;
    } else {
      kind = SendStructureKind.GET;
    }

    if (node.isOperator) {
      String operatorText = node.selector.asOperator().source;
      if (node.arguments.isEmpty) {
        unaryOperator = UnaryOperator.parse(operatorText);
        if (unaryOperator != null) {
          switch (unaryOperator.kind) {
          case UnaryOperatorKind.NOT:
            kind = SendStructureKind.NOT;
            break;
          default:
            kind = SendStructureKind.UNARY;
            break;
          }
        } else {
          return internalError(node, "No unary operator for '$operatorText'.");
        }
      } else {
        binaryOperator = BinaryOperator.parse(operatorText);
        if (binaryOperator != null) {
          switch (binaryOperator.kind) {
          case BinaryOperatorKind.EQ:
            kind = SendStructureKind.EQ;
            break;
          case BinaryOperatorKind.NOT_EQ:
            kind = SendStructureKind.NOT_EQ;
            break;
          case BinaryOperatorKind.INDEX:
            if (node.arguments.tail.isEmpty) {
              // a[b]
              kind = SendStructureKind.BINARY;
            } else {
              if (kind == SendStructureKind.COMPOUND) {
                // a[b] += c
                kind = SendStructureKind.COMPOUND_INDEX_SET;
              } else {
                // a[b] = c
                kind = SendStructureKind.INDEX_SET;
              }
            }
            break;
          default:
            kind = SendStructureKind.BINARY;
            break;
          }
        } else {
          return internalError(node, "No binary operator for '$operatorText'.");
        }
      }
    }
    AccessSemantics semantics = computeAccessSemantics(
        node,
        isGetOrSet: kind == SendStructureKind.GET ||
                    kind == SendStructureKind.SET,
        isCompound: kind == SendStructureKind.COMPOUND ||
                    kind == SendStructureKind.COMPOUND_INDEX_SET ||
                    kind == SendStructureKind.PREFIX ||
                    kind == SendStructureKind.POSTFIX);
    if (semantics == null) {
      internalError(node, 'No semantics for $node');
    }
    Selector selector = elements.getSelector(node);
    switch (kind) {
    case SendStructureKind.GET:
      return new GetStructure(semantics, selector);
    case SendStructureKind.SET:
      return new SetStructure(semantics, selector);
    case SendStructureKind.INVOKE:
      return new InvokeStructure(semantics, selector);
    case SendStructureKind.UNARY:
      return new UnaryStructure(semantics, unaryOperator, selector);
    case SendStructureKind.NOT:
      return new NotStructure(semantics, selector);
    case SendStructureKind.BINARY:
      return new BinaryStructure(semantics, binaryOperator, selector);
    case SendStructureKind.EQ:
      return new EqualsStructure(semantics, selector);
    case SendStructureKind.NOT_EQ:
      return new NotEqualsStructure(semantics, selector);
    case SendStructureKind.COMPOUND:
      Selector getterSelector =
          elements.getGetterSelectorInComplexSendSet(node);
      return new CompoundStructure(
          semantics,
          assignmentOperator,
          getterSelector,
          selector);
    case SendStructureKind.INDEX_SET:
      return new IndexSetStructure(semantics, selector);
    case SendStructureKind.COMPOUND_INDEX_SET:
      Selector getterSelector =
          elements.getGetterSelectorInComplexSendSet(node);
      return new CompoundIndexSetStructure(
          semantics,
          assignmentOperator,
          getterSelector,
          selector);
    case SendStructureKind.PREFIX:
      Selector getterSelector =
          elements.getGetterSelectorInComplexSendSet(node);
      return new PrefixStructure(
          semantics,
          incDecOperator,
          getterSelector,
          selector);
    case SendStructureKind.POSTFIX:
      Selector getterSelector =
          elements.getGetterSelectorInComplexSendSet(node);
      return new PostfixStructure(
          semantics,
          incDecOperator,
          getterSelector,
          selector);
    }
  }

  AccessSemantics computeAccessSemantics(Send node,
                                         {bool isGetOrSet: false,
                                          bool isCompound: false}) {
    Element element = elements[node];
    Element getter = isCompound ? elements[node.selector] : null;
    if (elements.isTypeLiteral(node)) {
      DartType dartType = elements.getTypeLiteralType(node);
      switch (dartType.kind) {
      case TypeKind.INTERFACE:
        return new AccessSemantics.classTypeLiteral(dartType.element);
      case TypeKind.TYPEDEF:
        return new AccessSemantics.typedefTypeLiteral(dartType.element);
      case TypeKind.TYPE_VARIABLE:
        return new AccessSemantics.typeParameterTypeLiteral(dartType.element);
      case TypeKind.DYNAMIC:
        return new AccessSemantics.dynamicTypeLiteral();
      default:
        return internalError(node, "Unexpected type literal type: $dartType");
      }
    } else if (node.isSuperCall) {
      if (!Elements.isUnresolved(element)) {
        if (element.isField) {
          if (getter != null && getter != element) {
            CompoundAccessKind accessKind;
            if (getter.isField) {
              accessKind = CompoundAccessKind.SUPER_FIELD_FIELD;
            } else if (getter.isGetter) {
              accessKind = CompoundAccessKind.SUPER_GETTER_FIELD;
            } else {
              return internalError(node,
                 "Unsupported super call: $node : $element/$getter.");
            }
            return new CompoundAccessSemantics(accessKind, getter, element);
          }
          return new AccessSemantics.superField(element);
        } else if (element.isGetter) {
          return new AccessSemantics.superGetter(element);
        } else if (element.isSetter) {
          if (getter != null) {
            CompoundAccessKind accessKind;
            if (getter.isField) {
              accessKind = CompoundAccessKind.SUPER_FIELD_SETTER;
            } else if (getter.isGetter) {
              accessKind = CompoundAccessKind.SUPER_GETTER_SETTER;
            } else {
              accessKind = CompoundAccessKind.SUPER_METHOD_SETTER;
            }
            return new CompoundAccessSemantics(accessKind, getter, element);
          }
          return new AccessSemantics.superSetter(element);
        } else {
          return new AccessSemantics.superMethod(element);
        }
      } else {
        return internalError(node, "Unsupported super call: $node : $element.");
      }
    } else if (node.isOperator) {
      return new AccessSemantics.dynamicProperty(node.receiver);
    } else if (isGetOrSet) {
      if (!Elements.isUnresolved(element) && element.impliesType) {
        // Prefix of a static access.
        return null;
      } else if (element == null || element.isInstanceMember) {
        if (node.receiver == null || node.receiver.isThis()) {
          return new AccessSemantics.thisProperty();
        } else {
          return new AccessSemantics.dynamicProperty(node.receiver);
        }
      } else {
        return handleStaticallyResolvedAccess(node, element, getter);
      }
    } else if (element != null && Initializers.isConstructorRedirect(node)) {
      return handleStaticallyResolvedAccess(node, element, getter);
    } else if (Elements.isClosureSend(node, element)) {
      if (element == null) {
        if (node.selector.isThis()) {
          return new AccessSemantics.thisAccess();
        } else {
          return new AccessSemantics.expression();
        }
      } else if (!Elements.isUnresolved(element)) {
        return handleStaticallyResolvedAccess(node, element, getter);
      }
      // TODO(johnniwinther): Handle this.
      return internalError(node, "Erroneous closure send unsupported.");
    } else {
      if (Elements.isUnresolved(element)) {
        if (element == null) {
          if (node.receiver == null || node.receiver.isThis()) {
            // Example: f() with 'f' unbound.
            // This can only happen inside an instance method.
            return new AccessSemantics.thisProperty();
          } else {
            return new AccessSemantics.dynamicProperty(node.receiver);
          }
        } else {
          // TODO(johnniwinther): Handle this.
          return internalError(node,
                               "Statically unresolved access unsupported.");
        }
      } else if (element.isInstanceMember) {
        // Example: f() with 'f' bound to instance method.
        if (node.receiver == null || node.receiver.isThis()) {
          return new AccessSemantics.thisProperty();
        } else {
          return new AccessSemantics.dynamicProperty(node.receiver);
        }
      } else if (!element.isInstanceMember) {
        // Example: A.f() or f() with 'f' bound to a static function.
        // Also includes new A() or new A.named() which is treated like a
        // static call to a factory.
        return handleStaticallyResolvedAccess(node, element, getter);
      } else {
        internalError(node, "Cannot generate code for send");
        return null;
      }
    }
  }
}

abstract class SemanticVisitor<R, A> extends Visitor<R>
    with SendResolverMixin {
  TreeElements elements;

  SemanticVisitor(this.elements);

  SemanticSendVisitor<R, A> sendVisitor;

  @override
  R visitIdentifier(Identifier node) {
    // TODO(johnniwinther): Support argument.
    A arg = null;
    if (node.isThis()) {
      // TODO(johnniwinther): Parse `this` as a [Send] whose selector is `this`
      // to normalize with `this(...)`.
      return sendVisitor.visitThisGet(node, arg);
    }
    //internalError(node, "Unhandled identifier: $node");
    return null;
  }

  @override
  R visitSend(Send node) {
    // TODO(johnniwinther): Support argument.
    A arg = null;

    SendStructure structure = computeSendStructure(node);
    if (structure == null) {
      return internalError(node, 'No structure for $node');
    } else {
      return structure.dispatch(sendVisitor, node, arg);
    }
  }

  @override
  R visitSendSet(SendSet node) {
    return visitSend(node);
  }
}

abstract class SemanticSendVisitor<R, A> {
  R apply(Node node, A arg);

  /// Read of the [parameter].
  ///
  /// For instance:
  ///     m(parameter) => parameter;
  ///
  R visitParameterGet(
      Send node,
      ParameterElement parameter,
      A arg);

  /// Assignment of [rhs] to the [parameter].
  ///
  /// For instance:
  ///     m(parameter) {
  ///       parameter = rhs;
  ///     }
  ///
  R visitParameterSet(
      SendSet node,
      ParameterElement parameter,
      Node rhs,
      A arg);

  /// Assignment of [rhs] to the final [parameter].
  ///
  /// For instance:
  ///     m(final parameter) {
  ///       parameter = rhs;
  ///     }
  ///
  R errorFinalParameterSet(
      SendSet node,
      ParameterElement parameter,
      Node rhs,
      A arg);

  /// Invocation of the [parameter] with [arguments].
  ///
  /// For instance:
  ///     m(parameter) {
  ///       parameter(null, 42);
  ///     }
  ///
  R visitParameterInvoke(
      Send node,
      ParameterElement parameter,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Read of the local [variable].
  ///
  /// For instance:
  ///     m() {
  ///       var variable;
  ///       return variable;
  ///     }
  ///
  R visitLocalVariableGet(
      Send node,
      LocalVariableElement variable,
      A arg);

  /// Assignment of [rhs] to the local [variable].
  ///
  /// For instance:
  ///     m() {
  ///       var variable;
  ///       variable = rhs;
  ///     }
  ///
  R visitLocalVariableSet(
      SendSet node,
      LocalVariableElement variable,
      Node rhs,
      A arg);

  /// Assignment of [rhs] to the final local [variable].
  ///
  /// For instance:
  ///     m() {
  ///       final variable = null;
  ///       variable = rhs;
  ///     }
  ///
  R errorFinalLocalVariableSet(
      SendSet node,
      LocalVariableElement variable,
      Node rhs,
      A arg);

  /// Invocation of the local variable [variable] with [arguments].
  ///
  /// For instance:
  ///     m() {
  ///       var variable;
  ///       variable(null, 42);
  ///     }
  ///
  R visitLocalVariableInvoke(
      Send node,
      LocalVariableElement variable,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Closurization of the local [function].
  ///
  /// For instance:
  ///     m() {
  ///       o(a, b) {}
  ///       return o;
  ///     }
  ///
  R visitLocalFunctionGet(
      Send node,
      LocalFunctionElement function,
      A arg);

  /// Assignment of [rhs] to the local [function].
  ///
  /// For instance:
  ///     m() {
  ///       o(a, b) {}
  ///       o = rhs;
  ///     }
  ///
  R errorLocalFunctionSet(
      SendSet node,
      LocalFunctionElement function,
      Node rhs,
      A arg);

  /// Invocation of the local [function] with [arguments].
  ///
  /// For instance:
  ///     m() {
  ///       o(a, b) {}
  ///       return o(null, 42);
  ///     }
  ///
  R visitLocalFunctionInvoke(
      Send node,
      LocalFunctionElement function,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Getter call on [receiver] of the property defined by [selector].
  ///
  /// For instance
  ///     m(receiver) => receiver.foo;
  ///
  R visitDynamicPropertyGet(
      Send node,
      Node receiver,
      Selector selector,
      A arg);

  /// Setter call on [receiver] with argument [rhs] of the property defined by
  /// [selector].
  ///
  /// For instance
  ///     m(receiver) {
  ///       receiver.foo = rhs;
  ///     }
  ///
  R visitDynamicPropertySet(
      SendSet node,
      Node receiver,
      Selector selector,
      Node rhs,
      A arg);

  /// Invocation of the property defined by [selector] on [receiver] with
  /// [arguments].
  ///
  /// For instance
  ///     m(receiver) {
  ///       receiver.foo(null, 42);
  ///     }
  ///
  R visitDynamicPropertyInvoke(
      Send node,
      Node receiver,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Getter call on `this` of the property defined by [selector].
  ///
  /// For instance
  ///     class C {
  ///       m() => this.foo;
  ///     }
  ///
  /// or
  ///
  ///     class C {
  ///       m() => foo;
  ///     }
  ///
  R visitThisPropertyGet(
      Send node,
      Selector selector,
      A arg);

  /// Setter call on `this` with argument [rhs] of the property defined by
  /// [selector].
  ///     class C {
  ///       m() { this.foo = rhs; }
  ///     }
  ///
  /// or
  ///
  ///     class C {
  ///       m() { foo = rhs; }
  ///     }
  ///
  R visitThisPropertySet(
      SendSet node,
      Selector selector,
      Node rhs,
      A arg);

  /// Invocation of the property defined by [selector] on `this` with
  /// [arguments].
  ///
  /// For instance
  ///     class C {
  ///       m() { this.foo(null, 42); }
  ///     }
  ///
  /// or
  ///
  ///     class C {
  ///       m() { foo(null, 42); }
  ///     }
  ///
  ///
  R visitThisPropertyInvoke(
      Send node,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Read of `this`.
  ///
  /// For instance
  ///     class C {
  ///       m() => this;
  ///     }
  ///
  R visitThisGet(
      Identifier node,
      A arg);

  /// Invocation of `this` with [arguments].
  ///
  /// For instance
  ///     class C {
  ///       m() => this(null, 42);
  ///     }
  ///
  R visitThisInvoke(
      Send node,
      NodeList arguments,
      Selector selector,
      A arg);


  /// Read of the super [field].
  ///
  /// For instance
  ///     class B {
  ///       var foo;
  ///     }
  ///     class C extends B {
  ///        m() => super.foo;
  ///     }
  ///
  R visitSuperFieldGet(
      Send node,
      FieldElement field,
      A arg);

  /// Assignment of [rhs] to the super [field].
  ///
  /// For instance
  ///     class B {
  ///       var foo;
  ///     }
  ///     class C extends B {
  ///        m() { super.foo = rhs; }
  ///     }
  ///
  R visitSuperFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      A arg);

  /// Assignment of [rhs] to the final static [field].
  ///
  /// For instance
  ///     class B {
  ///       final foo = null;
  ///     }
  ///     class C extends B {
  ///        m() { super.foo = rhs; }
  ///     }
  ///
  R errorFinalSuperFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      A arg);

  /// Invocation of the super [field] with [arguments].
  ///
  /// For instance
  ///     class B {
  ///       var foo;
  ///     }
  ///     class C extends B {
  ///        m() { super.foo(null, 42); }
  ///     }
  ///
  R visitSuperFieldInvoke(
      Send node,
      FieldElement field,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Closurization of the super [method].
  ///
  /// For instance
  ///     class B {
  ///       foo(a, b) {}
  ///     }
  ///     class C extends B {
  ///        m() => super.foo;
  ///     }
  ///
  R visitSuperMethodGet(
      Send node,
      MethodElement method,
      A arg);

  /// Invocation of the super [method] with [arguments].
  ///
  /// For instance
  ///     class B {
  ///       foo(a, b) {}
  ///     }
  ///     class C extends B {
  ///        m() { super.foo(null, 42); }
  ///     }
  ///
  R visitSuperMethodInvoke(
      Send node,
      MethodElement method,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Assignment of [rhs] to the super [method].
  ///
  /// For instance
  ///     class B {
  ///       foo(a, b) {}
  ///     }
  ///     class C extends B {
  ///        m() { super.foo = rhs; }
  ///     }
  ///
  R errorSuperMethodSet(
      Send node,
      MethodElement method,
      Node rhs,
      A arg);

  /// Getter call to the super [getter].
  ///
  /// For instance
  ///     class B {
  ///       get foo => null;
  ///     }
  ///     class C extends B {
  ///        m() => super.foo;
  ///     }
  ///
  R visitSuperGetterGet(
      Send node,
      FunctionElement getter,
      A arg);

  /// Getter call the super [setter].
  ///
  /// For instance
  ///     class B {
  ///       set foo(_) {}
  ///     }
  ///     class C extends B {
  ///        m() => super.foo;
  ///     }
  ///
  R errorSuperSetterGet(
      Send node,
      FunctionElement setter,
      A arg);

  /// Setter call to the super [setter].
  ///
  /// For instance
  ///     class B {
  ///       set foo(_) {}
  ///     }
  ///     class C extends B {
  ///        m() { super.foo = rhs; }
  ///     }
  ///
  R visitSuperSetterSet(
      SendSet node,
      FunctionElement setter,
      Node rhs,
      A arg);

  /// Assignment of [rhs] to the super [getter].
  ///
  /// For instance
  ///     class B {
  ///       get foo => null;
  ///     }
  ///     class C extends B {
  ///        m() { super.foo = rhs; }
  ///     }
  ///
  R errorSuperGetterSet(
      SendSet node,
      FunctionElement getter,
      Node rhs,
      A arg);

  /// Invocation of the super [getter] with [arguments].
  ///
  /// For instance
  ///     class B {
  ///       get foo => null;
  ///     }
  ///     class C extends B {
  ///        m() { super.foo(null, 42; }
  ///     }
  ///
  R visitSuperGetterInvoke(
      Send node,
      FunctionElement getter,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Invocation of the super [setter] with [arguments].
  ///
  /// For instance
  ///     class B {
  ///       set foo(_) {}
  ///     }
  ///     class C extends B {
  ///        m() { super.foo(null, 42; }
  ///     }
  ///
  R errorSuperSetterInvoke(
      Send node,
      FunctionElement setter,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Invocation of a [expression] with [arguments].
  ///
  /// For instance
  ///     m() => (a, b){}(null, 42);
  ///
  R visitExpressionInvoke(
      Send node,
      Node expression,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Read of the static [field].
  ///
  /// For instance
  ///     class C {
  ///       static var foo;
  ///     }
  ///     m() => C.foo;
  ///
  R visitStaticFieldGet(
      Send node,
      FieldElement field,
      A arg);

  /// Assignment of [rhs] to the static [field].
  ///
  /// For instance
  ///     class C {
  ///       static var foo;
  ///     }
  ///     m() { C.foo = rhs; }
  ///
  R visitStaticFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      A arg);

  /// Assignment of [rhs] to the final static [field].
  ///
  /// For instance
  ///     class C {
  ///       static final foo;
  ///     }
  ///     m() { C.foo = rhs; }
  ///
  R errorFinalStaticFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      A arg);

  /// Invocation of the static [field] with [arguments].
  ///
  /// For instance
  ///     class C {
  ///       static var foo;
  ///     }
  ///     m() { C.foo(null, 42); }
  ///
  R visitStaticFieldInvoke(
      Send node,
      FieldElement field,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Closurization of the static [function].
  ///
  /// For instance
  ///     class C {
  ///       static foo(a, b) {}
  ///     }
  ///     m() => C.foo;
  ///
  R visitStaticFunctionGet(
      Send node,
      MethodElement function,
      A arg);

  /// Invocation of the static [function] with [arguments].
  ///
  /// For instance
  ///     class C {
  ///       static foo(a, b) {}
  ///     }
  ///     m() { C.foo(null, 42); }
  ///
  R visitStaticFunctionInvoke(
      Send node,
      MethodElement function,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Assignment of [rhs] to the static [function].
  ///
  /// For instance
  ///     class C {
  ///       static foo(a, b) {}
  ///     }
  ///     m() { C.foo = rhs; }
  ///
  R errorStaticFunctionSet(
      Send node,
      MethodElement function,
      Node rhs,
      A arg);

  /// Getter call to the static [getter].
  ///
  /// For instance
  ///     class C {
  ///       static get foo => null;
  ///     }
  ///     m() => C.foo;
  ///
  R visitStaticGetterGet(
      Send node,
      FunctionElement getter,
      A arg);

  /// Getter call the static [setter].
  ///
  /// For instance
  ///     class C {
  ///       static set foo(_) {}
  ///     }
  ///     m() => C.foo;
  ///
  R errorStaticSetterGet(
      Send node,
      FunctionElement setter,
      A arg);

  /// Setter call to the static [setter].
  ///
  /// For instance
  ///     class C {
  ///       static set foo(_) {}
  ///     }
  ///     m() { C.foo = rhs; }
  ///
  R visitStaticSetterSet(
      SendSet node,
      FunctionElement setter,
      Node rhs,
      A arg);

  /// Assignment of [rhs] to the static [getter].
  ///
  /// For instance
  ///     class C {
  ///       static get foo => null;
  ///     }
  ///     m() { C.foo = rhs; }
  ///
  R errorStaticGetterSet(
      SendSet node,
      FunctionElement getter,
      Node rhs,
      A arg);

  /// Invocation of the static [getter] with [arguments].
  ///
  /// For instance
  ///     class C {
  ///       static get foo => null;
  ///     }
  ///     m() { C.foo(null, 42; }
  ///
  R visitStaticGetterInvoke(
      Send node,
      FunctionElement getter,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Invocation of the static [setter] with [arguments].
  ///
  /// For instance
  ///     class C {
  ///       static set foo(_) {}
  ///     }
  ///     m() { C.foo(null, 42; }
  ///
  R errorStaticSetterInvoke(
      Send node,
      FunctionElement setter,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Read of the top level [field].
  ///
  /// For instance
  ///     var foo;
  ///     m() => foo;
  ///
  R visitTopLevelFieldGet(
      Send node,
      FieldElement field,
      A arg);

  /// Assignment of [rhs] to the top level [field].
  ///
  /// For instance
  ///     var foo;
  ///     m() { foo = rhs; }
  ///
  R visitTopLevelFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      A arg);

  /// Assignment of [rhs] to the final top level [field].
  ///
  /// For instance
  ///     final foo = null;
  ///     m() { foo = rhs; }
  ///
  R errorFinalTopLevelFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      A arg);

  /// Invocation of the top level [field] with [arguments].
  ///
  /// For instance
  ///     var foo;
  ///     m() { foo(null, 42); }
  ///
  R visitTopLevelFieldInvoke(
      Send node,
      FieldElement field,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Closurization of the top level [function].
  ///
  /// For instance
  ///     foo(a, b) {};
  ///     m() => foo;
  ///
  R visitTopLevelFunctionGet(
      Send node,
      MethodElement function,
      A arg);

  /// Invocation of the top level [function] with [arguments].
  ///
  /// For instance
  ///     foo(a, b) {};
  ///     m() { foo(null, 42); }
  ///
  R visitTopLevelFunctionInvoke(
      Send node,
      MethodElement function,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Assignment of [rhs] to the top level [function].
  ///
  /// For instance
  ///     foo(a, b) {};
  ///     m() { foo = rhs; }
  ///
  R errorTopLevelFunctionSet(
      Send node,
      MethodElement function,
      Node rhs,
      A arg);

  /// Getter call to the top level [getter].
  ///
  /// For instance
  ///     get foo => null;
  ///     m() => foo;
  ///
  R visitTopLevelGetterGet(
      Send node,
      FunctionElement getter,
      A arg);

  /// Getter call the top level [setter].
  ///
  /// For instance
  ///     set foo(_) {}
  ///     m() => foo;
  ///
  R errorTopLevelSetterGet(
      Send node,
      FunctionElement setter,
      A arg);

  /// Setter call to the top level [setter].
  ///
  /// For instance
  ///     set foo(_) {}
  ///     m() { foo = rhs; }
  ///
  R visitTopLevelSetterSet(
      SendSet node,
      FunctionElement setter,
      Node rhs,
      A arg);

  /// Assignment of [rhs] to the top level [getter].
  ///
  /// For instance
  ///     get foo => null;
  ///     m() { foo = rhs; }
  ///
  R errorTopLevelGetterSet(
      SendSet node,
      FunctionElement getter,
      Node rhs,
      A arg);

  /// Invocation of the top level [getter] with [arguments].
  ///
  /// For instance
  ///     get foo => null;
  ///     m() { foo(null, 42); }
  ///
  R visitTopLevelGetterInvoke(
      Send node,
      FunctionElement getter,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Invocation of the top level [setter] with [arguments].
  ///
  /// For instance
  ///     set foo(_) {};
  ///     m() { foo(null, 42); }
  ///
  R errorTopLevelSetterInvoke(
      Send node,
      FunctionElement setter,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Read of the type literal for class [element].
  ///
  /// For instance
  ///     class C {}
  ///     m() => C;
  ///
  R visitClassTypeLiteralGet(
      Send node,
      ClassElement element,
      A arg);

  /// Invocation of the type literal for class [element] with [arguments].
  ///
  /// For instance
  ///     class C {}
  ///     m() => C(null, 42);
  ///
  R visitClassTypeLiteralInvoke(
      Send node,
      ClassElement element,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Assignment of [rhs] to the type literal for class [element].
  ///
  /// For instance
  ///     class C {}
  ///     m() { C = rhs; }
  ///
  R errorClassTypeLiteralSet(
      SendSet node,
      ClassElement element,
      Node rhs,
      A arg);

  /// Read of the type literal for typedef [element].
  ///
  /// For instance
  ///     typedef F();
  ///     m() => F;
  ///
  R visitTypedefTypeLiteralGet(
      Send node,
      TypedefElement element,
      A arg);

  /// Invocation of the type literal for typedef [element] with [arguments].
  ///
  /// For instance
  ///     typedef F();
  ///     m() => F(null, 42);
  ///
  R visitTypedefTypeLiteralInvoke(
      Send node,
      TypedefElement element,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Assignment of [rhs] to the type literal for typedef [element].
  ///
  /// For instance
  ///     typedef F();
  ///     m() { F = rhs; }
  ///
  R errorTypedefTypeLiteralSet(
      SendSet node,
      TypedefElement element,
      Node rhs,
      A arg);

  /// Read of the type literal for type variable [element].
  ///
  /// For instance
  ///     class C<T> {
  ///       m() => T;
  ///     }
  ///
  R visitTypeVariableTypeLiteralGet(
      Send node,
      TypeVariableElement element,
      A arg);

  /// Invocation of the type literal for type variable [element] with
  /// [arguments].
  ///
  /// For instance
  ///     class C<T> {
  ///       m() { T(null, 42); }
  ///     }
  ///
  R visitTypeVariableTypeLiteralInvoke(
      Send node,
      TypeVariableElement element,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Assignment of [rhs] to the type literal for type variable [element].
  ///
  /// For instance
  ///     class C<T> {
  ///       m() { T = rhs; }
  ///     }
  ///
  R errorTypeVariableTypeLiteralSet(
      SendSet node,
      TypeVariableElement element,
      Node rhs,
      A arg);

  /// Read of the type literal for `dynamic`.
  ///
  /// For instance
  ///     m() => dynamic;
  ///
  R visitDynamicTypeLiteralGet(
      Send node,
      A arg);

  /// Invocation of the type literal for `dynamic` with [arguments].
  ///
  /// For instance
  ///     m() { dynamic(null, 42); }
  ///
  R visitDynamicTypeLiteralInvoke(
      Send node,
      NodeList arguments,
      Selector selector,
      A arg);

  /// Assignment of [rhs] to the type literal for `dynamic`.
  ///
  /// For instance
  ///     m() { dynamic = rhs; }
  ///
  R errorDynamicTypeLiteralSet(
      SendSet node,
      Node rhs,
      A arg);

  /// Call to `assert` with [expression] as the condition.
  ///
  /// For instance:
  ///     m() { assert(expression); }
  ///
  R visitAssert(
      Send node,
      Node expression,
      A arg);

  /// Binary expression `left operator right` where [operator] is a user
  /// definable operator. Binary expressions using operator `==` are handled
  /// by [visitEquals].
  ///
  /// For instance:
  ///     add(a, b) => a + b;
  ///     sub(a, b) => a - b;
  ///     mul(a, b) => a * b;
  ///
  R visitBinary(
      Send node,
      Node left,
      BinaryOperator operator,
      Node right,
      A arg);

  /// Binary expression `super operator argument` where [operator] is a user
  /// definable operator implemented on a superclass by [function]. Binary
  /// expressions using operator `==` are handled by [visitSuperEquals].
  ///
  /// For instance:
  ///     class B {
  ///       operator +(_) => null;
  ///     }
  ///     class C extends B {
  ///       m(a) => super + a;
  ///     }
  ///
  R visitSuperBinary(
      Send node,
      FunctionElement function,
      BinaryOperator operator,
      Node argument,
      A arg);

  /// Binary expression `left == right`.
  ///
  /// For instance:
  ///     neq(a, b) => a != b;
  ///
  R visitNotEquals(
      Send node,
      Node left,
      Node right,
      A arg);

  /// Binary expression `super != argument` where `==` is implemented on a
  /// superclass by [function].
  ///
  /// For instance:
  ///     class B {
  ///       operator +(_) => null;
  ///     }
  ///     class C extends B {
  ///       m(a) => super + a;
  ///     }
  ///
  R visitSuperNotEquals(
      Send node,
      FunctionElement function,
      Node argument,
      A arg);

  /// Binary expression `left == right`.
  ///
  /// For instance:
  ///     eq(a, b) => a == b;
  ///
  R visitEquals(
      Send node,
      Node left,
      Node right,
      A arg);

  /// Binary expression `super == argument` where `==` is implemented on a
  /// superclass by [function].
  ///
  /// For instance:
  ///     class B {
  ///       operator ==(_) => null;
  ///     }
  ///     class C extends B {
  ///       m(a) => super == a;
  ///     }
  ///
  R visitSuperEquals(
      Send node,
      FunctionElement function,
      Node argument,
      A arg);

  /// Unary expression `operator expression` where [operator] is a user
  /// definable operator.
  ///
  /// For instance:
  ///     neg(a, b) => -a;
  ///     comp(a, b) => ~a;
  ///
  R visitUnary(
      Send node,
      UnaryOperator operator,
      Node expression,
      A arg);

  /// Unary expression `operator super` where [operator] is a user definable
  /// operator implemented on a superclass by [function].
  ///
  /// For instance:
  ///     class B {
  ///       operator -() => null;
  ///     }
  ///     class C extends B {
  ///       m(a) => -super;
  ///     }
  ///
  R visitSuperUnary(
      Send node,
      UnaryOperator operator,
      FunctionElement function,
      A arg);

  /// Unary expression `!expression`.
  ///
  /// For instance:
  ///     not(a) => !a;
  ///
  R visitNot(
      Send node,
      Node expression,
      A arg);

  /// Index set expression `receiver[index] = rhs`.
  ///
  /// For instance:
  ///     m(receiver, index, rhs) => receiver[index] = rhs;
  ///
  R visitIndexSet(
      Send node,
      Node receiver,
      Node index,
      Node rhs,
      A arg);

  /// Index set expression `super[index] = rhs` where `operator []=` is defined
  /// on a superclass by [function].
  ///
  /// For instance:
  ///     class B {
  ///       operator []=(a, b) {}
  ///     }
  ///     class C extends B {
  ///       m(a, b) => super[a] = b;
  ///     }
  ///
  R visitSuperIndexSet(
      Send node,
      FunctionElement function,
      Node index,
      Node rhs,
      A arg);

  /// Lazy and, &&, expression with operands [left] and [right].
  ///
  /// For instance
  ///     m() => left && right;
  ///
  R visitLazyAnd(
      Send node,
      Node left,
      Node right,
      A arg);

  /// Lazy or, ||, expression with operands [left] and [right].
  ///
  /// For instance
  ///     m() => left || right;
  ///
  R visitLazyOr(
      Send node,
      Node left,
      Node right,
      A arg);

  /// Is test of [expression] against [type].
  ///
  /// For instance
  ///     class C {}
  ///     m() => expression is C;
  ///
  R visitIs(
      Send node,
      Node expression,
      DartType type,
      A arg);

  /// Is not test of [expression] against [type].
  ///
  /// For instance
  ///     class C {}
  ///     m() => expression is! C;
  ///
  R visitIsNot(
      Send node,
      Node expression,
      DartType type,
      A arg);

  /// As cast of [expression] to [type].
  ///
  /// For instance
  ///     class C {}
  ///     m() => expression as C;
  ///
  R visitAs(
      Send node,
      Node expression,
      DartType type,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] of the property on
  /// [receiver] whose getter and setter are½ defined by [getterSelector] and
  /// [setterSelector], respectively.
  ///
  /// For instance:
  ///     m(receiver, rhs) => receiver.foo += rhs;
  ///
  R visitDynamicPropertyCompound(
      Send node,
      Node receiver,
      AssignmentOperator operator,
      Node rhs,
      Selector getterSelector,
      Selector setterSelector,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] of the property on
  /// `this` whose getter and setter are defined by [getterSelector] and
  /// [setterSelector], respectively.
  ///
  /// For instance:
  ///     class C {
  ///       m(rhs) => this.foo += rhs;
  ///     }
  /// or
  ///     class C {
  ///       m(rhs) => foo += rhs;
  ///     }
  ///
  R visitThisPropertyCompound(
      Send node,
      AssignmentOperator operator,
      Node rhs,
      Selector getterSelector,
      Selector setterSelector,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on a [parameter].
  ///
  /// For instance:
  ///     m(parameter, rhs) => parameter += rhs;
  ///
  R visitParameterCompound(
      Send node,
      ParameterElement parameter,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on a final
  /// [parameter].
  ///
  /// For instance:
  ///     m(final parameter, rhs) => parameter += rhs;
  ///
  R errorFinalParameterCompound(
      Send node,
      ParameterElement parameter,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on a local
  /// [variable].
  ///
  /// For instance:
  ///     m(rhs) {
  ///       var variable;
  ///       variable += rhs;
  ///     }
  ///
  R visitLocalVariableCompound(
      Send node,
      LocalVariableElement variable,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on a final local
  /// [variable].
  ///
  /// For instance:
  ///     m(rhs) {
  ///       final variable = 0;
  ///       variable += rhs;
  ///     }
  ///
  R errorFinalLocalVariableCompound(
      Send node,
      LocalVariableElement variable,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on a local
  /// [function].
  ///
  /// For instance:
  ///     m(rhs) {
  ///       function() {}
  ///       function += rhs;
  ///     }
  ///
  R errorLocalFunctionCompound(
      Send node,
      LocalFunctionElement function,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on a static
  /// [field].
  ///
  /// For instance:
  ///     class C {
  ///       static var field;
  ///       m(rhs) => field += rhs;
  ///     }
  ///
  R visitStaticFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on a final static
  /// [field].
  ///
  /// For instance:
  ///     class C {
  ///       static final field = 0;
  ///       m(rhs) => field += rhs;
  ///     }
  ///
  R errorFinalStaticFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] reading from a
  /// static [getter] and writing to a static [setter].
  ///
  /// For instance:
  ///     class C {
  ///       static get o => 0;
  ///       static set o(_) {}
  ///       m(rhs) => o += rhs;
  ///     }
  ///
  R visitStaticGetterSetterCompound(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] reading from a
  /// static [method], that is, closurizing [method], and writing to a static
  /// [setter].
  ///
  /// For instance:
  ///     class C {
  ///       static o() {}
  ///       static set o(_) {}
  ///       m(rhs) => o += rhs;
  ///     }
  ///
  R visitStaticMethodSetterCompound(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on a top level
  /// [field].
  ///
  /// For instance:
  ///     var field;
  ///     m(rhs) => field += rhs;
  ///
  R visitTopLevelFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on a final top
  /// level [field].
  ///
  /// For instance:
  ///     final field = 0;
  ///     m(rhs) => field += rhs;
  ///
  R errorFinalTopLevelFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] reading from a
  /// top level [getter] and writing to a top level [setter].
  ///
  /// For instance:
  ///     get o => 0;
  ///     set o(_) {}
  ///     m(rhs) => o += rhs;
  ///
  R visitTopLevelGetterSetterCompound(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] reading from a
  /// top level [method], that is, closurizing [method], and writing to a top
  /// level [setter].
  ///
  /// For instance:
  ///     o() {}
  ///     set o(_) {}
  ///     m(rhs) => o += rhs;
  ///
  R visitTopLevelMethodSetterCompound(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on a super
  /// [field].
  ///
  /// For instance:
  ///     class B {
  ///       var field;
  ///     }
  ///     class C extends B {
  ///       m(rhs) => super.field += rhs;
  ///     }
  ///
  R visitSuperFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on a final super
  /// [field].
  ///
  /// For instance:
  ///     class B {
  ///       final field = 0;
  ///     }
  ///     class C extends B {
  ///       m(rhs) => super.field += rhs;
  ///     }
  ///
  R errorFinalSuperFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] reading from a
  /// super [getter] and writing to a super [setter].
  ///
  /// For instance:
  ///     class B {
  ///       get o => 0;
  ///       set o(_) {}
  ///     }
  ///     class C extends B {
  ///       m(rhs) => super.o += rhs;
  ///     }
  ///
  R visitSuperGetterSetterCompound(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] reading from a
  /// super [method], that is, closurizing [method], and writing to a super
  /// [setter].
  ///
  /// For instance:
  ///     class B {
  ///       o() {}
  ///       set o(_) {}
  ///     }
  ///     class C extends B {
  ///       m(rhs) => super.o += rhs;
  ///     }
  ///
  R visitSuperMethodSetterCompound(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] reading from a
  /// super [field] and writing to a super [setter].
  ///
  /// For instance:
  ///     class A {
  ///       var o;
  ///     }
  ///     class B extends A {
  ///       set o(_) {}
  ///     }
  ///     class C extends B {
  ///       m(rhs) => super.o += rhs;
  ///     }
  ///
  R visitSuperFieldSetterCompound(
      Send node,
      FieldElement field,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] reading from a
  /// super [getter] and writing to a super [field].
  ///
  /// For instance:
  ///     class A {
  ///       var o;
  ///     }
  ///     class B extends A {
  ///       get o => 0;
  ///     }
  ///     class C extends B {
  ///       m(rhs) => super.o += rhs;
  ///     }
  ///
  R visitSuperGetterFieldCompound(
      Send node,
      FunctionElement getter,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on a type literal
  /// for class [element].
  ///
  /// For instance:
  ///     class C {}
  ///     m(rhs) => C += rhs;
  ///
  R visitClassTypeLiteralCompound(
      Send node,
      ClassElement element,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on a type literal
  /// for typedef [element].
  ///
  /// For instance:
  ///     typedef F();
  ///     m(rhs) => F += rhs;
  ///
  R visitTypedefTypeLiteralCompound(
      Send node,
      TypedefElement element,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on a type literal
  /// for type variable [element].
  ///
  /// For instance:
  ///     class C<T> {
  ///       m(rhs) => T += rhs;
  ///     }
  ///
  R visitTypeVariableTypeLiteralCompound(
      Send node,
      TypeVariableElement element,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on the type
  /// literal for `dynamic`.
  ///
  /// For instance:
  ///     m(rhs) => dynamic += rhs;
  ///
  R visitDynamicTypeLiteralCompound(
      Send node,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on the index
  /// operators of [receiver] whose getter and setter are defined by
  /// [getterSelector] and [setterSelector], respectively.
  ///
  /// For instance:
  ///     m(receiver, index, rhs) => receiver[index] += rhs;
  ///
  R visitCompoundIndexSet(
      Send node,
      Node receiver,
      Node index,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Compound assignment expression of [rhs] with [operator] on the index
  /// operators of a super class defined by [getter] and [setter].
  ///
  /// For instance:
  ///     class B {
  ///       operator [](index) {}
  ///       operator [](index, value) {}
  ///     }
  ///     class C extends B {
  ///       m(index, rhs) => super[index] += rhs;
  ///     }
  ///
  R visitSuperCompoundIndexSet(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      Node index,
      AssignmentOperator operator,
      Node rhs,
      A arg);

  /// Prefix expression with [operator] of the property on [receiver] whose
  /// getter and setter are defined by [getterSelector] and [setterSelector],
  /// respectively.
  ///
  /// For instance:
  ///     m(receiver) => ++receiver.foo;
  ///
  R visitDynamicPropertyPrefix(
      Send node,
      Node receiver,
      IncDecOperator operator,
      Selector getterSelector,
      Selector setterSelector,
      A arg);

  /// Prefix expression with [operator] on a [parameter].
  ///
  /// For instance:
  ///     m(parameter) => ++parameter;
  ///
  R visitParameterPrefix(
      Send node,
      ParameterElement parameter,
      IncDecOperator operator,
      A arg);

  /// Prefix expression with [operator] on a local [variable].
  ///
  /// For instance:
  ///     m() {
  ///     var variable;
  ///      ++variable;
  ///     }
  ///
  R visitLocalVariablePrefix(
      Send node,
      LocalVariableElement variable,
      IncDecOperator operator,
      A arg);

  /// Prefix expression with [operator] on a local [function].
  ///
  /// For instance:
  ///     m() {
  ///     function() {}
  ///      ++function;
  ///     }
  ///
  R errorLocalFunctionPrefix(
      Send node,
      LocalFunctionElement function,
      IncDecOperator operator,
      A arg);


  /// Prefix expression with [operator] of the property on `this` whose getter
  /// and setter are defined by [getterSelector] and [setterSelector],
  /// respectively.
  ///
  /// For instance:
  ///     class C {
  ///       m() => ++foo;
  ///     }
  /// or
  ///     class C {
  ///       m() => ++this.foo;
  ///     }
  ///
  R visitThisPropertyPrefix(
      Send node,
      IncDecOperator operator,
      Selector getterSelector,
      Selector setterSelector,
      A arg);

  /// Prefix expression with [operator] on a static [field].
  ///
  /// For instance:
  ///     class C {
  ///       static var field;
  ///       m() => ++field;
  ///     }
  ///
  R visitStaticFieldPrefix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      A arg);

  /// Prefix expression with [operator] reading from a static [getter] and
  /// writing to a static [setter].
  ///
  /// For instance:
  ///     class C {
  ///       static get o => 0;
  ///       static set o(_) {}
  ///       m() => ++o;
  ///     }
  ///
  R visitStaticGetterSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      A arg);


  /// Prefix expression with [operator] reading from a static [method], that is,
  /// closurizing [method], and writing to a static [setter].
  ///
  /// For instance:
  ///     class C {
  ///       static o() {}
  ///       static set o(_) {}
  ///       m() => ++o;
  ///     }
  ///
  R visitStaticMethodSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      A arg);

  /// Prefix expression with [operator] on a top level [field].
  ///
  /// For instance:
  ///     var field;
  ///     m() => ++field;
  ///
  R visitTopLevelFieldPrefix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      A arg);

  /// Prefix expression with [operator] reading from a top level [getter] and
  /// writing to a top level [setter].
  ///
  /// For instance:
  ///     get o => 0;
  ///     set o(_) {}
  ///     m() => ++o;
  ///
  R visitTopLevelGetterSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      A arg);

  /// Prefix expression with [operator] reading from a top level [method], that
  /// is, closurizing [method], and writing to a top level [setter].
  ///
  /// For instance:
  ///     o() {}
  ///     set o(_) {}
  ///     m() => ++o;
  ///
  R visitTopLevelMethodSetterPrefix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      A arg);

  /// Prefix expression with [operator] on a super [field].
  ///
  /// For instance:
  ///     class B {
  ///       var field;
  ///     }
  ///     class C extends B {
  ///       m() => ++super.field;
  ///     }
  ///
  R visitSuperFieldPrefix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      A arg);

  /// Prefix expression with [operator] reading from the super field [readField]
  /// and writint to the different super field [writtenField].
  ///
  /// For instance:
  ///     class A {
  ///       var field;
  ///     }
  ///     class B extends A {
  ///       final field;
  ///     }
  ///     class C extends B {
  ///       m() => ++super.field;
  ///     }
  ///
  R visitSuperFieldFieldPrefix(
      Send node,
      FieldElement readField,
      FieldElement writtenField,
      IncDecOperator operator,
      A arg);

  /// Prefix expression with [operator] reading from a super [field] and writing
  /// to a super [setter].
  ///
  /// For instance:
  ///     class A {
  ///       var field;
  ///     }
  ///     class B extends A {
  ///       set field(_) {}
  ///     }
  ///     class C extends B {
  ///       m() => ++super.field;
  ///     }
  ///
  R visitSuperFieldSetterPrefix(
      Send node,
      FieldElement field,
      FunctionElement setter,
      IncDecOperator operator,
      A arg);


  /// Prefix expression with [operator] reading from a super [getter] and
  /// writing to a super [setter].
  ///
  /// For instance:
  ///     class B {
  ///       get field => 0;
  ///       set field(_) {}
  ///     }
  ///     class C extends B {
  ///       m() => ++super.field;
  ///     }
  ///
  R visitSuperGetterSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      A arg);

  /// Prefix expression with [operator] reading from a super [getter] and
  /// writing to a super [field].
  ///
  /// For instance:
  ///     class A {
  ///       var field;
  ///     }
  ///     class B extends A {
  ///       get field => 0;
  ///     }
  ///     class C extends B {
  ///       m() => ++super.field;
  ///     }
  ///
  R visitSuperGetterFieldPrefix(
      Send node,
      FunctionElement getter,
      FieldElement field,
      IncDecOperator operator,
      A arg);

  /// Prefix expression with [operator] reading from a super [method], that is,
  /// closurizing [method], and writing to a super [setter].
  ///
  /// For instance:
  ///     class B {
  ///       o() {}
  ///       set o(_) {}
  ///     }
  ///     class C extends B {
  ///       m() => ++super.o;
  ///     }
  ///
  R visitSuperMethodSetterPrefix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      A arg);

  /// Prefix expression with [operator] on a type literal for a class [element].
  ///
  /// For instance:
  ///     class C {}
  ///     m() => ++C;
  ///
  R visitClassTypeLiteralPrefix(
      Send node,
      ClassElement element,
      IncDecOperator operator,
      A arg);

  /// Prefix expression with [operator] on a type literal for a typedef
  /// [element].
  ///
  /// For instance:
  ///     typedef F();
  ///     m() => ++F;
  ///
  R visitTypedefTypeLiteralPrefix(
      Send node,
      TypedefElement element,
      IncDecOperator operator,
      A arg);

  /// Prefix expression with [operator] on a type literal for a type variable
  /// [element].
  ///
  /// For instance:
  ///     class C<T> {
  ///       m() => ++T;
  ///     }
  ///
  R visitTypeVariableTypeLiteralPrefix(
      Send node,
      TypeVariableElement element,
      IncDecOperator operator,
      A arg);

  /// Prefix expression with [operator] on the type literal for `dynamic`.
  ///
  /// For instance:
  ///     m() => ++dynamic;
  ///
  R visitDynamicTypeLiteralPrefix(
      Send node,
      IncDecOperator operator,
      A arg);

  /// Postfix expression with [operator] of the property on [receiver] whose
  /// getter and setter are defined by [getterSelector] and [setterSelector],
  /// respectively.
  ///
  /// For instance:
  ///     m(receiver) => receiver.foo++;
  ///
  R visitDynamicPropertyPostfix(
      Send node,
      Node receiver,
      IncDecOperator operator,
      Selector getterSelector,
      Selector setterSelector,
      A arg);

  /// Postfix expression with [operator] on a [parameter].
  ///
  /// For instance:
  ///     m(parameter) => parameter++;
  ///
  R visitParameterPostfix(
      Send node,
      ParameterElement parameter,
      IncDecOperator operator,
      A arg);

  /// Postfix expression with [operator] on a local [variable].
  ///
  /// For instance:
  ///     m() {
  ///     var variable;
  ///      variable++;
  ///     }
  ///
  R visitLocalVariablePostfix(
      Send node,
      LocalVariableElement variable,
      IncDecOperator operator,
      A arg);

  /// Postfix expression with [operator] on a local [function].
  ///
  /// For instance:
  ///     m() {
  ///     function() {}
  ///      function++;
  ///     }
  ///
  R errorLocalFunctionPostfix(
      Send node,
      LocalFunctionElement function,
      IncDecOperator operator,
      A arg);


  /// Postfix expression with [operator] of the property on `this` whose getter
  /// and setter are defined by [getterSelector] and [setterSelector],
  /// respectively.
  ///
  /// For instance:
  ///     class C {
  ///       m() => foo++;
  ///     }
  /// or
  ///     class C {
  ///       m() => this.foo++;
  ///     }
  ///
  R visitThisPropertyPostfix(
      Send node,
      IncDecOperator operator,
      Selector getterSelector,
      Selector setterSelector,
      A arg);

  /// Postfix expression with [operator] on a static [field].
  ///
  /// For instance:
  ///     class C {
  ///       static var field;
  ///       m() => field++;
  ///     }
  ///
  R visitStaticFieldPostfix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      A arg);

  /// Postfix expression with [operator] reading from a static [getter] and
  /// writing to a static [setter].
  ///
  /// For instance:
  ///     class C {
  ///       static get o => 0;
  ///       static set o(_) {}
  ///       m() => o++;
  ///     }
  ///
  R visitStaticGetterSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      A arg);


  /// Postfix expression with [operator] reading from a static [method], that is,
  /// closurizing [method], and writing to a static [setter].
  ///
  /// For instance:
  ///     class C {
  ///       static o() {}
  ///       static set o(_) {}
  ///       m() => o++;
  ///     }
  ///
  R visitStaticMethodSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      A arg);

  /// Postfix expression with [operator] on a top level [field].
  ///
  /// For instance:
  ///     var field;
  ///     m() => field++;
  ///
  R visitTopLevelFieldPostfix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      A arg);

  /// Postfix expression with [operator] reading from a top level [getter] and
  /// writing to a top level [setter].
  ///
  /// For instance:
  ///     get o => 0;
  ///     set o(_) {}
  ///     m() => o++;
  ///
  R visitTopLevelGetterSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      A arg);

  /// Postfix expression with [operator] reading from a top level [method], that
  /// is, closurizing [method], and writing to a top level [setter].
  ///
  /// For instance:
  ///     o() {}
  ///     set o(_) {}
  ///     m() => o++;
  ///
  R visitTopLevelMethodSetterPostfix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      A arg);

  /// Postfix expression with [operator] on a super [field].
  ///
  /// For instance:
  ///     class B {
  ///       var field;
  ///     }
  ///     class C extends B {
  ///       m() => super.field++;
  ///     }
  ///
  R visitSuperFieldPostfix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      A arg);

  /// Postfix expression with [operator] reading from the super field [readField]
  /// and writint to the different super field [writtenField].
  ///
  /// For instance:
  ///     class A {
  ///       var field;
  ///     }
  ///     class B extends A {
  ///       final field;
  ///     }
  ///     class C extends B {
  ///       m() => super.field++;
  ///     }
  ///
  R visitSuperFieldFieldPostfix(
      Send node,
      FieldElement readField,
      FieldElement writtenField,
      IncDecOperator operator,
      A arg);

  /// Postfix expression with [operator] reading from a super [field] and writing
  /// to a super [setter].
  ///
  /// For instance:
  ///     class A {
  ///       var field;
  ///     }
  ///     class B extends A {
  ///       set field(_) {}
  ///     }
  ///     class C extends B {
  ///       m() => super.field++;
  ///     }
  ///
  R visitSuperFieldSetterPostfix(
      Send node,
      FieldElement field,
      FunctionElement setter,
      IncDecOperator operator,
      A arg);


  /// Postfix expression with [operator] reading from a super [getter] and
  /// writing to a super [setter].
  ///
  /// For instance:
  ///     class B {
  ///       get field => 0;
  ///       set field(_) {}
  ///     }
  ///     class C extends B {
  ///       m() => super.field++;
  ///     }
  ///
  R visitSuperGetterSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      A arg);

  /// Postfix expression with [operator] reading from a super [getter] and
  /// writing to a super [field].
  ///
  /// For instance:
  ///     class A {
  ///       var field;
  ///     }
  ///     class B extends A {
  ///       get field => 0;
  ///     }
  ///     class C extends B {
  ///       m() => super.field++;
  ///     }
  ///
  R visitSuperGetterFieldPostfix(
      Send node,
      FunctionElement getter,
      FieldElement field,
      IncDecOperator operator,
      A arg);

  /// Postfix expression with [operator] reading from a super [method], that is,
  /// closurizing [method], and writing to a super [setter].
  ///
  /// For instance:
  ///     class B {
  ///       o() {}
  ///       set o(_) {}
  ///     }
  ///     class C extends B {
  ///       m() => super.o++;
  ///     }
  ///
  R visitSuperMethodSetterPostfix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      A arg);

  /// Postfix expression with [operator] on a type literal for a class [element].
  ///
  /// For instance:
  ///     class C {}
  ///     m() => C++;
  ///
  R visitClassTypeLiteralPostfix(
      Send node,
      ClassElement element,
      IncDecOperator operator,
      A arg);

  /// Postfix expression with [operator] on a type literal for a typedef
  /// [element].
  ///
  /// For instance:
  ///     typedef F();
  ///     m() => F++;
  ///
  R visitTypedefTypeLiteralPostfix(
      Send node,
      TypedefElement element,
      IncDecOperator operator,
      A arg);

  /// Postfix expression with [operator] on a type literal for a type variable
  /// [element].
  ///
  /// For instance:
  ///     class C<T> {
  ///       m() => T++;
  ///     }
  ///
  R visitTypeVariableTypeLiteralPostfix(
      Send node,
      TypeVariableElement element,
      IncDecOperator operator,
      A arg);

  /// Postfix expression with [operator] on the type literal for `dynamic`.
  ///
  /// For instance:
  ///     m() => dynamic++;
  ///
  R visitDynamicTypeLiteralPostfix(
      Send node,
      IncDecOperator operator,
      A arg);
}
