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

  void visitDynamicPropertyPrefix(
      Send node,
      Node receiver,
      IncDecOperator operator,
      Selector getterSelector,
      Selector setterSelector,
      _) {
    node.visitChildren(this);
  }

  void visitDynamicPropertyPostfix(
      Send node,
      Node receiver,
      IncDecOperator operator,
      Selector getterSelector,
      Selector setterSelector,
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
    node.visitChildren(this);
  }

  void errorFinalLocalVariableSet(
      SendSet node,
      LocalVariableElement variable,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void errorLocalFunctionSet(
      SendSet node,
      LocalFunctionElement function,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitThisInvoke(
      Send node,
      NodeList arguments,
      Selector selector,
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
      Selector selector,
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

  void errorSuperMethodSet(
      Send node,
      MethodElement method,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitSuperGetterGet(
      Send node,
      FunctionElement getter,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void errorSuperSetterGet(
      Send node,
      FunctionElement setter,
      _) {
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

  void errorSuperGetterSet(
      SendSet node,
      FunctionElement getter,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitSuperGetterInvoke(
      Send node,
      FunctionElement getter,
      NodeList arguments,
      Selector selector,
      _) {
    markThisUsed();
    node.visitChildren(this);
  }

  void errorSuperSetterInvoke(
      Send node,
      FunctionElement setter,
      NodeList arguments,
      Selector selector,
      _) {
    node.visitChildren(this);
  }

  void errorFinalStaticFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitStaticFieldInvoke(
      Send node,
      FieldElement field,
      NodeList arguments,
      Selector selector,
      _) {
    node.visitChildren(this);
  }

  void visitStaticFunctionGet(
      Send node,
      MethodElement function,
      _) {
    node.visitChildren(this);
  }

  void errorStaticFunctionSet(
      Send node,
      MethodElement function,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitStaticGetterGet(
      Send node,
      FunctionElement getter,
      _) {
    node.visitChildren(this);
  }

  void errorStaticSetterGet(
      Send node,
      FunctionElement setter,
      _) {
    node.visitChildren(this);
  }

  void visitStaticSetterSet(
      SendSet node,
      FunctionElement setter,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void errorStaticGetterSet(
      SendSet node,
      FunctionElement getter,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitStaticGetterInvoke(
      Send node,
      FunctionElement getter,
      NodeList arguments,
      Selector selector,
      _) {
    node.visitChildren(this);
  }

  void errorStaticSetterInvoke(
      Send node,
      FunctionElement setter,
      NodeList arguments,
      Selector selector,
      _) {
    node.visitChildren(this);
  }

  void errorFinalTopLevelFieldSet(
      SendSet node,
      FieldElement field,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitTopLevelFunctionGet(
      Send node,
      MethodElement function,
      _) {
    node.visitChildren(this);
  }

  void errorTopLevelFunctionSet(
      Send node,
      MethodElement function,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitTopLevelGetterGet(
      Send node,
      FunctionElement getter,
      _) {
    node.visitChildren(this);
  }

  void errorTopLevelSetterGet(
      Send node,
      FunctionElement setter,
      _) {
    node.visitChildren(this);
  }

  void visitTopLevelSetterSet(
      SendSet node,
      FunctionElement setter,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void errorTopLevelGetterSet(
      SendSet node,
      FunctionElement getter,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitTopLevelGetterInvoke(
      Send node,
      FunctionElement getter,
      NodeList arguments,
      Selector selector,
      _) {
    node.visitChildren(this);
  }

  void errorTopLevelSetterInvoke(
      Send node,
      FunctionElement setter,
      NodeList arguments,
      Selector selector,
      _) {
    node.visitChildren(this);
  }

  void visitClassTypeLiteralGet(
      Send node,
      TypeConstantExpression constant,
      _) {
    node.visitChildren(this);
  }

  void visitClassTypeLiteralInvoke(
      Send node,
      TypeConstantExpression constant,
      NodeList arguments,
      Selector selector,
      _) {
    node.visitChildren(this);
  }

  void errorClassTypeLiteralSet(
      SendSet node,
      TypeConstantExpression constant,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitTypedefTypeLiteralGet(
      Send node,
      TypeConstantExpression constant,
      _) {
    node.visitChildren(this);
  }

  void visitTypedefTypeLiteralInvoke(
      Send node,
      TypeConstantExpression constant,
      NodeList arguments,
      Selector selector,
      _) {
    node.visitChildren(this);
  }

  void errorTypedefTypeLiteralSet(
      SendSet node,
      TypeConstantExpression constant,
      Node rhs,
      _) {
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
      Selector selector,
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

  void visitDynamicTypeLiteralGet(
      Send node,
      TypeConstantExpression constant,
      _) {
    node.visitChildren(this);
  }

  void visitDynamicTypeLiteralInvoke(
      Send node,
      TypeConstantExpression constant,
      NodeList arguments,
      Selector selector,
      _) {
    node.visitChildren(this);
  }

  void errorDynamicTypeLiteralSet(
      SendSet node,
      TypeConstantExpression constant,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void errorInvalidAssert(
      Send node,
      NodeList arguments,
      _) {
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

  void visitDynamicPropertyCompound(
      Send node,
      Node receiver,
      AssignmentOperator operator,
      Node rhs,
      Selector getterSelector,
      Selector setterSelector,
      _) {
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

  void errorFinalParameterCompound(
      Send node,
      ParameterElement parameter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void errorFinalLocalVariableCompound(
      Send node,
      LocalVariableElement variable,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void errorLocalFunctionCompound(
      Send node,
      LocalFunctionElement function,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitStaticFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void errorFinalStaticFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitStaticGetterSetterCompound(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitStaticMethodSetterCompound(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitTopLevelFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void errorFinalTopLevelFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitTopLevelGetterSetterCompound(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitTopLevelMethodSetterCompound(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      AssignmentOperator operator,
      Node rhs,
      _) {
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

  void errorFinalSuperFieldCompound(
      Send node,
      FieldElement field,
      AssignmentOperator operator,
      Node rhs,
      _) {
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

  void visitClassTypeLiteralCompound(
      Send node,
      TypeConstantExpression constant,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitTypedefTypeLiteralCompound(
      Send node,
      TypeConstantExpression constant,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitTypeVariableTypeLiteralCompound(
      Send node,
      TypeVariableElement element,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitDynamicTypeLiteralCompound(
      Send node,
      TypeConstantExpression constant,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void visitCompoundIndexSet(
      Send node,
      Node receiver,
      Node index,
      AssignmentOperator operator,
      Node rhs,
      _) {
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

  void errorLocalFunctionPrefix(
      Send node,
      LocalFunctionElement function,
      IncDecOperator operator,
      _) {
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

  void visitStaticFieldPrefix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    node.visitChildren(this);
  }

  void visitStaticGetterSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    node.visitChildren(this);
  }


  void visitStaticMethodSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    node.visitChildren(this);
  }

  void visitTopLevelFieldPrefix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    node.visitChildren(this);
  }

  void visitTopLevelGetterSetterPrefix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    node.visitChildren(this);
  }

  void visitTopLevelMethodSetterPrefix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
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

  void visitClassTypeLiteralPrefix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _) {
    node.visitChildren(this);
  }

  void visitTypedefTypeLiteralPrefix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _) {
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

  void visitDynamicTypeLiteralPrefix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _) {
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

  void errorLocalFunctionPostfix(
      Send node,
      LocalFunctionElement function,
      IncDecOperator operator,
      _) {
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

  void visitStaticFieldPostfix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    node.visitChildren(this);
  }

  void visitStaticGetterSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    node.visitChildren(this);
  }


  void visitStaticMethodSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    node.visitChildren(this);
  }

  void visitTopLevelFieldPostfix(
      Send node,
      FieldElement field,
      IncDecOperator operator,
      _) {
    node.visitChildren(this);
  }

  void visitTopLevelGetterSetterPostfix(
      Send node,
      FunctionElement getter,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
    node.visitChildren(this);
  }

  void visitTopLevelMethodSetterPostfix(
      Send node,
      FunctionElement method,
      FunctionElement setter,
      IncDecOperator operator,
      _) {
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

  void visitClassTypeLiteralPostfix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _) {
    node.visitChildren(this);
  }

  void visitTypedefTypeLiteralPostfix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _) {
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

  void visitDynamicTypeLiteralPostfix(
      Send node,
      TypeConstantExpression constant,
      IncDecOperator operator,
      _) {
    node.visitChildren(this);
  }

  void visitConstantGet(
      Send node,
      ConstantExpression constant,
      _) {
    node.visitChildren(this);
  }

  void visitConstantInvoke(
      Send node,
      ConstantExpression constant,
      NodeList arguments,
      Selector selector,
      _) {
    node.visitChildren(this);
  }

  void errorUnresolvedGet(
      Send node,
      Element element,
      _) {
    node.visitChildren(this);
  }

  void errorUnresolvedSet(
      Send node,
      Element element,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void errorUnresolvedCompound(
      Send node,
      Element element,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void errorUnresolvedPrefix(
      Send node,
      Element element,
      IncDecOperator operator,
      _) {
    node.visitChildren(this);
  }

  void errorUnresolvedPostfix(
      Send node,
      Element element,
      IncDecOperator operator,
      _) {
    node.visitChildren(this);
  }

  void errorUnresolvedSuperIndexSet(
      Send node,
      Element element,
      Node index,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void errorUnresolvedSuperCompoundIndexSet(
      Send node,
      Element element,
      Node index,
      AssignmentOperator operator,
      Node rhs,
      _) {
    node.visitChildren(this);
  }

  void errorUnresolvedSuperUnary(
      Send node,
      UnaryOperator operator,
      Element element,
      _) {
    node.visitChildren(this);
  }

  void errorUnresolvedSuperBinary(
      Send node,
      Element element,
      BinaryOperator operator,
      Node argument,
      _) {
    node.visitChildren(this);
  }

  void errorUndefinedUnaryExpression(
      Send node,
      Operator operator,
      Node expression,
      _) {
    node.visitChildren(this);
  }

  void errorUndefinedBinaryExpression(
      Send node,
      Node left,
      Operator operator,
      Node right,
      _) {
    node.visitChildren(this);
  }
}
