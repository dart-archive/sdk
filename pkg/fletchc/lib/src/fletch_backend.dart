// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_backend;

import 'dart:async' show
    Future;

import 'dart:collection' show
    SplayTreeMap;

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

import 'fletch_selector.dart';

import 'function_compiler.dart';

import '../commands.dart';

class CompiledClass {
  final int id;
  final ClassElement element;
  final SplayTreeMap<int, int> methodTable = new SplayTreeMap<int, int>();

  CompiledClass(this.id, this.element);
}

class FletchBackend extends Backend {
  final FletchContext context;

  final DartConstantTask constantCompilerTask;

  final Map<FunctionElement, int> methodIds = <FunctionElement, int>{};

  final Map<FunctionElement, FunctionCompiler> compiledFunctions =
      <FunctionElement, FunctionCompiler>{};

  final Set<FunctionElement> externals = new Set<FunctionElement>();

  final Map<ClassElement, int> classIds = <ClassElement, int>{};

  final Map<ClassElement, CompiledClass> compiledClasses =
      <ClassElement, CompiledClass>{};

  List<Command> commands;

  LibraryElement fletchSystemLibrary;

  FunctionElement fletchSystemEntry;

  FunctionElement fletchExternalInvokeMain;

  FunctionElement fletchExternalYield;

  FletchBackend(FletchCompiler compiler)
      : this.context = compiler.context,
        this.constantCompilerTask = new DartConstantTask(compiler),
        super(compiler) {
    context.resolutionCallbacks = new FletchResolutionCallbacks(context);
  }

  CompiledClass registerClassElement(ClassElement element) {
    return compiledClasses.putIfAbsent(element, () {
        int id = classIds.putIfAbsent(element, () => classIds.length);
        return new CompiledClass(id, element);
      });
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

    FunctionElement findHelper(String name) {
      FunctionElement helper = fletchSystemLibrary.findLocal(name);
      if (helper == null) {
        compiler.reportError(
            fletchSystemLibrary, MessageKind.GENERIC,
            {'text': "Required implementation method '$name' not found."});
      }
      return helper;
    }

    FunctionElement findExternal(String name) {
      FunctionElement helper = findHelper(name);
      externals.add(helper);
      return helper;
    }

    fletchSystemEntry = findHelper('entry');
    if (fletchSystemEntry != null) {
      world.registerStaticUse(fletchSystemEntry);
    }
    fletchExternalInvokeMain = findExternal('invokeMain');
    fletchExternalYield = findExternal('yield');

    registerClassElement(compiler.objectClass);
  }

  ClassElement get stringImplementation {
    return fletchSystemLibrary.findLocal("_StringImpl");
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
    return super.stringImplementation;
  }

  void codegen(CodegenWorkItem work) {
    Element element = work.element;
    assert(!compiledFunctions.containsKey(element));
    if (compiler.verbose) {
      compiler.reportHint(
          element, MessageKind.GENERIC, {'text': 'Compiling ${element.name}'});
    }

    if (element.isFunction || element.isGetter) {
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
    if (function == compiler.mainFunction) {
      registry.registerStaticInvocation(fletchSystemEntry);
    }

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
    // TODO(ahe): Don't do this.
    compiler.enqueuer.codegen.generatedCode[function] = null;

    int methodId = allocateMethodId(function);

    if (function.isInstanceMember) {
      ClassElement enclosingClass = function.enclosingClass;
      CompiledClass compiledClass = registerClassElement(enclosingClass);
      String symbol = context.getSymbolFromFunction(function);
      int id = context.getSymbolId(symbol);
      int arity = function.functionSignature.parameterCount;
      SelectorKind kind = function.isGetter ?
          SelectorKind.Getter : SelectorKind.Method;
      int fletchSelector = FletchSelector.encode(id, kind, arity);
      compiledClass.methodTable[fletchSelector] = methodId;
    }

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
      functionCompiler.builder
          ..emitThrow()
          ..methodEnd();
    } else {
      functionCompiler.compile();
    }
  }

  void codegenExternalFunction(
      FunctionElement function,
      FunctionCompiler functionCompiler) {
    if (function == fletchExternalYield) {
      codegenExternalYield(function, functionCompiler);
    } else if (function == fletchExternalInvokeMain) {
      codegenExternalInvokeMain(function, functionCompiler);
    } else {
      compiler.internalError(function, "Unhandled external function.");
    }
  }

  void codegenExternalYield(
      FunctionElement function,
      FunctionCompiler functionCompiler) {
    functionCompiler.builder
        ..loadLocal(1)
        ..processYield()
        ..ret()
        ..methodEnd();
  }

  void codegenExternalInvokeMain(
      FunctionElement function,
      FunctionCompiler functionCompiler) {
    // TODO(ahe): This code shouldn't normally be called, only if invokeMain is
    // torn off.
    FunctionElement main = compiler.mainFunction;
    int mainArity = main.functionSignature.parameterCount;
    registry.registerStaticInvocation(main);
    int methodId = allocateConstantFromFunction(main);
    if (mainArity == 0) {
    } else {
      // TODO(ahe): Push arguments on stack.
      compiler.internalError(main, "Arguments to main not implemented yet.");
    }
    functionCompiler.builder
        ..invokeStatic(methodId, mainArity)
        ..ret()
        ..methodEnd();
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
        const NewMap(MapId.classes),
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

    for (CompiledClass compiledClass in compiledClasses.values) {
      ClassElement element = compiledClass.element;
      if (element == stringImplementation) {
        commands.add(new PushBuiltinClass(14, 0));
      } else if (element == compiler.objectClass) {
        commands.add(new PushBuiltinClass(1, 0));
      } else {
        commands.add(new PushNewClass(0));
      }

      commands.add(const Dup());
      commands.add(new PopToMap(MapId.classes, compiledClass.id));

      compiledClass.methodTable.forEach((int selector, int methodId) {
        commands.add(new PushNewInteger(selector));
        commands.add(new PushFromMap(MapId.methods, methodId));
      });
      commands.add(new ChangeMethodTable(compiledClass.methodTable.length));

      changes++;
    }

    context.forEachStatic((element, index) {
      // TODO(ajohnsen): Push initializers.
      commands.add(const PushNull());
    });
    commands.add(new ChangeStatics(context.staticIndices.length));
    changes++;

    for (CompiledClass compiledClass in compiledClasses.values) {
      ClassElement element = compiledClass.element;
      if (element == compiler.objectClass) continue;
      commands.add(new PushFromMap(MapId.classes, compiledClass.id));
      // TODO(ajohnsen): Don't assume object id is 0.
      commands.add(new PushFromMap(MapId.classes, 0));
      commands.add(const ChangeSuperClass());
      changes++;
    }

    for (Function action in deferredActions) {
      action();
      changes++;
    }

    commands.add(new CommitChanges(changes));

    commands.add(const PushNewInteger(0));

    commands.add(
        new PushFromMap(
            MapId.methods, allocateMethodId(fletchSystemEntry)));

    commands.add(const RunMain());

    this.commands = commands;

    return 0;
  }

  int allocateMethodId(FunctionElement element) {
    element = element.declaration;
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

    if (Uri.parse('dart:_fletch_system') == library.canonicalUri) {
      fletchSystemLibrary = library;
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
    } else if (externals.contains(element)) {
      // Nothing needed for now.
    } else {
      compiler.reportError(
          element, MessageKind.PATCH_EXTERNAL_WITHOUT_IMPLEMENTATION);
    }
    return element;
  }
}
