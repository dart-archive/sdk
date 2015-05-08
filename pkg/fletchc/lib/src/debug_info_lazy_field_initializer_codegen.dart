// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.debug_info_lazy_field_initializer_codegen;

import 'package:compiler/src/dart2jslib.dart' show
    MessageKind,
    Registry;

import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/resolution/resolution.dart';
import 'package:compiler/src/tree/tree.dart';
import 'package:compiler/src/universe/universe.dart';

import 'fletch_context.dart';

import 'compiled_function.dart' show
    CompiledFunction;

import 'closure_environment.dart';
import 'codegen_visitor.dart';
import 'lazy_field_initializer_codegen.dart';

class DebugInfoLazyFieldInitializerCodegen
    extends LazyFieldInitializerCodegen {
  final FletchCompiler compiler;

  // Regenerate the bytecode in a fresh buffer separately from the compiled
  // function. If we did not create a separate buffer, the bytecode would
  // be appended to the compiled function builder and we would get a compiled
  // function with incorrect bytecode.
  final BytecodeBuilder debugBuilder;

  DebugInfoLazyFieldInitializerCodegen(CompiledFunction compiledFunction,
                                       FletchContext context,
                                       TreeElements elements,
                                       Registry registry,
                                       ClosureEnvironment closureEnvironment,
                                       FieldElement field,
                                       this.compiler)
      : debugBuilder = new BytecodeBuilder(compiledFunction.arity),
        super(compiledFunction, context, elements, registry,
              closureEnvironment, field);

  BytecodeBuilder get builder => debugBuilder;

  void recordDebugInfo(Node node) {
    compiledFunction.debugInfo.addLocation(compiler, builder.byteSize, node);
  }

  void pushVariableDeclaration(LocalValue value) {
    super.pushVariableDeclaration(value);
    compiledFunction.debugInfo.pushScope(builder.byteSize, value);
  }

  void popVariableDeclaration(Element element) {
    super.popVariableDeclaration(element);
    compiledFunction.debugInfo.popScope(builder.byteSize);
  }

  void registerDynamicInvocation(Selector selector) { }
  void registerDynamicGetter(Selector selector) { }
  void registerDynamicSetter(Selector selector) { }
  void registerStaticInvocation(FunctionElement function) { }
  void registerInstantiatedClass(ClassElement klass) { }

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
