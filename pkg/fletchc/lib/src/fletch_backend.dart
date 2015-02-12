// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_backend;

import 'package:compiler/src/dart2jslib.dart' show
    Backend,
    BackendConstantEnvironment,
    CodegenWorkItem,
    CompilerTask,
    ConstantCompilerTask,
    ConstantSystem,
    MessageKind,
    Registry,
    ResolutionEnqueuer;

import 'package:compiler/src/elements/elements.dart' show
    Element,
    ClassElement,
    FunctionElement;

import 'package:compiler/src/dart_backend/dart_backend.dart' show
    DartConstantTask;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue;

import '../bytecodes.dart' show
    Bytecode,
    InvokeNative;

import 'fletch_context.dart';
import 'function_compiler.dart';

class FletchBackend extends Backend {
  final FletchContext context;

  final DartConstantTask constantCompilerTask;

  FletchBackend(FletchCompiler compiler)
      : this.context = compiler.context,
        this.constantCompilerTask = new DartConstantTask(compiler),
        super(compiler) {
    context.resolutionCallbacks = new FletchResolutionCallbacks(context);
  }

  FletchResolutionCallbacks get resolutionCallbacks {
    return context.resolutionCallbacks;
  }

  List<CompilerTask> get tasks => <CompilerTask>[];

  ConstantSystem get constantSystem {
    return constantCompilerTask.constantCompiler.constantSystem;
  }

  BackendConstantEnvironment get constants => constantCompilerTask;

  bool classNeedsRti(ClassElement cls) => false;

  bool methodNeedsRti(FunctionElement function) => false;

  void enqueueHelpers(
      ResolutionEnqueuer world,
      Registry registry) {
  }

  void codegen(CodegenWorkItem work) {
    compiler.reportHint(
        work.element,
        MessageKind.GENERIC,
        {'text': 'Compiling ${work.element.name}'});

    if (isNative(work.element)) {
      return codegenNative(work);
    }

    FunctionCompiler functionCompiler =
        new FunctionCompiler(context, work.resolutionTree, work.registry);
    functionCompiler.compileFunction(work.element.node);

    print("Constants");
    functionCompiler.constants.forEach((constant, int index) {
      if (constant is ConstantValue) {
        constant = constant.toStructuredString();
      }
      print("  #$index: $constant");
    });

    print("Bytecodes:");
    int offset = 0;
    for (Bytecode bytecode in functionCompiler.builder.bytecodes) {
      print("  $offset: $bytecode");
      offset += bytecode.size;
    }
  }

  void codegenNative(CodegenWorkItem work) {
    // TODO(ahe): A native function can have a body which is considered an
    // exception handler. That body should also be compiled.
    Bytecode bytecode = natives[work.element.name];
    print("  0: $bytecode");
  }

  bool isNative(Element element) {
    if (element is FunctionElement) {
      if (element.hasNode) {
        return
            identical('native', element.node.body.getBeginToken().stringValue);
      }
    }
    return false;
  }

  bool get canHandleCompilationFailed => true;

  int assembleProgram() {
    // TODO(ahe): This would be a good place to send code to the VM.
    return 0;
  }
}

const Map<String, InvokeNative> natives = const <String, InvokeNative>{
  "_printString": const InvokeNative(1, 0),
  "_halt": const InvokeNative(1, 1),
};

