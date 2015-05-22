// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.closure_environment;

import 'package:compiler/src/util/util.dart' show
    SpannableAssertionFailure;

import 'package:compiler/src/resolution/semantic_visitor.dart';

import 'package:compiler/src/resolution/operators.dart' show
    AssignmentOperator,
    BinaryOperator,
    IncDecOperator,
    UnaryOperator;

import 'package:compiler/src/constants/expressions.dart' show
    ConstantExpression,
    ConstructedConstantExpression,
    TypeConstantExpression;

import 'package:compiler/src/dart2jslib.dart' show
    MessageKind,
    Registry;

import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/resolution/resolution.dart';
import 'package:compiler/src/tree/tree.dart';
import 'package:compiler/src/universe/universe.dart';
import 'package:compiler/src/util/util.dart' show Spannable;
import 'package:compiler/src/dart_types.dart';

import 'fletch_context.dart';

import 'fletch_constants.dart' show
    CompiledFunctionConstant,
    FletchClassConstant;

import '../bytecodes.dart' show
    Bytecode;

import 'compiled_function.dart' show
    CompiledFunction;

import 'fletch_selector.dart';

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
    extends Visitor
    with TraversalSendMixin,
         SemanticSendResolvedMixin,
         SendResolverMixin,
         BaseImplementationOfLocalsMixin
    implements SemanticSendVisitor {
  final ClosureEnvironment closureEnvironment = new ClosureEnvironment();

  /**
   * A set of all locals that are assigned in [function] excluding nested
   * closures. This is the inverse of implicit final locals.
   */
  final Set<LocalElement> locallyAssigned = new Set<LocalElement>();

  final MemberElement element;

  final TreeElements elements;

  ExecutableElement currentElement;

  ClosureVisitor(this.element, this.elements);

  SemanticSendVisitor get sendVisitor => this;

  ClosureEnvironment compute() {
    assert(element.memberContext == element);
    assert(currentElement == null);
    currentElement = element;
    if (element.node != null) element.node.accept(this);
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
    currentElement = elements[node];
    if (currentElement != element) {
      ClosureInfo info = new ClosureInfo();
      closureEnvironment.closures[currentElement] = info;
    }
    NodeList initializers = node.initializers;
    if (initializers != null) {
      for (var initializer in initializers) {
        Element element = elements[initializer];
        if (element != null && !element.isGenerativeConstructor) {
          initializer.accept(this);
        }
      }
    }
    node.body.accept(this);
    currentElement = oldElement;
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

  void visitThisPropertySet(Send node, Selector selector, Node rhs, _) {
    rhs.accept(this);
    markThisUsed();
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
      Selector selector,
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

  void visitAssert(Send node, Node expression, _) {
    // TODO(ajohnsen): Only visit in checked mode.
    expression.accept(this);
  }

  void visitLocalVariableCompound(
      Send node,
      LocalVariableElement variable,
      AssignmentOperator operator,
      Node rhs,
      _) {
    markUsed(variable, CaptureMode.ByReference);
    node.visitChildren(this);
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
    node.visitChildren(this);
  }

  void visitSuperFieldGet(
      Send node,
      FieldElement field,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void errorFinalSuperFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _) {
    markThisUsed(); // For invoking noSuchMethod.
    node.visitChildren(this);
  }

  void visitSuperFieldInvoke(
      Send node,
      FieldElement field,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperMethodGet(
      Send node,
      MethodElement method,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperGetterGet(
      Send node,
      FunctionElement getter,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperSetterSet(
      SendSet node,
      FunctionElement setter,
      Node rhs,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperGetterInvoke(
      Send node,
      FunctionElement getter,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitTypeVariableTypeLiteralGet(
      Send node,
      TypeVariableElement element,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitTypeVariableTypeLiteralInvoke(
      Send node,
      TypeVariableElement element,
      NodeList arguments,
      CallStructure callStructure,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void errorTypeVariableTypeLiteralSet(
      SendSet node,
      TypeVariableElement element,
      Node rhs,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperBinary(
      Send node,
      FunctionElement function,
      BinaryOperator operator,
      Node argument,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperIndex(
      Send node,
      FunctionElement function,
      Node index,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperIndexPostfix(
      SendSet node,
      FunctionElement getter,
      FunctionElement setter,
      Node index,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperNotEquals(
      Send node,
      FunctionElement function,
      Node argument,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperEquals(
      Send node,
      FunctionElement function,
      Node argument,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperUnary(
      Send node,
      UnaryOperator operator,
      FunctionElement function,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperIndexSet(
      Send node,
      FunctionElement function,
      Node index,
      Node rhs,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitThisPropertyCompound(
      Send node,
      AssignmentOperator operator,
      Node rhs,
      Selector getterSelector,
      Selector setterSelector,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitParameterCompound(
      Send node,
      ParameterElement parameter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    markUsed(parameter, CaptureMode.ByReference);
    node.visitChildren(this);
  }

  void visitSuperFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperGetterSetterCompound(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperMethodSetterCompound(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperFieldSetterCompound(
      Send node,
      FieldElement field,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperGetterFieldCompound(
      Send node,
      FunctionElement getter,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    markThisUsed();
    node.visitChildren(this);
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
    node.visitChildren(this);
  }

  void visitParameterPrefix(
      Send node,
      ParameterElement parameter,
      IncDecOperator operator,
      _) {
    markUsed(parameter, CaptureMode.ByReference);
    node.visitChildren(this);
  }

  void visitThisPropertyPrefix(
      Send node,
      IncDecOperator operator,
      Selector getterSelector,
      Selector setterSelector,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperFieldPrefix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperFieldFieldPrefix(
      Send node,
      FieldElement readField,
      FieldElement writtenField,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperFieldSetterPrefix(
      Send node,
      FieldElement field,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }


  void visitSuperGetterSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperGetterFieldPrefix(
      Send node,
      FunctionElement getter,
      FieldElement field,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperMethodSetterPrefix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitTypeVariableTypeLiteralPrefix(
      Send node,
      TypeVariableElement element,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitParameterPostfix(
      Send node,
      ParameterElement parameter,
      IncDecOperator operator,
      _) {
    markUsed(parameter, CaptureMode.ByReference);
    node.visitChildren(this);
  }

  void visitThisPropertyPostfix(
      Send node,
      IncDecOperator operator,
      Selector getterSelector,
      Selector setterSelector,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperFieldPostfix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperFieldFieldPostfix(
      Send node,
      FieldElement readField,
      FieldElement writtenField,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperFieldSetterPostfix(
      Send node,
      FieldElement field,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }


  void visitSuperGetterSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperGetterFieldPostfix(
      Send node,
      FunctionElement getter,
      FieldElement field,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperMethodSetterPostfix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitTypeVariableTypeLiteralPostfix(
      Send node,
      TypeVariableElement element,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void visitSuperIndexPrefix(
      Send node,
      FunctionElement indexFunction,
      FunctionElement indexSetFunction,
      Node index,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void errorUnresolvedSuperIndexPrefix(
      Send node,
      Element function,
      Node index,
      IncDecOperator operator,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void handleImmutableLocalSet(
      SendSet node,
      LocalElement element,
      Node rhs,
      _) {
    apply(rhs);
  }
}
