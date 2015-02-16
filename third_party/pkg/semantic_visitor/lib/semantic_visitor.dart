// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart2js.semantics_visitor;

import 'package:sharedfrontend/src/access_semantics.dart';

import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/resolution/resolution.dart';
import 'package:compiler/src/tree/tree.dart';
import 'package:compiler/src/universe/universe.dart';
import 'package:compiler/src/util/util.dart' show Spannable;
import 'package:compiler/src/dart_types.dart';

abstract class AccessSemanticMixin {
  TreeElements get elements;

  internalError(Spannable spannable, String message);

  AccessSemantics handleStaticallyResolvedAccess(Send node, Element element) {
    String name = node.selector.asIdentifier().source;
    bool isWrite = node.asSendSet() != null;
    bool isRead = !isWrite;
    bool isInvoke = isRead && !node.isPropertyAccess;

    if (element.isParameter) {
      return new AccessSemantics.parameter(
          name,
          element,
          isRead: isRead,
          isWrite: isWrite,
          isInvoke: isInvoke);
    } else if (element.isLocal) {
      if (element.isFunction) {
        return new AccessSemantics.localFunction(
            name,
            element,
            isRead: isRead,
            isWrite: isWrite,
            isInvoke: isInvoke);
      } else {
        return new AccessSemantics.localVariable(
            name,
            element,
            isRead: isRead,
            isWrite: isWrite,
            isInvoke: isInvoke);
      }
    } else if (element.isStatic) {
      if (element.isField) {
        return new AccessSemantics.staticField(
            name,
            element,
            element.enclosingClass,
            isRead: isRead,
            isWrite: isWrite,
            isInvoke: isInvoke);
      } else if (element.isGetter || element.isSetter) {
        return new AccessSemantics.staticProperty(
            name,
            element,
            element.enclosingClass,
            isRead: isRead,
            isWrite: isWrite,
            isInvoke: isInvoke);
      } else {
        return new AccessSemantics.staticMethod(
            name,
            element,
            element.enclosingClass,
            isRead: isRead,
            isWrite: isWrite,
            isInvoke: isInvoke);
      }
    } else if (element.isTopLevel) {
      if (element.isField) {
        return new AccessSemantics.topLevelField(
            name,
            element,
            isRead: isRead,
            isWrite: isWrite,
            isInvoke: isInvoke);
      } else if (element.isGetter || element.isSetter) {
        return new AccessSemantics.topLevelProperty(
            name,
            element,
            isRead: isRead,
            isWrite: isWrite,
            isInvoke: isInvoke);
      } else {
        return new AccessSemantics.topLevelMethod(
            name,
            element,
            isRead: isRead,
            isWrite: isWrite,
            isInvoke: isInvoke);
      }
    } else {
      return internalError(
          node, "Unhandled resolved property access: $element");
    }
  }

  AccessSemantics handleSend(Send node) {
    // TODO(johnniwinther): Refactor this method to match [AccessSemantics]
    // more than [ResolvedVisitor] structure.
    bool isWrite = node.asSendSet() != null;
    bool isRead = !isWrite;
    bool isInvoke = isRead && !node.isPropertyAccess;

    Element element = elements[node];
    if (elements.isAssert(node)) {
      return null;
    } else if (elements.isTypeLiteral(node)) {
      String name = node.selector.asIdentifier().source;
      DartType dartType = elements.getTypeLiteralType(node);
      switch (dartType.kind) {
      case TypeKind.INTERFACE:
        return new AccessSemantics.classTypeLiteral(
            name,
            dartType.element,
            isRead: isRead,
            isWrite: isWrite,
            isInvoke: isInvoke);
      case TypeKind.TYPEDEF:
        return new AccessSemantics.typedefTypeLiteral(
            name,
            dartType.element,
            isRead: isRead,
            isWrite: isWrite,
            isInvoke: isInvoke);
      case TypeKind.TYPE_VARIABLE:
        return new AccessSemantics.typeParameterTypeLiteral(
            name,
            dartType.element,
            isRead: isRead,
            isWrite: isWrite,
            isInvoke: isInvoke);
      case TypeKind.DYNAMIC:
        return new AccessSemantics.dynamicTypeLiteral(
            name,
            isRead: isRead,
            isWrite: isWrite,
            isInvoke: isInvoke);
      default:
        return internalError(node, "Unexpected type literal type: $dartType");
      }
    } else if (node.isSuperCall) {
      // TODO(johnniwinther): Handle super calls.
      return internalError(node, "Supper calls unsupported.");
    } else if (node.isOperator) {
      // TODO(johnniwinther): Handle operators.
      return internalError(node, "Operators unsupported.");
    } else if (!isInvoke) {
      String name = node.selector.asIdentifier().source;
      if (!Elements.isUnresolved(element) && element.impliesType) {
        // Prefix of a static access.
        return null;
      } else if (element == null) {
        return new AccessSemantics.dynamic(
            name,
            node.receiver,
            isRead: isRead,
            isWrite: isWrite,
            isInvoke: isInvoke);
      } else {
        return handleStaticallyResolvedAccess(node, element);
      }
    } else if (element != null && Initializers.isConstructorRedirect(node)) {
      return handleStaticallyResolvedAccess(node, element);
    } else if (Elements.isClosureSend(node, element)) {
      // TODO(johnniwinther): Handle this.
      return internalError(node, "Closure send unsupported.");
    } else {
      String name = node.selector.asIdentifier().source;
      if (Elements.isUnresolved(element)) {
        if (element == null) {
          // Example: f() with 'f' unbound.
          // This can only happen inside an instance method.
          return new AccessSemantics.dynamic(
              name,
              node.receiver,
              isRead: isRead,
              isWrite: isWrite,
              isInvoke: isInvoke);
        } else {
          // TODO(johnniwinther): Handle this.
          return internalError(node,
                               "Statically unresolved access unsupported.");
        }
      } else if (element.isInstanceMember) {
        // Example: f() with 'f' bound to instance method.
        return new AccessSemantics.dynamic(
            name,
            node.receiver,
            isRead: isRead,
            isWrite: isWrite,
            isInvoke: isInvoke);
      } else if (!element.isInstanceMember) {
        // Example: A.f() or f() with 'f' bound to a static function.
        // Also includes new A() or new A.named() which is treated like a
        // static call to a factory.
        return handleStaticallyResolvedAccess(node, element);
      } else {
        internalError(node, "Cannot generate code for send");
        return null;
      }
    }
  }
}

abstract class SemanticVisitor<R> extends Visitor<R> with AccessSemanticMixin {
  TreeElements elements;

  SemanticVisitor(this.elements);

  @override
  R visitSend(Send node) {
    Element element = elements[node];
    AccessSemantics semantics = handleSend(node);
    if (semantics == null) {
      if (elements.isAssert(node)) {
        Node argument;
        if (!node.arguments.isEmpty) {
          argument = node.arguments.first;
        }
        return visitAssert(node, argument);
      }
    } else {
      switch (semantics.kind) {
      case AccessKind.DYNAMIC:
        if (semantics.isInvoke) {
          return visitDynamicInvocation(
              node,
              node.argumentsNode,
              elements.getSelector(node));
        } else if (semantics.isWrite) {
          return visitDynamicAssignment(
              node, elements.getSelector(node), node.arguments.single);
        } else {
          return visitDynamicAccess(node, elements.getSelector(node));
        }
        break;
      case AccessKind.PARAMETER:
        if (semantics.isInvoke) {
          return visitParameterInvocation(
              node,
              semantics.element,
              node.argumentsNode,
              elements.getSelector(node));
        } else if (semantics.isWrite) {
          return visitParameterAssignment(
              node, semantics.element, node.arguments.single);
        } else {
          return visitParameterAccess(node, semantics.element);
        }
        break;
      case AccessKind.LOCAL_VARIABLE:
        if (semantics.isInvoke) {
          return visitParameterInvocation(
              node,
              semantics.element,
              node.argumentsNode,
              elements.getSelector(node));
        } else if (semantics.isWrite) {
          return visitParameterAssignment(
              node, semantics.element, node.arguments.single);
        } else {
          return visitParameterAccess(node, semantics.element);
        }
        break;
      case AccessKind.LOCAL_FUNCTION:
        if (semantics.isInvoke) {
          return visitLocalFunctionInvocation(
              node,
              semantics.element,
              node.argumentsNode,
              elements.getSelector(node));
        } else {
          return visitLocalFunctionAccess(node, semantics.element);
        }
        break;
      case AccessKind.STATIC_FIELD:
        if (semantics.isInvoke) {
          return visitStaticFieldInvocation(
              node,
              semantics.element,
              node.argumentsNode,
              elements.getSelector(node));
        } else if (semantics.isWrite) {
          return visitStaticFieldAssignment(
              node, semantics.element, node.arguments.single);
        } else {
          return visitStaticFieldAccess(node, semantics.element);
        }
        break;
      case AccessKind.STATIC_METHOD:
        if (semantics.isInvoke) {
          return visitStaticMethodInvocation(
              node,
              semantics.element,
              node.argumentsNode,
              elements.getSelector(node));
        } else {
          return visitStaticMethodAccess(node, semantics.element);
        }
        break;
      case AccessKind.STATIC_PROPERTY:
        if (semantics.isInvoke) {
          return visitStaticPropertyInvocation(
              node,
              semantics.element,
              node.argumentsNode,
              elements.getSelector(node));
        } else if (semantics.isWrite) {
          return visitStaticPropertyAssignment(
              node, semantics.element, node.arguments.single);
        } else {
          return visitStaticPropertyAccess(node, semantics.element);
        }
        break;
      case AccessKind.TOPLEVEL_FIELD:
        if (semantics.isInvoke) {
          return visitTopLevelFieldInvocation(
              node,
              semantics.element,
              node.argumentsNode,
              elements.getSelector(node));
        } else if (semantics.isWrite) {
          return visitTopLevelFieldAssignment(
              node, semantics.element, node.arguments.single);
        } else {
          return visitTopLevelFieldAccess(node, semantics.element);
        }
        break;
      case AccessKind.TOPLEVEL_METHOD:
        if (semantics.isInvoke) {
          return visitTopLevelMethodInvocation(
              node,
              semantics.element,
              node.argumentsNode,
              elements.getSelector(node));
        } else {
          return visitTopLevelMethodAccess(node, semantics.element);
        }
        break;
      case AccessKind.TOPLEVEL_PROPERTY:
        if (semantics.isInvoke) {
          return visitTopLevelPropertyInvocation(
              node,
              semantics.element,
              node.argumentsNode,
              elements.getSelector(node));
        } else if (semantics.isWrite) {
          return visitTopLevelPropertyAssignment(
              node, semantics.element, node.arguments.single);
        } else {
          return visitTopLevelPropertyAccess(node, semantics.element);
        }
        break;
      case AccessKind.CLASS_TYPE_LITERAL:
        if (semantics.isInvoke) {
          return visitClassTypeLiteralInvocation(
              node,
              semantics.element,
              node.argumentsNode,
              elements.getSelector(node));
        } else if (semantics.isWrite) {
          return visitClassTypeLiteralAssignment(
              node, semantics.element, node.arguments.single);
        } else {
          return visitClassTypeLiteralAccess(node, semantics.element);
        }
        break;
      case AccessKind.TYPEDEF_TYPE_LITERAL:
        if (semantics.isInvoke) {
          return visitTypedefTypeLiteralInvocation(
              node, semantics.element, node.argumentsNode,
              elements.getSelector(node));
        } else if (semantics.isWrite) {
          return visitTypedefTypeLiteralAssignment(
              node, semantics.element, node.arguments.single);
        } else {
          return visitTypedefTypeLiteralAccess(node, semantics.element);
        }
        break;
      case AccessKind.DYNAMIC_TYPE_LITERAL:
        if (semantics.isRead) {
          return visitDynamicTypeLiteralAccess(node);
        }
        break;
      case AccessKind.TYPE_PARAMETER_TYPE_LITERAL:
        if (semantics.isInvoke) {
          return visitTypeVariableTypeLiteralInvocation(
              node,
              semantics.element,
              node.argumentsNode,
              elements.getSelector(node));
        } else if (semantics.isWrite) {
          return visitTypeVariableTypeLiteralAssignment(
              node, semantics.element, node.arguments.single);
        } else {
          return visitTypeVariableTypeLiteralAccess(node, semantics.element);
        }
        break;
      }
    }
    return internalError(node, "Unhandled node.");
  }

  @override
  R visitSendSet(SendSet node) {
    return visitSend(node);
  }

  R visitParameterAccess(Send node, ParameterElement element);
  R visitParameterAssignment(SendSet node, ParameterElement element, Node rhs);
  R visitParameterInvocation(Send node,
                             ParameterElement element,
                             NodeList arguments,
                             Selector selector);

  R visitLocalVariableAccess(Send node, LocalVariableElement element);
  R visitLocalVariableAssignment(SendSet node,
                                 LocalVariableElement element,
                                 Node rhs);
  R visitLocalVariableInvocation(Send node,
                                 LocalVariableElement element,
                                 NodeList arguments,
                                 Selector selector);

  R visitLocalFunctionAccess(Send node, LocalFunctionElement element);
  R visitLocalFunctionAssignment(SendSet node,
                                 LocalFunctionElement element,
                                 Node rhs,
                                 Selector selector);
  R visitLocalFunctionInvocation(Send node,
                                 LocalFunctionElement element,
                                 NodeList arguments,
                                 Selector selector);

  R visitDynamicAccess(Send node, Selector selector);
  R visitDynamicAssignment(SendSet node, Selector selector, Node rhs);
  R visitDynamicInvocation(Send node,
                           NodeList arguments,
                           Selector selector);

  R visitStaticFieldAccess(Send node, FieldElement element);
  R visitStaticFieldAssignment(SendSet node, FieldElement element, Node rhs);
  R visitStaticFieldInvocation(Send node,
                               FieldElement element,
                               NodeList arguments,
                               Selector selector);

  R visitStaticMethodAccess(Send node, MethodElement element);
  R visitStaticMethodInvocation(Send node,
                                MethodElement element,
                                NodeList arguments,
                                Selector selector);

  R visitStaticPropertyAccess(Send node, FunctionElement element);
  R visitStaticPropertyAssignment(SendSet node,
                                  FunctionElement element,
                                  Node rhs);
  R visitStaticPropertyInvocation(Send node,
                                  FieldElement element,
                                  NodeList arguments,
                                  Selector selector);

  R visitTopLevelFieldAccess(Send node, FieldElement element);
  R visitTopLevelFieldAssignment(SendSet node, FieldElement element, Node rhs);
  R visitTopLevelFieldInvocation(Send node,
                               FieldElement element,
                               NodeList arguments,
                               Selector selector);

  R visitTopLevelMethodAccess(Send node, MethodElement element);
  R visitTopLevelMethodInvocation(Send node,
                                  MethodElement element,
                                  NodeList arguments,
                                  Selector selector);

  R visitTopLevelPropertyAccess(Send node, FunctionElement element);
  R visitTopLevelPropertyAssignment(SendSet node,
                                    FunctionElement element,
                                    Node rhs);
  R visitTopLevelPropertyInvocation(Send node,
                                    FieldElement element,
                                    NodeList arguments,
                                    Selector selector);

  R visitClassTypeLiteralAccess(Send node, ClassElement element);
  R visitClassTypeLiteralInvocation(Send node,
                                    ClassElement element,
                                    NodeList arguments,
                                    Selector selector);
  R visitClassTypeLiteralAssignment(SendSet node,
                                    ClassElement element,
                                    Node rhs);

  R visitTypedefTypeLiteralAccess(Send node, TypedefElement element);

  R visitTypedefTypeLiteralInvocation(Send node,
                                      TypedefElement element,
                                      NodeList arguments,
                                      Selector selector);

  R visitTypedefTypeLiteralAssignment(SendSet node,
                                      TypedefElement element,
                                      Node rhs);

  R visitTypeVariableTypeLiteralAccess(Send node, TypeVariableElement element);

  R visitTypeVariableTypeLiteralInvocation(Send node,
                                           TypeVariableElement element,
                                           NodeList arguments,
                                           Selector selector);

  R visitTypeVariableTypeLiteralAssignment(SendSet node,
                                           TypeVariableElement element,
                                           Node rhs);

  R visitDynamicTypeLiteralAccess(Send node);

  R visitAssert(Send node, Node expression);

  internalError(Spannable spannable, String reason);

  R visitNode(Node node) {
    internalError(node, "Unhandled node");
    return null;
  }
}
