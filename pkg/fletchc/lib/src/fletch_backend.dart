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

import 'package:compiler/src/tree/tree.dart' show
    Return;

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


import 'fletch_function_constant.dart' show
    FletchFunctionConstant;

import 'fletch_context.dart';

import 'function_compiler.dart';

import '../commands.dart';

class FletchBackend extends Backend {
  final FletchContext context;

  final DartConstantTask constantCompilerTask;

  final Map<FunctionElement, int> methodIds = <FunctionElement, int>{};

  final Map<FunctionElement, FunctionCompiler> compiledFunctions =
      <FunctionElement, FunctionCompiler>{};

  List<Command> commands;

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
    if (compiler.verbose) {
      compiler.reportHint(
          work.element,
          MessageKind.GENERIC,
          {'text': 'Compiling ${work.element.name}'});
    }

    FunctionElement function = work.element;
    FunctionCompiler functionCompiler = new FunctionCompiler(
        context,
        work.resolutionTree,
        work.registry,
        function);

    if (isNative(work.element)) {
      codegenNative(work, functionCompiler);
    } else {
      functionCompiler.compile();
    }

    compiledFunctions[work.element] = functionCompiler;

    allocateMethodId(work.element);
  }

  void codegenNative(CodegenWorkItem work, FunctionCompiler functionCompiler) {
    FunctionElement element = work.element;
    String name = element.name;

    FletchNativeDescriptor descriptor = context.nativeDescriptors[name];
    if (descriptor == null) {
      throw "Unsupported native function: $name";
    }

    int arity = element.functionSignature.parameterCount;
    functionCompiler.builder.invokeNative(arity, descriptor.index);

    Return returnNode = element.node.body.asReturn();
    if (returnNode != null && !returnNode.hasExpression) {
      // A native method without a body.
      functionCompiler.builder.emitThrow();
    } else {
      functionCompiler.compileFunction(element.node);
    }
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
    List<Command> commands = <Command>[
        const NewMap(MapId.methods),
    ];

    List<Function> deferredActions = <Function>[];

    void pushNewFunction(
        FunctionElement function,
        FunctionCompiler functionCompiler) {
      int arity = function.functionSignature.parameterCount;
      int constantCount = functionCompiler.constants.length;
      int methodId = allocateMethodId(function);

      functionCompiler.constants.forEach((constant, int index) {
        if (constant is ConstantValue) {
          if (constant.isInt) {
            commands.add(new PushNewInteger(constant.primitiveValue));
          } else if (constant.isString) {
            commands.add(
                new PushNewString(constant.primitiveValue.slowToString()));
          } else if (constant is FletchFunctionConstant) {
            commands.add(const PushNull());
            deferredActions.add(() {
              int referredMethodId = allocateMethodId(constant.element);
              commands
                  ..add(new PushFromMap(MapId.methods, methodId))
                  ..add(new PushFromMap(MapId.methods, referredMethodId))
                  ..add(new ChangeMethodLiteral(index));
            });
          } else {
            throw "Unsupported constant: ${constant.toStructuredString()}";
          }
        } else {
          throw "Unsupported constant: ${constant.runtimeType}";
        }
      });

      commands.add(
          new PushNewFunction(
              arity, constantCount, functionCompiler.builder.bytecodes));

      commands.add(new PopToMap(MapId.methods, methodId));
    }

    compiledFunctions.forEach(pushNewFunction);

    int changes = 0;
    for (Function action in deferredActions) {
      action();
      changes++;
    }

    commands.add(const ChangeStatics(0));
    changes++;

    commands.add(new CommitChanges(changes));

    commands.add(const PushNewInteger(0));

    commands.add(
        new PushFromMap(
            MapId.methods, allocateMethodId(compiler.mainFunction)));

    commands.add(const RunMain());

    commands.add(const SessionEnd());

    this.commands = commands;

    return 0;
  }

  int allocateMethodId(FunctionElement element) {
    return methodIds.putIfAbsent(element, () => methodIds.length);
  }
}
