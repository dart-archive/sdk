// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.expression_visitor;

import 'package:semantic_visitor/semantic_visitor.dart' show
    SemanticVisitor;

import 'package:compiler/src/constants/expressions.dart' show
    ConstantExpression;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue;

import 'package:compiler/src/dart2jslib.dart' show
    Registry;

import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/resolution/resolution.dart';
import 'package:compiler/src/tree/tree.dart';
import 'package:compiler/src/universe/universe.dart';
import 'package:compiler/src/util/util.dart' show Spannable;
import 'package:compiler/src/dart_types.dart';

import 'fletch_context.dart';

import 'fletch_function_constant.dart' show
    FletchFunctionConstant;

class FunctionCompiler extends SemanticVisitor {
  final FletchContext context;

  final Registry registry;

  final BytecodeBuilder builder = new BytecodeBuilder();

  final Map<ConstantValue, int> constants = <ConstantValue, int>{};

  final Map<Element, ConstantValue> functionConstantValues =
      <Element, ConstantValue>{};

  FunctionCompiler(this.context, TreeElements elements, this.registry)
      : super(elements);

  ConstantExpression compileConstant(Node node, {bool isConst}) {
    return context.compileConstant(node, elements, isConst: isConst);
  }

  void compileFunction(FunctionExpression node) {
    node.body.accept(this);

    // Emit implicit return if none is present.
    if (!builder.endsWithReturn) {
      builder.loadLiteralNull();
      builder.ret();
    }

    builder.methodEnd();
  }

  int allocateConstant(ConstantValue constant) {
    return constants.putIfAbsent(constant, () => constants.length);
  }

  int allocateConstantFromFunction(FunctionElement function) {
    FletchFunctionConstant constant =
        functionConstantValues.putIfAbsent(
            function, () => new FletchFunctionConstant(function));
    return allocateConstant(constant);
  }

  int allocateConstantFromNode(Node node) {
    ConstantExpression expression = compileConstant(node, isConst: false);
    return allocateConstant(expression.value);
  }

  // Visit the expression [node] with the result pushed on top of the stack.
  void visitForValue(Node node) {
    node.accept(this);
  }

  // Visit the expression [node] without the result pushed on top of the stack.
  void visitForEffect(Node node) {
    node.accept(this);
    builder.pop();
  }

  // Visit the expression [node] with the result being a branch to either
  // [trueLabel] or [falseLabel].
  void visitForTest(Node node, trueLabel, falseLabel) {
    internalError(node, "[visitForTest] isn't implemented.");
  }

  void visitStaticMethodInvocation(
      Send node,
      /* MethodElement */ element,
      NodeList arguments,
      Selector selector) {
    visitForValue(arguments);
    registry.registerStaticInvocation(element);
    builder.invokeStatic(
        allocateConstantFromFunction(element),
        arguments.slowLength());
  }

  void visitLiteral(Literal node) {
    builder.loadConst(allocateConstantFromNode(node));
  }

  void visitLiteralString(LiteralString node) {
    builder.loadConst(allocateConstantFromNode(node));
  }

  void visitBlock(Block node) {
    node.visitChildren(this);
  }

  void visitNodeList(NodeList node) {
    node.visitChildren(this);
  }

  void visitExpressionStatement(ExpressionStatement node) {
    visitForEffect(node.expression);
  }

  void visitFunctionExpression(FunctionExpression node) {
    internalError(
        node, "[visitFunctionExpression] isn't implemented.");
  }

  void visitParameterAccess(
      Send node,
      ParameterElement element) {
    internalError(
        node, "[visitParameterAccess] isn't implemented.");
  }

  void visitParameterAssignment(
      SendSet node,
      ParameterElement element,
      Node rhs) {
    internalError(
        node, "[visitParameterAssignment] isn't implemented.");
  }

  void visitParameterInvocation(
      Send node,
      ParameterElement element,
      NodeList arguments,
      Selector selector) {
    internalError(
        node, "[visitParameterInvocation] isn't implemented.");
  }

  void visitLocalVariableAccess(
      Send node,
      LocalVariableElement element) {
    internalError(
        node, "[visitLocalVariableAccess] isn't implemented.");
  }

  void visitLocalVariableAssignment(
      SendSet node,
      LocalVariableElement element,
      Node rhs) {
    internalError(
        node, "[visitLocalVariableAssignment] isn't implemented.");
  }

  void visitLocalVariableInvocation(
      Send node,
      LocalVariableElement element,
      NodeList arguments,
      Selector selector) {
    internalError(
        node, "[visitLocalVariableInvocation] isn't implemented.");
  }

  void visitLocalFunctionAccess(
      Send node,
      LocalFunctionElement element) {
    internalError(
        node, "[visitLocalFunctionAccess] isn't implemented.");
  }

  void visitLocalFunctionAssignment(
      SendSet node,
      LocalFunctionElement element,
      Node rhs,
      Selector selector) {
    internalError(
        node, "[visitLocalFunctionAssignment] isn't implemented.");
  }

  void visitLocalFunctionInvocation(
      Send node,
      LocalFunctionElement element,
      NodeList arguments,
      Selector selector) {
    internalError(
        node, "[visitLocalFunctionInvocation] isn't implemented.");
  }

  void visitDynamicAccess(
      Send node,
      Selector selector) {
    internalError(
        node, "[visitDynamicAccess] isn't implemented.");
  }

  void visitDynamicAssignment(
      SendSet node,
      Selector selector,
      Node rhs) {
    internalError(
        node, "[visitDynamicAssignment] isn't implemented.");
  }

  void visitDynamicInvocation(
      Send node,
      NodeList arguments,
      Selector selector) {
    internalError(
        node, "[visitDynamicInvocation] isn't implemented.");
  }

  void visitStaticFieldAccess(
      Send node,
      FieldElement element) {
    internalError(
        node, "[visitStaticFieldAccess] isn't implemented.");
  }

  void visitStaticFieldAssignment(
      SendSet node,
      FieldElement element,
      Node rhs) {
    internalError(
        node, "[visitStaticFieldAssignment] isn't implemented.");
  }

  void visitStaticFieldInvocation(
      Send node,
      FieldElement element,
      NodeList arguments,
      Selector selector) {
    internalError(
        node, "[visitStaticFieldInvocation] isn't implemented.");
  }

  void visitStaticMethodAccess(
      Send node,
      MethodElement element) {
    internalError(
        node, "[visitStaticMethodAccess] isn't implemented.");
  }

  void visitStaticPropertyAccess(
      Send node,
      FunctionElement element) {
    internalError(
        node, "[visitStaticPropertyAccess] isn't implemented.");
  }

  void visitStaticPropertyAssignment(
      SendSet node,
      FunctionElement element,
      Node rhs) {
    internalError(
        node, "[visitStaticPropertyAssignment] isn't implemented.");
  }

  void visitStaticPropertyInvocation(
      Send node,
      FieldElement element,
      NodeList arguments,
      Selector selector) {
    internalError(
        node, "[visitStaticPropertyInvocation] isn't implemented.");
  }

  void visitTopLevelFieldAccess(
      Send node,
      FieldElement element) {
    internalError(
        node, "[visitTopLevelFieldAccess] isn't implemented.");
  }

  void visitTopLevelFieldAssignment(
      SendSet node,
      FieldElement element,
      Node rhs) {
    internalError(
        node, "[visitTopLevelFieldAssignment] isn't implemented.");
  }

  void visitTopLevelFieldInvocation(
      Send node,
      FieldElement element,
      NodeList arguments,
      Selector selector) {
    internalError(
        node, "[visitTopLevelFieldInvocation] isn't implemented.");
  }

  void visitTopLevelMethodAccess(
      Send node,
      MethodElement element) {
    internalError(
        node, "[visitTopLevelMethodAccess] isn't implemented.");
  }

  void visitTopLevelMethodInvocation(
      Send node,
      MethodElement element,
      NodeList arguments,
      Selector selector) {
    internalError(
        node, "[visitTopLevelMethodInvocation] isn't implemented.");
  }

  void visitTopLevelPropertyAccess(
      Send node,
      FunctionElement element) {
    internalError(
        node, "[visitTopLevelPropertyAccess] isn't implemented.");
  }

  void visitTopLevelPropertyAssignment(
      SendSet node,
      FunctionElement element,
      Node rhs) {
    internalError(
        node, "[visitTopLevelPropertyAssignment] isn't implemented.");
  }

  void visitTopLevelPropertyInvocation(
      Send node,
      FieldElement element,
      NodeList arguments,
      Selector selector) {
    internalError(
        node, "[visitTopLevelPropertyInvocation] isn't implemented.");
  }

  void visitClassTypeLiteralAccess(
      Send node,
      ClassElement element) {
    internalError(
        node, "[visitClassTypeLiteralAccess] isn't implemented.");
  }

  void visitClassTypeLiteralInvocation(
      Send node,
      ClassElement element,
      NodeList arguments,
      Selector selector) {
    internalError(
        node, "[visitClassTypeLiteralInvocation] isn't implemented.");
  }

  void visitClassTypeLiteralAssignment(
      SendSet node,
      ClassElement element,
      Node rhs) {
    internalError(
        node, "[visitClassTypeLiteralAssignment] isn't implemented.");
  }

  void visitTypedefTypeLiteralAccess(
      Send node,
      TypedefElement element) {
    internalError(
        node, "[visitTypedefTypeLiteralAccess] isn't implemented.");
  }

  void visitTypedefTypeLiteralInvocation(
      Send node,
      TypedefElement element,
      NodeList arguments,
      Selector selector) {
    internalError(
        node, "[visitTypedefTypeLiteralInvocation] isn't implemented.");
  }

  void visitTypedefTypeLiteralAssignment(
      SendSet node,
      TypedefElement element,
      Node rhs) {
    internalError(
        node, "[visitTypedefTypeLiteralAssignment] isn't implemented.");
  }

  void visitTypeVariableTypeLiteralAccess(
      Send node,
      TypeVariableElement element) {
    internalError(
        node, "[visitTypeVariableTypeLiteralAccess] isn't implemented.");
  }

  void visitTypeVariableTypeLiteralInvocation(
      Send node,
      TypeVariableElement element,
      NodeList arguments,
      Selector selector) {
    internalError(
        node, "[visitTypeVariableTypeLiteralInvocation] isn't implemented.");
  }

  void visitTypeVariableTypeLiteralAssignment(
      SendSet node,
      TypeVariableElement element,
      Node rhs) {
    internalError(
        node, "[visitTypeVariableTypeLiteralAssignment] isn't implemented.");
  }

  void visitDynamicTypeLiteralAccess(
      Send node) {
    internalError(
        node, "[visitDynamicTypeLiteralAccess] isn't implemented.");
  }

  void visitAssert(
      Send node,
      Node expression) {
    internalError(
        node, "[visitAssert] isn't implemented.");
  }

  void internalError(Spannable spannable, String reason) {
    context.compiler.internalError(spannable, reason);
  }
}
