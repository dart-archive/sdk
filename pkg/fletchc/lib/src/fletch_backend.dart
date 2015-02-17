// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_backend;

import 'dart:async' show
    Future;

import 'package:compiler/src/dart2jslib.dart' show
    Backend,
    BackendConstantEnvironment,
    CodegenWorkItem,
    CompilerTask,
    ConstantCompilerTask,
    ConstantSystem,
    Enqueuer,
    MessageKind,
    Registry,
    ResolutionEnqueuer;

import 'package:compiler/src/tree/tree.dart' show
    Return;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    Element,
    FunctionElement,
    LibraryElement;

import 'package:compiler/src/elements/modelx.dart' show
    FunctionElementX;

import 'package:compiler/src/dart_backend/dart_backend.dart' show
    DartConstantTask;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue;

import '../bytecodes.dart' show
    InvokeNative;

import 'package:compiler/src/resolution/resolution.dart' show
    TreeElements;

import 'package:compiler/src/library_loader.dart' show
    LibraryLoader;

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
    compiler.patchAnnotationClass = patchAnnotationClass;
  }

  /// Class of annotations to mark patches in patch files.
  ///
  /// The patch parser (pkg/compiler/lib/src/patch_parser.dart). The patch
  /// parser looks for an annotation on the form "@patch", where "patch" is
  /// compile-time constant instance of [patchAnnotationClass].
  ClassElement get patchAnnotationClass {
    // TODO(ahe): Introduce a proper constant class to identify constants. For
    // now, we simply put "const patch = "patch";" in the beginning of patch
    // files.
    return stringImplementation;
  }

  void codegen(CodegenWorkItem work) {
    Element element = work.element;
    if (compiler.verbose) {
      compiler.reportHint(
          element, MessageKind.GENERIC, {'text': 'Compiling ${element.name}'});
    }

    if (element.isFunction) {
      compiler.withCurrentElement(element.implementation, () {
        codegenFunction(
            element.implementation, work.resolutionTree, work.registry);
      });
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
    } else if (isExternal(function)) {
      codegenExternalFunction(function, functionCompiler);
    } else {
      functionCompiler.compile();
    }

    compiledFunctions[function] = functionCompiler;

    allocateMethodId(function);

    if (compiler.verbose) {
      print(functionCompiler.verboseToString());
    }
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

  void codegenExternalFunction(
      FunctionElement function,
      FunctionCompiler functionCompiler) {
    if (function.name == "_yield") {
      // TODO(ajohnsen): Load argument 0 instead of literal true.
      functionCompiler.builder.loadLiteralTrue();
      functionCompiler.builder.processYield();
      functionCompiler.builder.ret();
      return;
    }
    throw "Unhandled external: $function";
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

  bool isExternal(Element element) {
    if (element is FunctionElement) return element.isExternal;
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
          } else if (constant.isTrue) {
            commands.add(new PushBoolean(true));
          } else if (constant.isFalse) {
            commands.add(new PushBoolean(false));
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

    this.commands = commands;

    return 0;
  }

  int allocateMethodId(FunctionElement element) {
    return methodIds.putIfAbsent(element, () => methodIds.length);
  }

  Future onLibraryScanned(LibraryElement library, LibraryLoader loader) {
    if (library.isPlatformLibrary && !library.isPatched) {
      // Apply patch, if any.
      Uri patchUri = compiler.resolvePatchUri(library.canonicalUri.path);
      if (patchUri != null) {
        return compiler.patchParser.patchLibrary(loader, patchUri, library);
      }
    }
  }

  /// Return non-null to enable patching. Possible return values are 'new' and
  /// 'old'. Referring to old and new emitter. Since the new emitter is the
  /// future, we assume 'old' will go away. So it seems the best option for
  /// Fletch is 'new'.
  String get patchVersion => 'new';

  FunctionElement resolveExternalFunction(FunctionElement element) {
    if (element.isPatched) {
      FunctionElementX patch = element.patch;
      compiler.withCurrentElement(patch, () {
        patch.parseNode(compiler);
        patch.computeType(compiler);
      });
      element = patch;
    } else {
      compiler.reportError(
         element, MessageKind.PATCH_EXTERNAL_WITHOUT_IMPLEMENTATION);
    }
    return element;
  }
}
