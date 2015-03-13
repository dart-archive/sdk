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
    DartString,
    EmptyStatement,
    Expression;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    ConstructorElement,
    Element,
    FieldElement,
    FormalElement,
    FunctionElement,
    FunctionSignature,
    LibraryElement;

import 'package:compiler/src/universe/universe.dart'
    show Selector;

import 'package:compiler/src/util/util.dart'
    show Spannable;

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

import 'fletch_constants.dart' show
    FletchClassConstant,
    FletchFunctionConstant;

import 'compiled_function.dart' show
    CompiledFunction;

import 'fletch_context.dart';

import 'fletch_selector.dart';

import 'function_compiler.dart';

import 'constructor_compiler.dart';

import 'closure_environment.dart';

import '../commands.dart';

class CompiledClass {
  final int id;
  final ClassElement element;
  final int fields;
  final CompiledClass superClass;

  final Map<int, int> methodTable = <int, int>{};

  CompiledClass(this.id, this.element, this.fields, this.superClass);

  /**
   * Returns the number of instance fields of all the super classes of this
   * class.
   *
   * If this class has no super class (if it's Object), 0 is returned.
   */
  int get superClassFields => hasSuperClass ? superClass.fields : 0;

  bool get hasSuperClass => superClass != null;

  void createImplicitAccessors(FletchBackend backend) {
    // If we don't have an element (stub class), we don't have anything to
    // generate accessors for.
    if (element == null) return;
    // TODO(ajohnsen): Don't do this once dart2js can enqueue field getters in
    // CodegenEnqueuer.
    int fieldIndex = superClassFields;
    element.forEachInstanceField((enclosing, field) {
      var getter = new Selector.getter(field.name, field.library);
      int getterSelector = backend.context.toFletchSelector(getter);
      methodTable.putIfAbsent(
          getterSelector,
          () => backend.makeGetter(fieldIndex));

      if (!field.isFinal) {
        var setter = new Selector.setter(field.name, field.library);
        var setterSelector = backend.context.toFletchSelector(setter);
        methodTable.putIfAbsent(
            setterSelector,
            () => backend.makeSetter(fieldIndex));
      }

      fieldIndex++;
    });
  }
}

class FletchBackend extends Backend {
  static const String growableListName = '_GrowableList';
  static const String fixedListName = '_FixedList';
  static const String noSuchMethodName = '_noSuchMethod';
  static const String noSuchMethodTrampolineName = '_noSuchMethodTrampoline';

  final FletchContext context;

  final DartConstantTask constantCompilerTask;

  final Map<FunctionElement, int> methodIds = <FunctionElement, int>{};

  final Map<FunctionElement, CompiledFunction> compiledFunctions =
      <FunctionElement, CompiledFunction>{};

  final Map<ConstructorElement, int> constructorIds =
      <ConstructorElement, int>{};

  final List<FletchFunction> functions = <FletchFunction>[];

  final Set<FunctionElement> externals = new Set<FunctionElement>();

  final Map<ClassElement, CompiledClass> compiledClasses =
      <ClassElement, CompiledClass>{};

  final List<CompiledClass> classes = <CompiledClass>[];

  final Set<ClassElement> builtinClasses = new Set<ClassElement>();

  final Map<FunctionElement, ClosureEnvironment> closureEnvironments =
      <FunctionElement, ClosureEnvironment>{};

  final Map<FunctionElement, CompiledClass> closureClasses =
      <FunctionElement, CompiledClass>{};

  final Map<int, int> getters = <int, int>{};
  final Map<int, int> setters = <int, int>{};

  int nextMethodId = 0;

  List<Command> commands;

  LibraryElement fletchSystemLibrary;
  LibraryElement fletchNativesLibrary;

  FunctionElement fletchSystemEntry;

  FunctionElement fletchExternalInvokeMain;

  FunctionElement fletchExternalYield;

  FieldElement fletchNativeElement;

  CompiledClass compiledObjectClass;

  ClassElement stringClass;
  ClassElement smiClass;
  ClassElement mintClass;
  ClassElement growableListClass;

  FletchBackend(FletchCompiler compiler)
      : this.context = compiler.context,
        this.constantCompilerTask = new DartConstantTask(compiler),
        super(compiler) {
    context.resolutionCallbacks = new FletchResolutionCallbacks(context);
  }

  CompiledClass registerClassElement(ClassElement element) {
    if (element == null) return null;
    assert(element.isDeclaration);
    return compiledClasses.putIfAbsent(element, () {
      CompiledClass superClass = registerClassElement(element.superclass);
      int fields = superClass != null ? superClass.fields : 0;
      element.forEachInstanceField((enclosing, field) { fields++; });
      int id = classes.length;
      CompiledClass compiledClass = new CompiledClass(
          id,
          element,
          fields,
          superClass);
      classes.add(compiledClass);
      return compiledClass;
    });
  }

  CompiledClass createStubClass(int fields, CompiledClass superClass) {
    int totalFields = fields + superClass.fields;
    int id = classes.length;
    CompiledClass compiledClass = new CompiledClass(
        id,
        null,
        totalFields,
        superClass);
    classes.add(compiledClass);
    return compiledClass;
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

    fletchNativeElement = fletchSystemLibrary.findLocal('native');

    CompiledClass loadClass(String name, LibraryElement library) {
      var classImpl = library.findLocal(name);
      if (classImpl == null) {
        compiler.internalError(library, "Internal class '$name' not found.");
        return null;
      }
      // TODO(ahe): Register in ResolutionCallbacks. The 3 lines below should
      // not happen at this point in time.
      classImpl.ensureResolved(compiler);
      CompiledClass compiledClass = registerClassElement(classImpl);
      world.registerInstantiatedType(classImpl.rawType, registry);
      // TODO(ahe): This is a hack to let both the world and the codegen know
      // about the instantiated type.
      registry.registerInstantiatedType(classImpl.rawType);
      return compiledClass;
    }

    CompiledClass loadBuiltinClass(String name, LibraryElement library) {
      CompiledClass compiledClass = loadClass(name, library);
      builtinClasses.add(compiledClass.element);
      return compiledClass;
    }

    compiledObjectClass = loadBuiltinClass("Object", compiler.coreLibrary);
    smiClass = loadBuiltinClass("_Smi", fletchSystemLibrary).element;
    mintClass = loadBuiltinClass("_Mint", fletchSystemLibrary).element;
    stringClass = loadBuiltinClass("String", fletchSystemLibrary).element;
    loadBuiltinClass("Null", compiler.coreLibrary);
    loadBuiltinClass("bool", compiler.coreLibrary);

    growableListClass =
        loadClass(growableListName, fletchSystemLibrary).element;
    // Register list constructors to world.
    // TODO(ahe): Register growableListClass through ResolutionCallbacks.
    for (ConstructorElement constructor in growableListClass.constructors) {
      world.registerStaticUse(constructor);
    }
    // TODO(ahe): Register fixedListClass through ResolutionCallbacks.
    loadClass(fixedListName, fletchSystemLibrary);

    // TODO(ajohnsen): Remove? String interpolation does not enqueue '+'.
    // Investigate what else it may enqueue, could be StringBuilder, and then
    // consider using that instead.
    world.registerDynamicInvocation(new Selector.binaryOperator('+'));

    void registerNamedSelector(String name, LibraryElement library, int arity) {
      var selector = new Selector.call(name, library, arity);
      world.registerDynamicInvocation(selector);
      registry.registerDynamicInvocation(selector);
    }

    registerNamedSelector(noSuchMethodTrampolineName, compiler.coreLibrary, 0);
    registerNamedSelector(noSuchMethodName, compiler.coreLibrary, 1);
  }

  ClassElement get stringImplementation => stringClass;

  ClassElement get intImplementation => smiClass;

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

  CompiledClass createClosureClass(
      Function closure,
      ClosureEnvironment closureEnvironment) {
    return closureClasses.putIfAbsent(closure, () {
      ClosureInfo info = closureEnvironment.closures[closure];
      int fields = info.free.length;
      if (info.isThisFree) fields++;
      return createStubClass(fields, compiledObjectClass);
    });
  }

  void codegen(CodegenWorkItem work) {
    Element element = work.element;
    assert(!compiledFunctions.containsKey(element));
    if (compiler.verbose) {
      compiler.reportHint(
          element, MessageKind.GENERIC, {'text': 'Compiling ${element.name}'});
    }

    if (element.isFunction ||
        element.isGetter ||
        element.isGenerativeConstructor) {
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

    ClosureEnvironment closureEnvironment = createClosureEnvironment(
        function,
        elements);

    CompiledClass holderClass;

    if (function.isInstanceMember ||
        function.isGenerativeConstructor) {
      ClassElement enclosingClass = function.enclosingClass.declaration;
      holderClass = registerClassElement(enclosingClass);
    } else if (function.memberContext != function) {
      holderClass = createClosureClass(function, closureEnvironment);
    }

    FunctionCompiler functionCompiler = new FunctionCompiler(
        allocateMethodId(function),
        context,
        elements,
        registry,
        closureEnvironment,
        function,
        holderClass);

    if (isNative(function)) {
      codegenNativeFunction(function, functionCompiler);
    } else if (isExternal(function)) {
      codegenExternalFunction(function, functionCompiler);
    } else {
      functionCompiler.compile();
    }

    CompiledFunction compiledFunction = functionCompiler.compiledFunction;

    compiledFunctions[function] = compiledFunction;
    functions.add(compiledFunction);

    // TODO(ahe): Don't do this.
    compiler.enqueuer.codegen.generatedCode[function.declaration] = null;

    if (holderClass != null && !function.isGenerativeConstructor) {
      // Inject the function into the method table of the 'holderClass' class. Note
      // that while constructor bodies has a this argument, we don't inject
      // them into the method table.
      String symbol = context.getSymbolFromFunction(function);
      int id = context.getSymbolId(symbol);
      int arity = function.functionSignature.parameterCount;
      SelectorKind kind = SelectorKind.Method;
      if (function.isGetter) kind = SelectorKind.Getter;
      if (function.isSetter) kind = SelectorKind.Setter;
      int fletchSelector = FletchSelector.encode(id, kind, arity);
      holderClass.methodTable[fletchSelector] = compiledFunction.methodId;
    }

    if (compiler.verbose) {
      print(functionCompiler.compiledFunction.verboseToString());
    }
  }

  void codegenNativeFunction(
      FunctionElement function,
      FunctionCompiler functionCompiler) {
    String name = function.name;

    ClassElement enclosingClass = function.enclosingClass;
    if (enclosingClass != null) name = '${enclosingClass.name}.$name';

    FletchNativeDescriptor descriptor = context.nativeDescriptors[name];
    if (descriptor == null) {
      throw "Unsupported native function: $name";
    }

    int arity = functionCompiler.builder.functionArity;
    functionCompiler.builder.invokeNative(arity, descriptor.index);

    EmptyStatement empty = function.node.body.asEmptyStatement();
    if (empty != null) {
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
    } else if (function.name == noSuchMethodTrampolineName &&
               function.library == compiler.coreLibrary) {
      codegenExternalNoSuchMethodTrampoline(function, functionCompiler);
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

  void codegenExternalNoSuchMethodTrampoline(
      FunctionElement function,
      FunctionCompiler functionCompiler) {
    int id = context.getSymbolId(
        context.mangleName(noSuchMethodName, compiler.coreLibrary));
    int fletchSelector = FletchSelector.encodeMethod(id, 1);
    functionCompiler.builder
        ..enterNoSuchMethod()
        ..invokeMethod(fletchSelector, 1)
        ..exitNoSuchMethod()
        ..methodEnd();
  }

  bool isNative(Element element) {
    if (element is FunctionElement) {
      for (var metadata in element.metadata) {
        // TODO(ahe): This code should ensure that @native resolves to precisely
        // the native variable in fletch:system.
        if (metadata.constant == null) continue;
        ConstantValue value = metadata.constant.value;
        if (!value.isString) continue;
        if (value.toDartString().slowToString() != 'native') continue;
        return true;
      }
    }
    return false;
  }

  bool isExternal(Element element) {
    if (element is FunctionElement) return element.isExternal;
    return false;
  }

  bool get canHandleCompilationFailed => true;

  ClosureEnvironment createClosureEnvironment(
      FunctionElement function,
      TreeElements elements) {
    function = function.memberContext;
    return closureEnvironments.putIfAbsent(function, () {
      ClosureVisitor environment = new ClosureVisitor(function, elements);
      return environment.compute();
    });
  }

  int assembleProgram() {
    // TODO(ajohnsen): Currently, the CodegenRegistry does not enqueue fields.
    // This is a workaround, where we basically add getters for all fields.
    for (CompiledClass compiledClass in classes) {
      compiledClass.createImplicitAccessors(this);
    }

    List<Command> commands = <Command>[
        const NewMap(MapId.methods),
        const NewMap(MapId.classes),
    ];

    List<Function> deferredActions = <Function>[];

    void pushNewFunction(CompiledFunction compiledFunction) {
      int arity = compiledFunction.builder.functionArity;
      int constantCount = compiledFunction.constants.length;
      int methodId = compiledFunction.methodId;

      compiledFunction.constants.forEach((constant, int index) {
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
              commands
                  ..add(new PushFromMap(MapId.methods, methodId))
                  ..add(new PushFromMap(MapId.methods, constant.methodId))
                  ..add(new ChangeMethodLiteral(index));
            });
          } else if (constant is FletchClassConstant) {
            commands.add(const PushNull());
            deferredActions.add(() {
              commands
                  ..add(new PushFromMap(MapId.methods, methodId))
                  ..add(new PushFromMap(MapId.classes, constant.classId))
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
              arity, constantCount, compiledFunction.builder.bytecodes));

      commands.add(new PopToMap(MapId.methods, methodId));
    }

    functions.forEach(pushNewFunction);

    int changes = 0;

    for (CompiledClass compiledClass in classes) {
      ClassElement element = compiledClass.element;
      if (builtinClasses.contains(element)) {
        int nameId = context.getSymbolId(element.name);
        commands.add(new PushBuiltinClass(nameId, compiledClass.fields));
      } else {
        commands.add(new PushNewClass(compiledClass.fields));
      }

      commands.add(const Dup());
      commands.add(new PopToMap(MapId.classes, compiledClass.id));

      Map<int, int> methodTable = compiledClass.methodTable;
      for (int selector in methodTable.keys.toList()..sort()) {
        int methodId = methodTable[selector];
        commands.add(new PushNewInteger(selector));
        commands.add(new PushFromMap(MapId.methods, methodId));
      }
      commands.add(new ChangeMethodTable(compiledClass.methodTable.length));

      changes++;
    }

    context.forEachStatic((element, index) {
      // TODO(ajohnsen): Push initializers.
      commands.add(const PushNull());
    });
    commands.add(new ChangeStatics(context.staticIndices.length));
    changes++;

    for (CompiledClass compiledClass in classes) {
      CompiledClass superClass = compiledClass.superClass;
      if (superClass == null) continue;
      commands.add(new PushFromMap(MapId.classes, compiledClass.id));
      commands.add(new PushFromMap(MapId.classes, superClass.id));
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
            MapId.methods, allocatedMethodId(fletchSystemEntry)));

    commands.add(const RunMain());

    this.commands = commands;

    return 0;
  }

  int allocateMethodId(FunctionElement element) {
    element = element.declaration;
    return methodIds.putIfAbsent(element, () => nextMethodId++);
  }

  int allocatedMethodId(FunctionElement element) {
    element = element.declaration;
    int id = methodIds[element];
    if (id != null) return id;
    id = constructorIds[element];
    if (id != null) return id;
    throw "Use of non-compiled function: $element";
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
    if (Uri.parse('dart:fletch_natives') == library.canonicalUri) {
      fletchNativesLibrary = library;
    }
  }

  bool isBackendLibrary(LibraryElement library) {
    return library == fletchSystemLibrary;
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
    } else if (element.library == fletchSystemLibrary) {
      // Nothing needed for now.
    } else if (element.library == fletchNativesLibrary) {
      // Nothing needed for now.
    } else if (element.library == compiler.coreLibrary) {
      // Nothing needed for now.
    } else if (externals.contains(element)) {
      // Nothing needed for now.
    } else {
      compiler.reportError(
          element, MessageKind.PATCH_EXTERNAL_WITHOUT_IMPLEMENTATION);
    }
    return element;
  }

  int compileConstructor(ConstructorElement constructor,
                         TreeElements elements,
                         Registry registry) {
    // TODO(ajohnsen): Move out to seperate file, and visit super
    // constructors as well.
    if (constructorIds.containsKey(constructor)) {
      return constructorIds[constructor];
    }

    if (compiler.verbose) {
      compiler.reportHint(
          constructor,
          MessageKind.GENERIC,
          {'text': 'Compiling constructor ${constructor.name}'});
    }

    ClassElement classElement = constructor.enclosingClass;
    CompiledClass compiledClass = registerClassElement(classElement);

    ClosureEnvironment closureEnvironment = createClosureEnvironment(
        constructor,
        elements);

    ConstructorCompiler constructorCompiler = new ConstructorCompiler(
        nextMethodId++,
        context,
        elements,
        registry,
        closureEnvironment,
        constructor,
        compiledClass);

    constructorCompiler.compile();
    CompiledFunction compiledFunction = constructorCompiler.compiledFunction;
    if (compiler.verbose) {
      print(compiledFunction.verboseToString());
    }

    functions.add(compiledFunction);

    return compiledFunction.methodId;
  }

  /**
   * Generate a getter for field [fieldIndex].
   */
  int makeGetter(int fieldIndex) {
    return getters.putIfAbsent(fieldIndex, () {
      CompiledFunction stub = new CompiledFunction.accessor(
          nextMethodId++,
          false);
      stub.builder
          ..loadParameter(0)
          ..loadField(fieldIndex)
          ..ret()
          ..methodEnd();
      functions.add(stub);
      return stub.methodId;
    });
  }

  /**
   * Generate a setter for field [fieldIndex].
   */
  int makeSetter(int fieldIndex) {
    return setters.putIfAbsent(fieldIndex, () {
      CompiledFunction stub = new CompiledFunction.accessor(
          nextMethodId++,
          true);
      stub.builder
          ..loadParameter(0)
          ..loadParameter(1)
          ..storeField(fieldIndex)
      // Top is at this point the rhs argument, thus the return value.
          ..ret()
          ..methodEnd();
      functions.add(stub);
      return stub.methodId;
    });
  }

  void generateUnimplementedError(
      Spannable spannable,
      String reason,
      CompiledFunction function) {
    compiler.reportError(
        spannable, MessageKind.GENERIC, {'text': reason});
    var constString = constantSystem.createString(
        new DartString.literal(reason));
    function
        ..builder.loadConst(function.allocateConstant(constString))
        ..builder.emitThrow();
  }
}
