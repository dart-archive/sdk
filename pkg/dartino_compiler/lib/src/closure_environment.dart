// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.closure_environment;

import 'package:compiler/src/resolution/semantic_visitor.dart';

import 'package:compiler/src/resolution/operators.dart' show
    AssignmentOperator,
    BinaryOperator,
    IncDecOperator,
    UnaryOperator;

import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/resolution/tree_elements.dart';
import 'package:compiler/src/resolution/send_resolver.dart';
import 'package:compiler/src/tree/tree.dart';
import 'package:compiler/src/universe/selector.dart';
import 'package:compiler/src/universe/call_structure.dart';
import 'package:compiler/src/diagnostics/spannable.dart' show
    Spannable,
    SpannableAssertionFailure;
import 'package:compiler/src/dart_types.dart';

enum CaptureMode {
  /**
   * If a local is marked [ByValue], the local is read in closures.
   */
  ByValue,

  /**
   * If a local is marked [ByReference], a write to the local can be observed
   * from a closure.
   *
   * In this case, the local must be boxed.
   */
  ByReference,
}

/**
 * The computed infomation about a closures usage of locals and 'this'.
 */
class ClosureInfo {
  bool isThisFree = false;
  Set<LocalElement> free = new Set<LocalElement>();

  void markUsed(LocalElement element) {
    free.add(element);
  }
}

class ClosureEnvironment {
  /**
   * A map of locals that are captured, and how.
   */
  final Map<LocalElement, CaptureMode> captured = <LocalElement, CaptureMode>{};

  /**
   * A map of all nested closures of [function], and what locals they capture.
   */
  final Map<FunctionElement, ClosureInfo> closures =
      <FunctionElement, ClosureInfo>{};

  bool shouldBeBoxed(element) => captured[element] == CaptureMode.ByReference;
}

class ClosureVisitor
    extends SemanticVisitor
    with TraversalSendMixin,
         SemanticSendResolvedMixin,
         BaseImplementationOfLocalsMixin,
         VariableBulkMixin,
         ParameterBulkMixin,
         FunctionBulkMixin,
         ConstructorBulkMixin,
         InitializerBulkMixin
    implements SemanticSendVisitor, SemanticDeclarationVisitor {
  final ClosureEnvironment closureEnvironment = new ClosureEnvironment();

  /**
   * A set of all locals that are assigned in [function] excluding nested
   * closures. This is the inverse of implicit final locals.
   */
  final Set<LocalElement> locallyAssigned = new Set<LocalElement>();

  final MemberElement element;

  ExecutableElement currentElement;

  bool inInitializers = false;

  ClosureVisitor(this.element, TreeElements elements)
      : super(elements);

  SemanticSendVisitor get sendVisitor => this;
  SemanticDeclarationVisitor get declVisitor => this;

  ClosureEnvironment compute() {
    assert(element.memberContext == element);
    assert(currentElement == null);
    currentElement = element;
    if (element.node != null) element.resolvedAst.node.accept(this);
    assert(currentElement == element);
    return closureEnvironment;
  }

  void visitNode(Node node) {
    node.visitChildren(this);
  }

  void visitVariableDefinitions(VariableDefinitions node) {
    for (Node definition in node.definitions) {
      VariableElement element = elements[definition];
      Expression initializer = element.initializer;
      if (initializer != null) initializer.accept(this);
    }
  }

  void visitFunctionExpression(FunctionExpression node) {
    ExecutableElement oldElement = currentElement;
    currentElement = elements.getFunctionDefinition(node);
    if (currentElement != element) {
      ClosureInfo info = new ClosureInfo();
      closureEnvironment.closures[currentElement] = info;
    }
    if (currentElement.isConstructor) {
      inInitializers = true;
      visitInitializers(node, null);
      inInitializers = false;
    }
    node.body.accept(this);
    currentElement = oldElement;
  }

  void visitFieldInitializer(
      SendSet node,
      FieldElement field,
      Node initializer,
      _) {
    initializer.accept(this);
  }

  void visitSuperConstructorInvoke(
      Send node,
      ConstructorElement superConstructor,
      InterfaceType type,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    arguments.accept(this);
  }

  void visitThisConstructorInvoke(
      Send node,
      ConstructorElement thisConstructor,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    arguments.accept(this);
  }

  void markUsed(LocalElement element, CaptureMode use) {
    if (currentElement == element.executableContext) {
      // If a local is assigned in the declaring context, and it is captured
      // at this point, mark it as used by reference (we assign to the value
      // after it's captured).
      if (use == CaptureMode.ByReference) {
        if (closureEnvironment.captured.containsKey(element)) {
          closureEnvironment.captured[element] = use;
        } else {
          locallyAssigned.add(element);
        }
      }
    } else {
      if (locallyAssigned.contains(element)) use = CaptureMode.ByReference;
      // If the element is used by reference, upgrade it unconditionally.
      if (use == CaptureMode.ByReference) {
        closureEnvironment.captured[element] = use;
      } else {
        // If it's used by value, only add it to `captured` if it's not
        // there already - if it's in there it can be by reference.
        closureEnvironment.captured.putIfAbsent(element, () => use);
      }
      ExecutableElement current = currentElement;
      // Mark all closures from the current to the one where `element` is
      // defined, as used in that closure. That makes sure we capture it in
      // all intermidiate closures, thus making it available in the current.
      while (current != element.executableContext) {
        ClosureInfo info = closureEnvironment.closures[current];
        info.markUsed(element);
        current = (current as Local).executableContext;
      }
    }
  }

  void markThisUsed() {
    assert(!inInitializers);
    ExecutableElement current = currentElement;
    while (current != element) {
      ClosureInfo info = closureEnvironment.closures[current];
      info.isThisFree = true;
      current = (current as Local).executableContext;
    }
  }

  void handleLocalGet(Send node, LocalElement element, _) {
    markUsed(element, CaptureMode.ByValue);
  }

  void handleLocalSet(
      SendSet node,
      LocalElement element,
      Node rhs,
      _) {
    markUsed(element, CaptureMode.ByReference);
    rhs.accept(this);
  }

  void handleLocalInvoke(
      Send node,
      LocalElement element,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    markUsed(element, CaptureMode.ByValue);
    arguments.accept(this);
  }

  void visitThisPropertySet(Send node, Name name, Node rhs, _) {
    markThisUsed();
    super.visitThisPropertySet(node, name, rhs, null);
  }

  void visitLocalVariablePrefix(
      SendSet node,
      LocalVariableElement element,
      IncDecOperator operator,
      _) {
    markUsed(element, CaptureMode.ByReference);
  }

  void visitLocalVariablePostfix(
      SendSet node,
      LocalVariableElement element,
      IncDecOperator operator,
      _) {
    markUsed(element, CaptureMode.ByReference);
  }

  void visitThisPropertyInvoke(
      Send node,
      NodeList arguments,
      Selector selector,
      _) {
    markThisUsed();
    arguments.accept(this);
  }

  void visitThisPropertyGet(
      Send node,
      Name name,
      _) {
    markThisUsed();
  }

  void visitThisGet(Node node, _) {
    markThisUsed();
  }

  void visitIs(Send node, Node expression, DartType type, _) {
    // TODO(ajohnsen): Type is used ByValue.
    expression.accept(this);
  }

  void visitIsNot(Send node, Node expression, DartType type, _) {
    // TODO(ajohnsen): Type is used ByValue.
    expression.accept(this);
  }

  void visitAs(Send node, Node expression, DartType type, _) {
    // TODO(ajohnsen): Type is used ByValue.
    expression.accept(this);
  }

  void visitAssert(Assert node) {
    // TODO(ajohnsen): Only visit in checked mode.
    node.condition.accept(this);
    node.message?.accept(this);
  }

  void visitLocalVariableCompound(
      Send node,
      LocalVariableElement variable,
      AssignmentOperator operator,
      Node rhs,
      _) {
    markUsed(variable, CaptureMode.ByReference);
    super.visitLocalVariableCompound(node, variable, operator, rhs, null);
  }

  void internalError(Spannable spannable, String message) {
    throw new SpannableAssertionFailure(spannable, message);
  }

  void apply(Node node, [_]) {
    node.accept(this);
  }

  void visitThisInvoke(
      Send node,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    markThisUsed();
    super.visitThisInvoke(node, arguments, callStructure, null);
  }

  void visitSuperFieldGet(
      Send node,
      FieldElement field,
      _) {
    markThisUsed();
    super.visitSuperFieldGet(node, field, null);
  }

  void visitSuperFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _) {
    markThisUsed();
    super.visitSuperFieldSet(node, field, rhs, null);
  }

  void visitSuperFieldInvoke(
      Send node,
      FieldElement field,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    markThisUsed();
    super.visitSuperFieldInvoke(node, field, arguments, callStructure, null);
  }

  void visitSuperMethodGet(
      Send node,
      MethodElement method,
      _) {
    markThisUsed();
    super.visitSuperMethodGet(node, method, null);
  }

  void visitSuperGetterGet(
      Send node,
      FunctionElement getter,
      _) {
    markThisUsed();
    super.visitSuperGetterGet(node, getter, null);
  }

  void visitSuperSetterSet(
      SendSet node,
      FunctionElement setter,
      Node rhs,
      _) {
    markThisUsed();
    super.visitSuperSetterSet(node, setter, rhs, null);
  }

  void visitSuperGetterInvoke(
      Send node,
      FunctionElement getter,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    markThisUsed();
    super.visitSuperGetterInvoke(node, getter, arguments, callStructure, null);
  }

  void visitTypeVariableTypeLiteralGet(
      Send node,
      TypeVariableElement element,
      _) {
    // TODO(ajohnsen): Visit 'this' for type literal support, except for
    // closures in initializers.
    super.visitTypeVariableTypeLiteralGet(node, element, null);
  }

  void visitTypeVariableTypeLiteralInvoke(
      Send node,
      TypeVariableElement element,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    // TODO(ajohnsen): Visit 'this' for type literal support, except for
    // closures in initializers.
    super.visitTypeVariableTypeLiteralInvoke(
        node, element, arguments, callStructure, null);
  }

  void visitSuperBinary(
      Send node,
      FunctionElement function,
      BinaryOperator operator,
      Node argument,
      _) {
    markThisUsed();
    super.visitSuperBinary(node, function, operator, argument, null);
  }

  void visitSuperIndex(
      Send node,
      FunctionElement function,
      Node index,
      _) {
    markThisUsed();
    super.visitSuperIndex(node, function, index, null);
  }

  void visitSuperIndexPostfix(
      SendSet node,
      FunctionElement getter,
      FunctionElement setter,
      Node index,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitSuperIndexPostfix(node, getter, setter, index, operator, null);
  }

  void visitSuperNotEquals(
      Send node,
      FunctionElement function,
      Node argument,
      _) {
    markThisUsed();
    super.visitSuperNotEquals(node, function, argument, null);
  }

  void visitSuperEquals(
      Send node,
      FunctionElement function,
      Node argument,
      _) {
    markThisUsed();
    super.visitSuperEquals(node, function, argument, null);
  }

  void visitSuperUnary(
      Send node,
      UnaryOperator operator,
      FunctionElement function,
      _) {
    markThisUsed();
    super.visitSuperUnary(node, operator, function, null);
  }

  void visitSuperIndexSet(
      Send node,
      FunctionElement function,
      Node index,
      Node rhs,
      _) {
    markThisUsed();
    super.visitSuperIndexSet(node, function, index, rhs, null);
  }

  void visitThisPropertyCompound(
      Send node,
      Name name,
      AssignmentOperator operator,
      Node rhs,
      _) {
    markThisUsed();
    super.visitThisPropertyCompound(
        node, name, operator, rhs, null);
  }

  void visitParameterCompound(
      Send node,
      ParameterElement parameter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    markUsed(parameter, CaptureMode.ByReference);
    super.visitParameterCompound(node, parameter, operator, rhs, null);
  }

  void visitSuperFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    markThisUsed();
    super.visitSuperFieldCompound(node, field, operator, rhs, null);
  }

  void visitSuperGetterSetterCompound(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    markThisUsed();
    super.visitSuperGetterSetterCompound(
        node, getter, setter, operator, rhs, null);
  }

  void visitSuperMethodSetterCompound(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    markThisUsed();
    super.visitSuperMethodSetterCompound(
        node, method, setter, operator, rhs, null);
  }

  void visitSuperFieldSetterCompound(
      Send node,
      FieldElement field,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    markThisUsed();
    super.visitSuperFieldSetterCompound(
        node, field, setter, operator, rhs, null);
  }

  void visitSuperGetterFieldCompound(
      Send node,
      FunctionElement getter,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    markThisUsed();
    super.visitSuperGetterFieldCompound(
        node, getter, field, operator, rhs, null);
  }

  void visitSuperCompoundIndexSet(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      Node index,
      AssignmentOperator operator,
      Node rhs,
      _) {
    markThisUsed();
    super.visitSuperCompoundIndexSet(
        node, getter, setter, index, operator, rhs, null);
  }

  void visitParameterPrefix(
      Send node,
      ParameterElement parameter,
      IncDecOperator operator,
      _) {
    markUsed(parameter, CaptureMode.ByReference);
    super.visitParameterPrefix(node, parameter, operator, null);
  }

  void visitThisPropertyPrefix(
      Send node,
      Name name,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitThisPropertyPrefix(
        node, name, operator, null);
  }

  void visitSuperFieldPrefix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitSuperFieldPrefix(node, field, operator, null);
  }

  void visitSuperFieldFieldPrefix(
      Send node,
      FieldElement readField,
      FieldElement writtenField,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitSuperFieldFieldPrefix(
        node, readField, writtenField, operator, null);
  }

  void visitSuperFieldSetterPrefix(
      Send node,
      FieldElement field,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitSuperFieldSetterPrefix(node, field, setter, operator, null);
  }

  void visitSuperGetterSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitSuperGetterSetterPrefix(node, getter, setter, operator, null);
  }

  void visitSuperGetterFieldPrefix(
      Send node,
      FunctionElement getter,
      FieldElement field,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitSuperGetterFieldPrefix(node, getter, field, operator, null);
  }

  void visitSuperMethodSetterPrefix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitSuperMethodSetterPrefix(node, method, setter, operator, null);
  }

  void visitTypeVariableTypeLiteralPrefix(
      Send node,
      TypeVariableElement element,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitTypeVariableTypeLiteralPrefix(node, element, operator, null);
  }

  void visitParameterPostfix(
      Send node,
      ParameterElement parameter,
      IncDecOperator operator,
      _) {
    markUsed(parameter, CaptureMode.ByReference);
    super.visitParameterPostfix(node, parameter, operator, null);
  }

  void visitThisPropertyPostfix(
      Send node,
      Name name,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitThisPropertyPostfix(
        node, name, operator, null);
  }

  void visitSuperFieldPostfix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitSuperFieldPostfix(node, field, operator, null);
  }

  void visitSuperFieldFieldPostfix(
      Send node,
      FieldElement readField,
      FieldElement writtenField,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitSuperFieldFieldPostfix(
        node, readField, writtenField, operator, null);
  }

  void visitSuperFieldSetterPostfix(
      Send node,
      FieldElement field,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitSuperFieldSetterPostfix(node, field, setter, operator, null);
  }

  void visitSuperGetterSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitSuperGetterSetterPostfix(node, getter, setter, operator, null);
  }

  void visitSuperGetterFieldPostfix(
      Send node,
      FunctionElement getter,
      FieldElement field,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitSuperGetterFieldPostfix(node, getter, field, operator, null);
  }

  void visitSuperMethodSetterPostfix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitSuperMethodSetterPostfix(node, method, setter, operator, null);
  }

  void visitTypeVariableTypeLiteralPostfix(
      Send node,
      TypeVariableElement element,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitTypeVariableTypeLiteralPostfix(node, element, operator, null);
  }

  void visitSuperIndexPrefix(
      Send node,
      FunctionElement indexFunction,
      FunctionElement indexSetFunction,
      Node index,
      IncDecOperator operator,
      _) {
    markThisUsed();
    super.visitSuperIndexPrefix(
        node, indexFunction, indexSetFunction, index, operator, null);
  }

  @override
  void visitTypeAnnotation(TypeAnnotation node) {
  // This is to avoid the inherited implementation that visits children and
  // throws when encountering anything unresolved.
  }

  void handleImmutableLocalSet(
      SendSet node,
      LocalElement element,
      Node rhs,
      _) {
    apply(rhs);
  }

  void bulkHandleNode(Node node, String message, _) {
  }

  void applyInitializers(FunctionExpression initializers, _) {
  }

  void applyParameters(NodeList parameters, _) {
  }
}
