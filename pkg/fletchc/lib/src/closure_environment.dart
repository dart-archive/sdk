// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.closure_environment;

import 'package:compiler/src/util/util.dart' show
    SpannableAssertionFailure;

import 'package:compiler/src/resolution/semantic_visitor.dart' show
    SemanticSendVisitor,
    SemanticVisitor;

import 'package:compiler/src/resolution/operators.dart' show
    AssignmentOperator,
    BinaryOperator,
    IncDecOperator,
    UnaryOperator;

import 'package:compiler/src/constants/expressions.dart' show
    ConstantExpression,
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
    extends SemanticVisitor
    implements SemanticSendVisitor {
  final ClosureEnvironment closureEnvironment = new ClosureEnvironment();

  /**
   * A set of all locals that are assigned in [function] excluding nested
   * closures. This is the inverse of implicit final locals.
   */
  final Set<LocalElement> locallyAssigned = new Set<LocalElement>();

  final FunctionElement function;

  FunctionElement currentFunction;

  ClosureVisitor(this.function, TreeElements elements)
      : super(elements);

  SemanticSendVisitor get sendVisitor => this;

  ClosureEnvironment compute() {
    assert(function.memberContext == function);
    assert(currentFunction == null);
    currentFunction = function;
    if (function.node != null) function.node.body.accept(this);
    assert(currentFunction == function);
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
    FunctionElement oldFunction = currentFunction;
    currentFunction = elements[node];
    ClosureInfo info = new ClosureInfo();
    closureEnvironment.closures[currentFunction] = info;
    node.body.accept(this);
    currentFunction = oldFunction;
  }

  void markUsed(LocalElement element, CaptureMode use) {
    if (currentFunction == element.executableContext) {
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
      FunctionElement current = currentFunction;
      // Mark all closures from the current to the one where `element` is
      // defined, as used in that closure. That makes sure we capture it in
      // all intermidiate closures, thus making it available in the current.
      while (current != element.executableContext) {
        ClosureInfo info = closureEnvironment.closures[current];
        info.markUsed(element);
        LocalFunctionElement local = current;
        current = local.executableContext;
      }
    }
  }

  void markThisUsed() {
    FunctionElement current = currentFunction;
    while (current != function) {
      ClosureInfo info = closureEnvironment.closures[current];
      info.isThisFree = true;
      LocalFunctionElement local = current;
      current = local.executableContext;
    }
  }

  void visitLocalVariableGet(Send node, LocalVariableElement element, _) {
    markUsed(element, CaptureMode.ByValue);
  }

  void visitLocalFunctionGet(Send node, LocalFunctionElement element, _) {
    markUsed(element, CaptureMode.ByValue);
  }

  void visitParameterGet(Send node, ParameterElement element, _) {
    markUsed(element, CaptureMode.ByValue);
  }

  void visitParameterSet(SendSet node, ParameterElement element, Node rhs, _) {
    rhs.accept(this);
    markUsed(element, CaptureMode.ByReference);
  }

  void visitThisPropertySet(Send node, Selector selector, Node rhs, _) {
    rhs.accept(this);
    markThisUsed();
  }

  void visitLocalVariableSet(
      SendSet node,
      LocalVariableElement element,
      Node rhs,
      _) {
    markUsed(element, CaptureMode.ByReference);
    rhs.accept(this);
  }

  void visitLocalVariableInvoke(
      Send node,
      LocalVariableElement element,
      NodeList arguments,
      Selector selector,
      _) {
    markUsed(element, CaptureMode.ByValue);
    arguments.accept(this);
  }

  void visitParameterInvoke(
      Send node,
      ParameterElement element,
      NodeList arguments,
      Selector selector,
      _) {
    markUsed(element, CaptureMode.ByValue);
    arguments.accept(this);
  }

  void visitLocalFunctionInvoke(
      Send node,
      LocalFunctionElement element,
      NodeList arguments,
      Selector selector,
      _) {
    markUsed(element, CaptureMode.ByValue);
    arguments.accept(this);
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

  void visitTopLevelFunctionInvoke(
      Send node,
      MethodElement element,
      NodeList arguments,
      Selector selector,
      _) {
    arguments.accept(this);
  }

  void visitSuperMethodInvoke(
      Send node,
      MethodElement element,
      NodeList arguments,
      Selector selector,
      _) {
    arguments.accept(this);
  }

  void visitTopLevelFieldGet(Send node, FieldElement element, _) {
    // Intentionally empty: there is just nothing to visit in this case.
  }

  void visitStaticFieldGet(Send node, FieldElement element, _) {
    // Intentionally empty: there is just nothing to visit in this case.
  }

  void visitTopLevelFieldInvoke(
      Send node,
      FieldElement element,
      NodeList arguments,
      Selector selector,
      _) {
    arguments.accept(this);
  }

  void visitTopLevelFieldSet(
      SendSet node,
      FieldElement element,
      Node rhs,
      _) {
    rhs.accept(this);
  }

  void visitStaticFunctionInvoke(
      Send node,
      /* MethodElement */ element,
      NodeList arguments,
      Selector selector,
      _) {
    arguments.accept(this);
  }

  void visitNewExpression(NewExpression node) {
    node.send.argumentsNode.accept(this);
  }

  void visitExpressionInvoke(
      Send node,
      Expression receiver,
      NodeList arguments,
      Selector selector,
      _) {
    receiver.accept(this);
    arguments.accept(this);
  }

  void visitDynamicPropertyInvoke(
      Send node,
      Node receiver,
      NodeList arguments,
      Selector selector,
      _) {
    receiver.accept(this);
    arguments.accept(this);
  }

  void visitDynamicPropertyGet(
      Send node,
      Node receiver,
      Selector selector,
      _) {
    receiver.accept(this);
  }

  void visitDynamicPropertySet(
      Send node,
      Node receiver,
      Selector selector,
      Node rhs,
      _) {
    receiver.accept(this);
    rhs.accept(this);
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

  void visitBinary(
      Send node,
      Node left,
      BinaryOperator operator,
      Node right,
      _) {
    left.accept(this);
    right.accept(this);
  }

  void visitUnary(
      Send node,
      UnaryOperator operator,
      Node value,
      _) {
    value.accept(this);
  }

  void visitNot(
      Send node,
      Node value,
      _) {
    value.accept(this);
  }

  void visitIndexSet(
      SendSet node,
      Node receiver,
      Node index,
      Node value,
      _) {
    receiver.accept(this);
    index.accept(this);
    value.accept(this);
  }

  void visitEquals(Send node, Node left, Node right, _) {
    left.accept(this);
    right.accept(this);
  }

  void visitNotEquals(Send node, Node left, Node right, _) {
    left.accept(this);
    right.accept(this);
  }

  void visitLogicalAnd(Send node, Node left, Node right, _) {
    left.accept(this);
    right.accept(this);
  }

  void visitLogicalOr(Send node, Node left, Node right, _) {
    left.accept(this);
    right.accept(this);
  }

  void visitAssert(Send node, Node expression, _) {
    // TODO(ajohnsen): Only visit in checked mode.
    expression.accept(this);
  }

  void visitStaticFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitLocalVariableCompound(
      Send node,
      LocalVariableElement variable,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void errorUnresolvedInvoke(
      Send node,
      Element element,
      Node arguments,
      Selector selector,
      _) {
    // Don't report errors here.
  }

  void internalError(Spannable spannable, String message) {
    throw new SpannableAssertionFailure(spannable, message);
  }

  void apply(Node node, _) {
    internalError(node, "[apply] isn't implemented yet.");
  }

  void errorFinalParameterSet(
      SendSet node,
      ParameterElement parameter,
      Node rhs,
      _) {
    internalError(node, "[errorFinalParameterSet] isn't implemented yet.");
  }

  void errorFinalLocalVariableSet(
      SendSet node,
      LocalVariableElement variable,
      Node rhs,
      _) {
    internalError(node, "[errorFinalLocalVariableSet] isn't implemented yet.");
  }

  void errorLocalFunctionSet(
      SendSet node,
      LocalFunctionElement function,
      Node rhs,
      _) {
    internalError(node, "[errorLocalFunctionSet] isn't implemented yet.");
  }

  void visitThisInvoke(
      Send node,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(node, "[visitThisInvoke] isn't implemented yet.");
  }

  void visitSuperFieldGet(
      Send node,
      FieldElement field,
      _) {
    internalError(node, "[visitSuperFieldGet] isn't implemented yet.");
  }

  void visitSuperFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _) {
    internalError(node, "[visitSuperFieldSet] isn't implemented yet.");
  }

  void errorFinalSuperFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _) {
    internalError(node, "[errorFinalSuperFieldSet] isn't implemented yet.");
  }

  void visitSuperFieldInvoke(
      Send node,
      FieldElement field,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(node, "[visitSuperFieldInvoke] isn't implemented yet.");
  }

  void visitSuperMethodGet(
      Send node,
      MethodElement method,
      _) {
    internalError(node, "[visitSuperMethodGet] isn't implemented yet.");
  }

  void errorSuperMethodSet(
      Send node,
      MethodElement method,
      Node rhs,
      _) {
    internalError(node, "[errorSuperMethodSet] isn't implemented yet.");
  }

  void visitSuperGetterGet(
      Send node,
      FunctionElement getter,
      _) {
    internalError(node, "[visitSuperGetterGet] isn't implemented yet.");
  }

  void errorSuperSetterGet(
      Send node,
      FunctionElement setter,
      _) {
    internalError(node, "[errorSuperSetterGet] isn't implemented yet.");
  }

  void visitSuperSetterSet(
      SendSet node,
      FunctionElement setter,
      Node rhs,
      _) {
    internalError(node, "[visitSuperSetterSet] isn't implemented yet.");
  }

  void errorSuperGetterSet(
      SendSet node,
      FunctionElement getter,
      Node rhs,
      _) {
    internalError(node, "[errorSuperGetterSet] isn't implemented yet.");
  }

  void visitSuperGetterInvoke(
      Send node,
      FunctionElement getter,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(node, "[visitSuperGetterInvoke] isn't implemented yet.");
  }

  void errorSuperSetterInvoke(
      Send node,
      FunctionElement setter,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(node, "[errorSuperSetterInvoke] isn't implemented yet.");
  }

  void errorFinalStaticFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _) {
    internalError(node, "[errorFinalStaticFieldSet] isn't implemented yet.");
  }

  void visitStaticFieldInvoke(
      Send node,
      FieldElement field,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(node, "[visitStaticFieldInvoke] isn't implemented yet.");
  }

  void visitStaticFunctionGet(
      Send node,
      MethodElement function,
      _) {
    internalError(node, "[visitStaticFunctionGet] isn't implemented yet.");
  }

  void errorStaticFunctionSet(
      Send node,
      MethodElement function,
      Node rhs,
      _) {
    internalError(node, "[errorStaticFunctionSet] isn't implemented yet.");
  }

  void visitStaticGetterGet(
      Send node,
      FunctionElement getter,
      _) {
    internalError(node, "[visitStaticGetterGet] isn't implemented yet.");
  }

  void errorStaticSetterGet(
      Send node,
      FunctionElement setter,
      _) {
    internalError(node, "[errorStaticSetterGet] isn't implemented yet.");
  }

  void visitStaticSetterSet(
      SendSet node,
      FunctionElement setter,
      Node rhs,
      _) {
    internalError(node, "[visitStaticSetterSet] isn't implemented yet.");
  }

  void errorStaticGetterSet(
      SendSet node,
      FunctionElement getter,
      Node rhs,
      _) {
    internalError(node, "[errorStaticGetterSet] isn't implemented yet.");
  }

  void visitStaticGetterInvoke(
      Send node,
      FunctionElement getter,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(node, "[visitStaticGetterInvoke] isn't implemented yet.");
  }

  void errorStaticSetterInvoke(
      Send node,
      FunctionElement setter,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(node, "[errorStaticSetterInvoke] isn't implemented yet.");
  }

  void errorFinalTopLevelFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _) {
    internalError(node, "[errorFinalTopLevelFieldSet] isn't implemented yet.");
  }

  void visitTopLevelFunctionGet(
      Send node,
      MethodElement function,
      _) {
    internalError(node, "[visitTopLevelFunctionGet] isn't implemented yet.");
  }

  void errorTopLevelFunctionSet(
      Send node,
      MethodElement function,
      Node rhs,
      _) {
    internalError(node, "[errorTopLevelFunctionSet] isn't implemented yet.");
  }

  void visitTopLevelGetterGet(
      Send node,
      FunctionElement getter,
      _) {
    internalError(node, "[visitTopLevelGetterGet] isn't implemented yet.");
  }

  void errorTopLevelSetterGet(
      Send node,
      FunctionElement setter,
      _) {
    internalError(node, "[errorTopLevelSetterGet] isn't implemented yet.");
  }

  void visitTopLevelSetterSet(
      SendSet node,
      FunctionElement setter,
      Node rhs,
      _) {
    internalError(node, "[visitTopLevelSetterSet] isn't implemented yet.");
  }

  void errorTopLevelGetterSet(
      SendSet node,
      FunctionElement getter,
      Node rhs,
      _) {
    internalError(node, "[errorTopLevelGetterSet] isn't implemented yet.");
  }

  void visitTopLevelGetterInvoke(
      Send node,
      FunctionElement getter,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(node, "[visitTopLevelGetterInvoke] isn't implemented yet.");
  }

  void errorTopLevelSetterInvoke(
      Send node,
      FunctionElement setter,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(node, "[errorTopLevelSetterInvoke] isn't implemented yet.");
  }

  void visitClassTypeLiteralGet(
      Send node,
      TypeConstantExpression constant,
      _) {
    internalError(node, "[visitClassTypeLiteralGet] isn't implemented yet.");
  }

  void visitClassTypeLiteralInvoke(
      Send node,
      TypeConstantExpression constant,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(node, "[visitClassTypeLiteralInvoke] isn't implemented yet.");
  }

  void errorClassTypeLiteralSet(
      SendSet node,
      TypeConstantExpression constant,
      Node rhs,
      _) {
    internalError(node, "[errorClassTypeLiteralSet] isn't implemented yet.");
  }

  void visitTypedefTypeLiteralGet(
      Send node,
      TypeConstantExpression constant,
      _) {
    internalError(node, "[visitTypedefTypeLiteralGet] isn't implemented yet.");
  }

  void visitTypedefTypeLiteralInvoke(
      Send node,
      TypeConstantExpression constant,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(
        node, "[visitTypedefTypeLiteralInvoke] isn't implemented yet.");
  }

  void errorTypedefTypeLiteralSet(
      SendSet node,
      TypeConstantExpression constant,
      Node rhs,
      _) {
    internalError(node, "[errorTypedefTypeLiteralSet] isn't implemented yet.");
  }

  void visitTypeVariableTypeLiteralGet(
      Send node,
      TypeVariableElement element,
      _) {
    internalError(
        node, "[visitTypeVariableTypeLiteralGet] isn't implemented yet.");
  }

  void visitTypeVariableTypeLiteralInvoke(
      Send node,
      TypeVariableElement element,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(
        node, "[visitTypeVariableTypeLiteralInvoke] isn't implemented yet.");
  }

  void errorTypeVariableTypeLiteralSet(
      SendSet node,
      TypeVariableElement element,
      Node rhs,
      _) {
    internalError(
        node, "[errorTypeVariableTypeLiteralSet] isn't implemented yet.");
  }

  void visitDynamicTypeLiteralGet(
      Send node,
      TypeConstantExpression constant,
      _) {
    internalError(node, "[visitDynamicTypeLiteralGet] isn't implemented yet.");
  }

  void visitDynamicTypeLiteralInvoke(
      Send node,
      TypeConstantExpression constant,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(
        node, "[visitDynamicTypeLiteralInvoke] isn't implemented yet.");
  }

  void errorDynamicTypeLiteralSet(
      SendSet node,
      TypeConstantExpression constant,
      Node rhs,
      _) {
    internalError(node, "[errorDynamicTypeLiteralSet] isn't implemented yet.");
  }

  void errorInvalidAssert(
      Send node,
      NodeList arguments,
      _) {
    internalError(node, "[errorInvalidAssert] isn't implemented yet.");
  }

  void visitSuperBinary(
      Send node,
      FunctionElement function,
      BinaryOperator operator,
      Node argument,
      _) {
    internalError(node, "[visitSuperBinary] isn't implemented yet.");
  }

  void visitSuperNotEquals(
      Send node,
      FunctionElement function,
      Node argument,
      _) {
    internalError(node, "[visitSuperNotEquals] isn't implemented yet.");
  }

  void visitSuperEquals(
      Send node,
      FunctionElement function,
      Node argument,
      _) {
    internalError(node, "[visitSuperEquals] isn't implemented yet.");
  }

  void visitSuperUnary(
      Send node,
      UnaryOperator operator,
      FunctionElement function,
      _) {
    internalError(node, "[visitSuperUnary] isn't implemented yet.");
  }

  void visitSuperIndexSet(
      Send node,
      FunctionElement function,
      Node index,
      Node rhs,
      _) {
    internalError(node, "[visitSuperIndexSet] isn't implemented yet.");
  }

  void visitDynamicPropertyCompound(
      Send node,
      Node receiver,
      AssignmentOperator operator,
      Node rhs,
      Selector getterSelector,
      Selector setterSelector,
      _) {
    internalError(
        node, "[visitDynamicPropertyCompound] isn't implemented yet.");
  }

  void visitThisPropertyCompound(
      Send node,
      AssignmentOperator operator,
      Node rhs,
      Selector getterSelector,
      Selector setterSelector,
      _) {
    internalError(node, "[visitThisPropertyCompound] isn't implemented yet.");
  }

  void visitParameterCompound(
      Send node,
      ParameterElement parameter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(node, "[visitParameterCompound] isn't implemented yet.");
  }

  void errorFinalParameterCompound(
      Send node,
      ParameterElement parameter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(node, "[errorFinalParameterCompound] isn't implemented yet.");
  }

  void errorFinalLocalVariableCompound(
      Send node,
      LocalVariableElement variable,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[errorFinalLocalVariableCompound] isn't implemented yet.");
  }

  void errorLocalFunctionCompound(
      Send node,
      LocalFunctionElement function,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(node, "[errorLocalFunctionCompound] isn't implemented yet.");
  }

  void visitStaticFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(node, "[visitStaticFieldCompound] isn't implemented yet.");
  }

  void errorFinalStaticFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[errorFinalStaticFieldCompound] isn't implemented yet.");
  }

  void visitStaticGetterSetterCompound(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[visitStaticGetterSetterCompound] isn't implemented yet.");
  }

  void visitStaticMethodSetterCompound(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[visitStaticMethodSetterCompound] isn't implemented yet.");
  }

  void visitTopLevelFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(node, "[visitTopLevelFieldCompound] isn't implemented yet.");
  }

  void errorFinalTopLevelFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[errorFinalTopLevelFieldCompound] isn't implemented yet.");
  }

  void visitTopLevelGetterSetterCompound(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[visitTopLevelGetterSetterCompound] isn't implemented yet.");
  }

  void visitTopLevelMethodSetterCompound(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[visitTopLevelMethodSetterCompound] isn't implemented yet.");
  }

  void visitSuperFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(node, "[visitSuperFieldCompound] isn't implemented yet.");
  }

  void errorFinalSuperFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[errorFinalSuperFieldCompound] isn't implemented yet.");
  }

  void visitSuperGetterSetterCompound(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[visitSuperGetterSetterCompound] isn't implemented yet.");
  }

  void visitSuperMethodSetterCompound(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[visitSuperMethodSetterCompound] isn't implemented yet.");
  }

  void visitSuperFieldSetterCompound(
      Send node,
      FieldElement field,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[visitSuperFieldSetterCompound] isn't implemented yet.");
  }

  void visitSuperGetterFieldCompound(
      Send node,
      FunctionElement getter,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[visitSuperGetterFieldCompound] isn't implemented yet.");
  }

  void visitClassTypeLiteralCompound(
      Send node,
      TypeConstantExpression constant,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[visitClassTypeLiteralCompound] isn't implemented yet.");
  }

  void visitTypedefTypeLiteralCompound(
      Send node,
      TypeConstantExpression constant,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[visitTypedefTypeLiteralCompound] isn't implemented yet.");
  }

  void visitTypeVariableTypeLiteralCompound(
      Send node,
      TypeVariableElement element,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[visitTypeVariableTypeLiteralCompound] isn't implemented yet.");
  }

  void visitDynamicTypeLiteralCompound(
      Send node,
      TypeConstantExpression constant,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[visitDynamicTypeLiteralCompound] isn't implemented yet.");
  }

  void visitCompoundIndexSet(
      Send node,
      Node receiver,
      Node index,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(node, "[visitCompoundIndexSet] isn't implemented yet.");
  }

  void visitSuperCompoundIndexSet(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      Node index,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(node, "[visitSuperCompoundIndexSet] isn't implemented yet.");
  }

  void visitDynamicPropertyPrefix(
      Send node,
      Node receiver,
      IncDecOperator operator,
      Selector getterSelector,
      Selector setterSelector,
      _) {
    internalError(node, "[visitDynamicPropertyPrefix] isn't implemented yet.");
  }

  void visitParameterPrefix(
      Send node,
      ParameterElement parameter,
      IncDecOperator operator,
      _) {
    internalError(node, "[visitParameterPrefix] isn't implemented yet.");
  }

  void errorLocalFunctionPrefix(
      Send node,
      LocalFunctionElement function,
      IncDecOperator operator,
      _) {
    internalError(node, "[errorLocalFunctionPrefix] isn't implemented yet.");
  }


  void visitThisPropertyPrefix(
      Send node,
      IncDecOperator operator,
      Selector getterSelector,
      Selector setterSelector,
      _) {
    internalError(node, "[visitThisPropertyPrefix] isn't implemented yet.");
  }

  void visitStaticFieldPrefix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    internalError(node, "[visitStaticFieldPrefix] isn't implemented yet.");
  }

  void visitStaticGetterSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitStaticGetterSetterPrefix] isn't implemented yet.");
  }


  void visitStaticMethodSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitStaticMethodSetterPrefix] isn't implemented yet.");
  }

  void visitTopLevelFieldPrefix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    internalError(node, "[visitTopLevelFieldPrefix] isn't implemented yet.");
  }

  void visitTopLevelGetterSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitTopLevelGetterSetterPrefix] isn't implemented yet.");
  }

  void visitTopLevelMethodSetterPrefix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitTopLevelMethodSetterPrefix] isn't implemented yet.");
  }

  void visitSuperFieldPrefix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    internalError(node, "[visitSuperFieldPrefix] isn't implemented yet.");
  }

  void visitSuperFieldFieldPrefix(
      Send node,
      FieldElement readField,
      FieldElement writtenField,
      IncDecOperator operator,
      _) {
    internalError(node, "[visitSuperFieldFieldPrefix] isn't implemented yet.");
  }

  void visitSuperFieldSetterPrefix(
      Send node,
      FieldElement field,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    internalError(node, "[visitSuperFieldSetterPrefix] isn't implemented yet.");
  }


  void visitSuperGetterSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitSuperGetterSetterPrefix] isn't implemented yet.");
  }

  void visitSuperGetterFieldPrefix(
      Send node,
      FunctionElement getter,
      FieldElement field,
      IncDecOperator operator,
      _) {
    internalError(node, "[visitSuperGetterFieldPrefix] isn't implemented yet.");
  }

  void visitSuperMethodSetterPrefix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitSuperMethodSetterPrefix] isn't implemented yet.");
  }

  void visitClassTypeLiteralPrefix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _) {
    internalError(node, "[visitClassTypeLiteralPrefix] isn't implemented yet.");
  }

  void visitTypedefTypeLiteralPrefix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitTypedefTypeLiteralPrefix] isn't implemented yet.");
  }

  void visitTypeVariableTypeLiteralPrefix(
      Send node,
      TypeVariableElement element,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitTypeVariableTypeLiteralPrefix] isn't implemented yet.");
  }

  void visitDynamicTypeLiteralPrefix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitDynamicTypeLiteralPrefix] isn't implemented yet.");
  }

  void visitDynamicPropertyPostfix(
      Send node,
      Node receiver,
      IncDecOperator operator,
      Selector getterSelector,
      Selector setterSelector,
      _) {
    internalError(node, "[visitDynamicPropertyPostfix] isn't implemented yet.");
  }

  void visitParameterPostfix(
      Send node,
      ParameterElement parameter,
      IncDecOperator operator,
      _) {
    internalError(node, "[visitParameterPostfix] isn't implemented yet.");
  }

  void errorLocalFunctionPostfix(
      Send node,
      LocalFunctionElement function,
      IncDecOperator operator,
      _) {
    internalError(node, "[errorLocalFunctionPostfix] isn't implemented yet.");
  }


  void visitThisPropertyPostfix(
      Send node,
      IncDecOperator operator,
      Selector getterSelector,
      Selector setterSelector,
      _) {
    internalError(node, "[visitThisPropertyPostfix] isn't implemented yet.");
  }

  void visitStaticFieldPostfix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    internalError(node, "[visitStaticFieldPostfix] isn't implemented yet.");
  }

  void visitStaticGetterSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitStaticGetterSetterPostfix] isn't implemented yet.");
  }


  void visitStaticMethodSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitStaticMethodSetterPostfix] isn't implemented yet.");
  }

  void visitTopLevelFieldPostfix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    internalError(node, "[visitTopLevelFieldPostfix] isn't implemented yet.");
  }

  void visitTopLevelGetterSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitTopLevelGetterSetterPostfix] isn't implemented yet.");
  }

  void visitTopLevelMethodSetterPostfix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitTopLevelMethodSetterPostfix] isn't implemented yet.");
  }

  void visitSuperFieldPostfix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    internalError(node, "[visitSuperFieldPostfix] isn't implemented yet.");
  }

  void visitSuperFieldFieldPostfix(
      Send node,
      FieldElement readField,
      FieldElement writtenField,
      IncDecOperator operator,
      _) {
    internalError(node, "[visitSuperFieldFieldPostfix] isn't implemented yet.");
  }

  void visitSuperFieldSetterPostfix(
      Send node,
      FieldElement field,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitSuperFieldSetterPostfix] isn't implemented yet.");
  }


  void visitSuperGetterSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitSuperGetterSetterPostfix] isn't implemented yet.");
  }

  void visitSuperGetterFieldPostfix(
      Send node,
      FunctionElement getter,
      FieldElement field,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitSuperGetterFieldPostfix] isn't implemented yet.");
  }

  void visitSuperMethodSetterPostfix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitSuperMethodSetterPostfix] isn't implemented yet.");
  }

  void visitClassTypeLiteralPostfix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitClassTypeLiteralPostfix] isn't implemented yet.");
  }

  void visitTypedefTypeLiteralPostfix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitTypedefTypeLiteralPostfix] isn't implemented yet.");
  }

  void visitTypeVariableTypeLiteralPostfix(
      Send node,
      TypeVariableElement element,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitTypeVariableTypeLiteralPostfix] isn't implemented yet.");
  }

  void visitDynamicTypeLiteralPostfix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _) {
    internalError(
        node, "[visitDynamicTypeLiteralPostfix] isn't implemented yet.");
  }

  void visitConstantGet(
      Send node,
      ConstantExpression constant,
      _) {
    internalError(node, "[visitConstantGet] isn't implemented yet.");
  }

  void visitConstantInvoke(
      Send node,
      ConstantExpression constant,
      NodeList arguments,
      Selector selector,
      _) {
    internalError(node, "[visitConstantInvoke] isn't implemented yet.");
  }

  void errorUnresolvedGet(
      Send node,
      Element element,
      _) {
    internalError(node, "[errorUnresolvedGet] isn't implemented yet.");
  }

  void errorUnresolvedSet(
      Send node,
      Element element,
      Node rhs,
      _) {
    internalError(node, "[errorUnresolvedSet] isn't implemented yet.");
  }

  void errorUnresolvedCompound(
      Send node,
      Element element,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(node, "[errorUnresolvedCompound] isn't implemented yet.");
  }

  void errorUnresolvedPrefix(
      Send node,
      Element element,
      IncDecOperator operator,
      _) {
    internalError(node, "[errorUnresolvedPrefix] isn't implemented yet.");
  }

  void errorUnresolvedPostfix(
      Send node,
      Element element,
      IncDecOperator operator,
      _) {
    internalError(node, "[errorUnresolvedPostfix] isn't implemented yet.");
  }

  void errorUnresolvedSuperIndexSet(
      Send node,
      Element element,
      Node index,
      Node rhs,
      _) {
    internalError(
        node, "[errorUnresolvedSuperIndexSet] isn't implemented yet.");
  }

  void errorUnresolvedSuperCompoundIndexSet(
      Send node,
      Element element,
      Node index,
      AssignmentOperator operator,
      Node rhs,
      _) {
    internalError(
        node, "[errorUnresolvedSuperCompoundIndexSet] isn't implemented yet.");
  }

  void errorUnresolvedSuperUnary(
      Send node,
      UnaryOperator operator,
      Element element,
      _) {
    internalError(node, "[errorUnresolvedSuperUnary] isn't implemented yet.");
  }

  void errorUnresolvedSuperBinary(
      Send node,
      Element element,
      BinaryOperator operator,
      Node argument,
      _) {
    internalError(node, "[errorUnresolvedSuperBinary] isn't implemented yet.");
  }

  void errorUndefinedUnaryExpression(
      Send node,
      Operator operator,
      Node expression,
      _) {
    internalError(
        node, "[errorUndefinedUnaryExpression] isn't implemented yet.");
  }

  void errorUndefinedBinaryExpression(
      Send node,
      Node left,
      Operator operator,
      Node right,
      _) {
    internalError(
        node, "[errorUndefinedBinaryExpression] isn't implemented yet.");
  }
}
