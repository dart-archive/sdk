// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.bytecode_builder;

import 'package:semantic_visitor/semantic_visitor.dart' show
    SemanticVisitor;

import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/resolution/resolution.dart';
import 'package:compiler/src/tree/tree.dart';
import 'package:compiler/src/universe/universe.dart';
import 'package:compiler/src/util/util.dart' show Spannable;
import 'package:compiler/src/dart_types.dart';

import 'fletch_context.dart';

import '../bytecodes.dart';

class BytecodeBuilder extends SemanticVisitor {
  final FletchContext context;

  final List<Bytecode> bytecodes = <Bytecode>[];

  final Map<dynamic, int> constants = <dynamic, int>{};

  BytecodeBuilder(this.context, element)
      : super(element.resolvedAst.elements);

  int allocateConstant(constant) {
    return constants.putIfAbsent(constant, () => constants.length);
  }

  void visitStaticMethodInvocation(
      Send node,
      /* MethodElement */ element,
      NodeList arguments,
      Selector selector) {
    arguments.accept(this);
    int id = allocateConstant(element);
    bytecodes.add(new InvokeStaticUnfold(id));
  }

  void visitLiteralString(LiteralString node) {
    int id = allocateConstant(node.dartString.slowToString());
    bytecodes.add(new LoadConstUnfold(id));
  }

  void visitLiteralInt(LiteralInt node) {
    int id = allocateConstant(node.value);
    bytecodes.add(new LoadConstUnfold(id));
  }

  void visitFunctionExpression(FunctionExpression node) {
    node.body.accept(this);
  }

  void visitBlock(Block node) {
    node.visitChildren(this);
  }

  void visitNodeList(NodeList node) {
    node.visitChildren(this);
  }

  void visitExpressionStatement(ExpressionStatement node) {
    node.visitChildren(this);
    bytecodes.add(const Pop());
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
