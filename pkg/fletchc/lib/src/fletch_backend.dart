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

import 'package:compiler/src/resolution/resolution.dart' show
    TreeElements;

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
    Element element = work.element;
    if (compiler.verbose) {
      compiler.reportHint(
          element, MessageKind.GENERIC, {'text': 'Compiling ${element.name}'});
    }

    if (element.isFunction) {
      codegenFunction(element, work.resolutionTree, work.registry);
    } else {
      compiler.internalError(
          element, "Uninimplemented element kind: ${element.kind}");
    }
  }

  void codegenFunction(
      FunctionElement function,
      TreeElements elements,
      Registry registry) {
    FunctionCompiler functionCompiler = new FunctionCompiler(
        context,
        elements,
        registry,
        function);

    if (isNative(function)) {
      codegenNativeFunction(function, functionCompiler);
    } else {
      functionCompiler.compile();
    }

    compiledFunctions[function] = functionCompiler;

    allocateMethodId(function);
  }

  void codegenNativeFunction(
      FunctionElement function,
      FunctionCompiler functionCompiler) {
    String name = function.name;

    FletchNativeDescriptor descriptor = context.nativeDescriptors[name];
    if (descriptor == null) {
      throw "Unsupported native function: $name";
    }

    int arity = function.functionSignature.parameterCount;
    functionCompiler.builder.invokeNative(arity, descriptor.index);

    Return returnNode = function.node.body.asReturn();
    if (returnNode != null && !returnNode.hasExpression) {
      // A native method without a body.
      functionCompiler.builder.emitThrow();
    } else {
      functionCompiler.compile();
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
