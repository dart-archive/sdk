// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.debug_info_function_codegen;

import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/resolution/resolution.dart';
import 'package:compiler/src/tree/tree.dart';
import 'package:compiler/src/universe/universe.dart';

import 'package:compiler/src/dart2jslib.dart' show
    Registry;

import 'package:compiler/src/dart_types.dart' show
    DartType;

import 'package:compiler/src/util/util.dart' show
    Spannable;

import 'bytecode_assembler.dart';
import 'closure_environment.dart';
import 'codegen_visitor.dart';

import 'fletch_function_builder.dart' show
    FletchFunctionBuilder;

import 'fletch_registry.dart' show
    FletchRegistry;

import 'fletch_context.dart';
import 'function_codegen.dart';
import 'debug_info.dart';

class DebugInfoFunctionCodegen extends FunctionCodegen {
  final FletchCompilerImplementation compiler;
  final DebugInfo debugInfo;

  DebugInfoFunctionCodegen(this.debugInfo,
                           FletchFunctionBuilder functionBuilder,
                           FletchContext context,
                           TreeElements elements,
                           FletchRegistry registry,
                           ClosureEnvironment closureEnvironment,
                           FunctionElement function,
                           this.compiler)
      : super(functionBuilder, context, elements, registry,
              closureEnvironment, function) {
    if (functionBuilder.isInstanceMember) pushVariableDeclaration(thisValue);
  }

  void recordDebugInfo(Node node) {
    debugInfo.addLocation(compiler, assembler.byteSize, node);
  }

  void pushVariableDeclaration(LocalValue value) {
    super.pushVariableDeclaration(value);
    debugInfo.pushScope(assembler.byteSize, value);
  }

  void popVariableDeclaration(Element element) {
    super.popVariableDeclaration(element);
    debugInfo.popScope(assembler.byteSize);
  }

  void registerDynamicInvocation(Selector selector) { }
  void registerDynamicGetter(Selector selector) { }
  void registerDynamicSetter(Selector selector) { }
  void registerStaticInvocation(FunctionElement function) { }
  void registerInstantiatedClass(ClassElement klass) { }

  void callIsSelector(
      Node node,
      DartType type,
      Spannable diagnosticLocation) {
    recordDebugInfo(node);
    super.callIsSelector(node, type, diagnosticLocation);
  }

  void invokeMethod(Node node, Selector selector) {
    recordDebugInfo(node);
    super.invokeMethod(node, selector);
  }

  void invokeGetter(Node node, Selector selector) {
    recordDebugInfo(node);
    super.invokeGetter(node, selector);
  }

  void invokeSetter(Node node, Selector selector) {
    recordDebugInfo(node);
    super.invokeSetter(node, selector);
  }

  void invokeFactory(Node node, int constId, int arity) {
    recordDebugInfo(node);
    super.invokeFactory(node, constId, arity);
  }

  void invokeStatic(Node node, int constId, int arity) {
    recordDebugInfo(node);
    super.invokeStatic(node, constId, arity);
  }

  void generateReturn(Node node) {
    recordDebugInfo(node);
    super.generateReturn(node);
  }

  void generateImplicitReturn(FunctionExpression node) {
    // If the method is empty, generate debug information for the
    // implicit 'return null' that covers the entire method. That was,
    // the debugger will use the entire (empty) method as the source
    // listing is a breakpoint is set in the method.
    if (node.body is Block) {
      Block body = node.body;
      if (body.statements.isEmpty) recordDebugInfo(node);
    }
    super.generateImplicitReturn(node);
  }

  void generateSwitchCaseMatch(CaseMatch caseMatch, BytecodeLabel ifTrue) {
    // We do not want to break on the evaluation of the individual
    // case equality tests.
    recordDebugInfo(null);
    super.generateSwitchCaseMatch(caseMatch, ifTrue);
  }

  void generateIdentical(Node node) {
    recordDebugInfo(node);
    super.generateIdentical(node);
  }

  void generateIdenticalNonNumeric(Node node) {
    recordDebugInfo(node);
    super.generateIdenticalNonNumeric(node);
  }

  void visitForValue(Node node) {
    recordDebugInfo(node);
    super.visitForValue(node);
  }

  void visitForEffect(Node node) {
    recordDebugInfo(node);
    super.visitForEffect(node);
  }
}
