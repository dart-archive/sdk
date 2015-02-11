// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_backend;

import 'package:compiler/src/dart2jslib.dart' show
    Backend,
    BackendConstantEnvironment,
    CodegenWorkItem,
    ConstantCompilerTask,
    ConstantSystem,
    MessageKind,
    Registry,
    ResolutionEnqueuer;

import '../bytecodes.dart' show Bytecode;

import 'fletch_context.dart';

class FletchBackend extends Backend {
  final FletchContext context;

  FletchBackend(FletchCompiler compiler)
      : this.context = compiler.context,
        super(compiler) {
    context.resolutionCallbacks = new FletchResolutionCallbacks(context);
  }

  FletchResolutionCallbacks get resolutionCallbacks {
    return context.resolutionCallbacks;
  }

  List<CompilerTask> get tasks => <CompilerTask>[];

  ConstantSystem get constantSystem {
    throw new UnsupportedError("get constantSystem");
  }

  BackendConstantEnvironment get constants {
    throw new UnsupportedError("get constants");
  }

  ConstantCompilerTask get constantCompilerTask {
    throw new UnsupportedError("get constantCompilerTask");
  }

  void enqueueHelpers(
      ResolutionEnqueuer world,
      Registry registry) {
  }

  void codegen(CodegenWorkItem work) {
  }

  bool get canHandleCompilationFailed => true;

  int assembleProgram() {
    compiler.reportHint(
        compiler.mainFunction,
        MessageKind.GENERIC,
        {'text': 'Compiling ${compiler.mainFunction.name}'});

    BytecodeBuilder builder =
        new BytecodeBuilder(context, compiler.mainFunction);
    compiler.mainFunction.node.accept(builder);
    print("Constants");
    builder.constants.forEach((constant, int index) {
      print("  #$index: $constant");
    });

    print("Bytecodes:");
    int offset = 0;
    for (Bytecode bytecode in builder.bytecodes) {
      print("  $offset: $bytecode");
      offset += bytecode.size;
    }
  }
}
