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

import 'bytecode_builder.dart';
import 'closure_environment.dart';

import 'compiled_function.dart' show
    CompiledFunction;

import 'fletch_context.dart';
import 'function_codegen.dart';

class DebugInfoFunctionCodegen extends FunctionCodegen {
  final FletchCompiler compiler;

  // Regenerate the bytecode in a fresh buffer separately from the compiled
  // function. If we did not create a separate buffer, the bytecode would
  // be appended to the compiled function builder and we would get a compiled
  // function with incorrect bytecode.
  BytecodeBuilder builder;

  DebugInfoFunctionCodegen(CompiledFunction compiledFunction,
                           FletchContext context,
                           TreeElements elements,
                           Registry registry,
                           ClosureEnvironment closureEnvironment,
                           FunctionElement function,
                           this.compiler)
      : super(compiledFunction, context, elements, registry,
              closureEnvironment, function) {
    builder = new BytecodeBuilder(super.builder.functionArity);
  }

  void recordDebugInfo(Node node) {
    compiledFunction.debugInfo.add(compiler, builder.byteSize, node);
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

  void visitForValue(Node node) {
    recordDebugInfo(node);
    super.visitForValue(node);
  }

  void visitForEffect(Node node) {
    recordDebugInfo(node);
    super.visitForEffect(node);
  }
}
