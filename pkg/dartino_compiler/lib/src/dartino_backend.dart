// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_backend;

import 'dart:async' show
    Future;

import 'dart:collection' show
    Queue;

import 'package:compiler/src/common/backend_api.dart' show
    Backend,
    ImpactTransformer;

import 'package:compiler/src/common/tasks.dart' show
    CompilerTask;

import 'package:compiler/src/enqueue.dart' show
    Enqueuer,
    ResolutionEnqueuer;

import 'package:compiler/src/diagnostics/messages.dart' show
    MessageKind;

import 'package:compiler/src/diagnostics/diagnostic_listener.dart' show
    DiagnosticMessage;

import 'package:compiler/src/common/registry.dart' show
    Registry;

import 'package:compiler/src/dart_types.dart' show
    InterfaceType;

import 'package:compiler/src/tree/tree.dart' show
    EmptyStatement;

import 'package:compiler/src/elements/elements.dart' show
    AbstractFieldElement,
    AstElement,
    ClassElement,
    ConstructorElement,
    Element,
    ExecutableElement,
    FieldElement,
    FunctionElement,
    FunctionSignature,
    FunctionTypedElement,
    LibraryElement,
    MemberElement,
    MethodElement,
    Name,
    PublicName,
    ResolvedAstKind;

import 'package:compiler/src/universe/selector.dart' show
    Selector;

import 'package:compiler/src/universe/use.dart' show
    DynamicUse,
    StaticUse,
    TypeUse;

import 'package:compiler/src/universe/call_structure.dart' show
    CallStructure;

import 'package:compiler/src/common.dart' show
    Spannable;

import 'package:compiler/src/elements/modelx.dart' show
    FunctionElementX;

import 'package:compiler/src/dart_backend/dart_backend.dart' show
    DartConstantTask;

import 'package:compiler/src/constants/constant_system.dart' show
    ConstantSystem;

import 'package:compiler/src/compile_time_constants.dart' show
    BackendConstantEnvironment;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue,
    FunctionConstantValue,
    StringConstantValue;

import 'package:compiler/src/resolution/tree_elements.dart' show
    TreeElements;

import 'package:compiler/src/library_loader.dart' show
    LibraryLoader;

import 'package:compiler/src/common/names.dart' show
    Identifiers,
    Names;

import 'package:compiler/src/universe/world_impact.dart' show
    TransformedWorldImpact,
    WorldImpact;

import 'package:compiler/src/common/resolution.dart';

import 'package:compiler/src/common/names.dart' show
    Names;

import 'package:persistent/persistent.dart' show
    PersistentSet;

import 'dartino_function_builder.dart' show
    DartinoFunctionBuilder;

import 'dartino_class_builder.dart' show
    DartinoClassBuilder;

import 'dartino_system_builder.dart' show
    DartinoSystemBuilder,
    SchemaChange;

import '../dartino_class_base.dart' show
    DartinoClassBase;

import '../dartino_class.dart' show
    DartinoClass;

import '../incremental_backend.dart' show
    IncrementalDartinoBackend;

import 'dartino_enqueuer.dart' show
    DartinoEnqueueTask,
    shouldReportEnqueuingOfElement;

import 'dartino_registry.dart' show
    ClosureKind,
    DartinoRegistry;

import 'diagnostic.dart' show
   throwInternalError;

import 'class_debug_info.dart' show
    ClassDebugInfo;

import 'codegen_visitor.dart' show
    CodegenVisitor;

import 'debug_info.dart' show
    DebugInfo;

import 'debug_info_function_codegen.dart' show
    DebugInfoFunctionCodegen;

import 'function_codegen.dart' show
    FunctionCodegen,
    FunctionCodegenBase;

import 'debug_info_constructor_codegen.dart' show
    DebugInfoConstructorCodegen;

import 'lazy_field_initializer_codegen.dart' show
    LazyFieldInitializerCodegen;

import 'constructor_codegen.dart' show
    ConstructorCodegen;

import 'debug_info_lazy_field_initializer_codegen.dart' show
    DebugInfoLazyFieldInitializerCodegen;

import 'dartino_context.dart' show
    BytecodeAssembler,
    BytecodeLabel,
    DartinoCompilerImplementation,
    DartinoContext,
    DartinoNativeDescriptor;

import 'dartino_selector.dart' show
    DartinoSelector,
    SelectorKind;

import 'closure_environment.dart' show
    ClosureEnvironment,
    ClosureInfo,
    ClosureVisitor;

import '../bytecodes.dart' show
    Bytecode;

import '../vm_commands.dart' show
    MapId,
    NewMap,
    PushFromMap,
    PushNewInteger,
    SetEntryPoint,
    VmCommand;

import '../dartino_system.dart' show
    DartinoDelta,
    DartinoFunction,
    DartinoFunctionBase,
    DartinoFunctionKind,
    DartinoSystem,
    ParameterStubSignature;

import 'parameter_stub_codegen.dart' show
    ParameterStubCodegen;

import '../dartino_field.dart' show
    DartinoField;

class DartinoBackend extends Backend
    implements IncrementalDartinoBackend {
  static const String growableListName = '_GrowableList';
  static const String constantListName = '_ConstantList';
  static const String constantByteListName = '_ConstantByteList';
  static const String constantMapName = '_ConstantMap';
  static const String dartinoNoSuchMethodErrorName = 'DartinoNoSuchMethodError';
  static const String noSuchMethodName = '_noSuchMethod';
  static const String noSuchMethodTrampolineName = '_noSuchMethodTrampoline';

  final DartinoContext context;

  final DartConstantTask constantCompilerTask;

  /// Constructors that need to have an initilizer compiled. See
  /// [compilePendingConstructorInitializers].
  final Queue<DartinoFunctionBuilder> pendingConstructorInitializers =
      new Queue<DartinoFunctionBuilder>();

  final Set<FunctionElement> externals = new Set<FunctionElement>();

  // TODO(ahe): This should be invalidated by a new [DartinoSystem].
  final Map<MemberElement, ClosureEnvironment> closureEnvironments =
      <MemberElement, ClosureEnvironment>{};

  DartinoCompilerImplementation get compiler => super.compiler;

  LibraryElement dartinoSystemLibrary;
  LibraryElement dartinoFFILibrary;
  LibraryElement collectionLibrary;
  LibraryElement mathLibrary;
  LibraryElement get asyncLibrary => compiler.asyncLibrary;
  LibraryElement dartinoLibrary;

  FunctionElement dartinoSystemEntry;

  FunctionElement dartinoExternalInvokeMain;

  FunctionElement dartinoExternalYield;

  FunctionElement dartinoExternalNativeError;

  FunctionElement dartinoExternalCoroutineChange;

  FunctionElement dartinoUnresolved;
  FunctionElement dartinoCompileError;

  ClassElement smiClass;
  ClassElement mintClass;
  ClassElement growableListClass;
  ClassElement dartinoNoSuchMethodErrorClass;
  ClassElement bigintClass;
  ClassElement uint32DigitsClass;

  /// Holds a reference to the class Coroutine if it exists.
  ClassElement coroutineClass;

  ClassElement closureClass;

  DartinoSystemBuilder systemBuilder;

  final Set<FunctionElement> alwaysEnqueue = new Set<FunctionElement>();

  DartinoImpactTransformer impactTransformer;

  DartinoBackend(DartinoCompilerImplementation compiler)
      : this.context = compiler.context,
        this.constantCompilerTask = new DartConstantTask(compiler),
        this.systemBuilder = new DartinoSystemBuilder(DartinoSystem.base),
        super(compiler) {
    this.impactTransformer = new DartinoImpactTransformer(this);
  }

  void newSystemBuilder(DartinoSystem predecessorSystem) {
    systemBuilder = new DartinoSystemBuilder(predecessorSystem);
  }

  // TODO(ahe): Where should this end up...?
  DartinoClassBuilder get compiledClosureClass {
    return systemBuilder.getClassBuilder(closureClass);
  }

  Map<FunctionElement, ClosureInfo> lookupNestedClosures(Element element) {
    return closureEnvironments[element]?.closures;
  }

  DartinoClassBuilder createCallableStubClass(
      List<DartinoField> fields,
      int arity,
      DartinoClassBuilder superclass) {
    DartinoClassBuilder classBuilder = systemBuilder.newClassBuilder(
        null, superclass, false, new SchemaChange(null), extraFields: fields);
    classBuilder.createIsFunctionEntry(
        compiler.coreClasses.functionClass, arity);
    return classBuilder;
  }

  List<CompilerTask> get tasks => <CompilerTask>[];

  ConstantSystem get constantSystem {
    return constantCompilerTask.constantCompiler.constantSystem;
  }

  BackendConstantEnvironment get constants => constantCompilerTask;

  bool classNeedsRti(ClassElement cls) => false;

  bool methodNeedsRti(FunctionElement function) => false;

  void enqueueHelpers(ResolutionEnqueuer world, Registry incomingRegistry) {
    DartinoRegistry registry = new DartinoRegistry(compiler);

    bool hasMissingHelpers = false;
    loadHelperMethods((String name) {
      LibraryElement library = dartinoSystemLibrary;
      Element helper = library.findLocal(name);
      // TODO(ahe): Make it cleaner.
      if (helper != null && helper.isAbstractField) {
        AbstractFieldElement abstractField = helper;
        helper = abstractField.getter;
      }
      if (helper == null) {
        hasMissingHelpers = true;
        compiler.reporter.reportErrorMessage(
            library, MessageKind.GENERIC,
            {'text': "Required implementation method '$name' not found."});
      }
      return helper;
    });
    if (hasMissingHelpers) {
      throwInternalError(
          "Some implementation methods are missing, see details above");
    }
    world.registerStaticUse(
        new StaticUse.staticInvoke(dartinoCompileError, CallStructure.ONE_ARG));
    world.registerStaticUse(
        new StaticUse.staticInvoke(dartinoSystemEntry, CallStructure.ONE_ARG));
    world.registerStaticUse(
        new StaticUse.staticInvoke(dartinoUnresolved, CallStructure.ONE_ARG));

    loadHelperClasses((
        String name,
        LibraryElement library,
        {bool builtin: false}) {
      var classImpl = library.findLocal(name);
      if (classImpl == null) classImpl = library.implementation.find(name);
      if (classImpl == null) {
        compiler.reporter.reportErrorMessage(
            library, MessageKind.GENERIC,
            {'text': "Required implementation class '$name' not found."});
        hasMissingHelpers = true;
        return null;
      }
      if (hasMissingHelpers) return null;
      if (builtin) systemBuilder.registerBuiltinClass(classImpl);
      {
        // TODO(ahe): Register in ResolutionCallbacks. The lines in this block
        // should not happen at this point in time.
        classImpl.ensureResolved(compiler.resolution);
        world.registerInstantiatedType(classImpl.rawType);
        // TODO(ahe): This is a hack to let both the world and the codegen know
        // about the instantiated type.
        registry.registerInstantiatedType(classImpl.rawType);
      }
      return systemBuilder.getClassBuilder(classImpl);
    });
    if (hasMissingHelpers) {
      throwInternalError(
          "Some implementation classes are missing, see details above");
    }

    // Register list constructors to world.
    // TODO(ahe): Register growableListClass through ResolutionCallbacks.
    growableListClass.constructors.forEach((Element element) {
      world.registerStaticUse(new StaticUse.constructorInvoke(element, null));
    });

    // TODO(ajohnsen): Remove? String interpolation does not enqueue '+'.
    // Investigate what else it may enqueue, could be StringBuilder, and then
    // consider using that instead.
    world.registerDynamicUse(
        new DynamicUse(new Selector.binaryOperator('+'), null));

    world.registerDynamicUse(new DynamicUse(
        new Selector.call(new PublicName('add'), CallStructure.ONE_ARG), null));

    alwaysEnqueue.add(
        compiler.coreClasses.objectClass.implementation.lookupLocalMember(
            noSuchMethodTrampolineName));
    alwaysEnqueue.add(
        compiler.coreClasses.objectClass.implementation.lookupLocalMember(
            noSuchMethodName));

    if (coroutineClass != null) {
      systemBuilder.registerBuiltinClass(coroutineClass);
      alwaysEnqueue.add(coroutineClass.lookupLocalMember("_coroutineStart"));
    }

    for (FunctionElement element in alwaysEnqueue) {
      world.registerStaticUse(new StaticUse.foreignUse(element));
    }
  }

  void loadHelperMethods(
      FunctionElement findHelper(String name)) {

    FunctionElement findExternal(String name) {
      FunctionElement helper = findHelper(name);
      if (helper != null) externals.add(helper);
      return helper;
    }

    dartinoSystemEntry = findHelper('entry');
    dartinoExternalInvokeMain = findExternal('invokeMain');
    dartinoExternalYield = findExternal('yield');
    dartinoExternalCoroutineChange = findExternal('coroutineChange');
    dartinoExternalNativeError = findExternal('nativeError');
    dartinoUnresolved = findExternal('unresolved');
    dartinoCompileError = findExternal('compileError');
  }

  void loadHelperClasses(
      DartinoClassBuilder loadClass(
          String name,
          LibraryElement library,
          {bool builtin})) {
    loadClass("Object", compiler.coreLibrary, builtin: true);
    closureClass = loadClass(
        "_TearOffClosure",
        compiler.coreLibrary,
        builtin: true)?.element;
    smiClass = loadClass("_Smi", compiler.coreLibrary, builtin: true)?.element;
    mintClass =
        loadClass("_Mint", compiler.coreLibrary, builtin: true)?.element;
    loadClass("_OneByteString", compiler.coreLibrary, builtin: true);
    loadClass("_TwoByteString", compiler.coreLibrary, builtin: true);
    // TODO(ahe): Register _ConstantList through ResolutionCallbacks.
    loadClass(constantListName, dartinoSystemLibrary, builtin: true);
    loadClass(constantByteListName, dartinoSystemLibrary, builtin: true);
    loadClass(constantMapName, dartinoSystemLibrary, builtin: true);
    loadClass("_DoubleImpl", compiler.coreLibrary, builtin: true);
    loadClass("Null", compiler.coreLibrary, builtin: true);
    loadClass("bool", compiler.coreLibrary, builtin: true);
    loadClass("StackOverflowError", compiler.coreLibrary, builtin: true);
    loadClass("Port", dartinoLibrary, builtin: true);
    loadClass("Process", dartinoLibrary, builtin: true);
    loadClass("ProcessDeath", dartinoLibrary, builtin: true);
    loadClass("ForeignMemory", dartinoFFILibrary, builtin: true);
    if (context.enableBigint) {
      bigintClass = loadClass("_Bigint", compiler.coreLibrary)?.element;
      uint32DigitsClass =
          loadClass("_Uint32Digits", compiler.coreLibrary)?.element;
    }
    growableListClass =
        loadClass(growableListName, dartinoSystemLibrary)?.element;
    dartinoNoSuchMethodErrorClass =
        loadClass(dartinoNoSuchMethodErrorName,
                  dartinoSystemLibrary,
                  builtin: true)?.element;

    // This class is optional.
    coroutineClass = dartinoSystemLibrary.implementation.find("Coroutine");
    if (coroutineClass != null) {
      coroutineClass.ensureResolved(compiler.resolution);
    }
  }

  void onElementResolved(Element element) {
    if (alwaysEnqueue.contains(element)) {
      var registry = new DartinoRegistry(compiler);
      registry.registerStaticInvocation(element);
    }
  }

  ClassElement get intImplementation => smiClass;

  /// Class of annotations to mark patches in patch files.
  ///
  /// The patch parser (pkg/compiler/lib/src/patch_parser.dart). The patch
  /// parser looks for an annotation on the form "@patch", where "patch" is
  /// compile-time constant instance of [patchAnnotationClass].
  ClassElement get patchAnnotationClass {
    // TODO(ahe): Introduce a proper constant class to identify constants. For
    // now, we simply put "const patch = "patch";" in dartino._system.
    return super.stringImplementation;
  }

  /**
   * Create a tearoff class for function [function].
   *
   * The class will have one method named 'call', accepting the same arguments
   * as [function]. The method will load the arguments received and statically
   * call [function] (essential a tail-call).
   *
   * If [function] is an instance member, the class will have one field, the
   * instance.
   */
  DartinoClassBase getTearoffClass(DartinoFunctionBase function) {
    DartinoClassBase base = systemBuilder.lookupTearoffClass(function);
    if (base != null) return base;

    FunctionSignature signature = function.signature;
    bool hasThis = function.isInstanceMember;
    List<DartinoField> fields = <DartinoField>[];
    if (hasThis) {
      ClassElement classElement =
          systemBuilder.lookupClassBuilder(function.memberOf).element;
      fields.add(new DartinoField.boxedThis(classElement));
    }

    DartinoClassBuilder tearoffClass = createCallableStubClass(
        fields, signature.parameterCount, compiledClosureClass);

    DartinoFunctionBuilder functionBuilder =
        systemBuilder.newTearOff(function, tearoffClass.classId);

    BytecodeAssembler assembler = functionBuilder.assembler;
    int argumentCount = signature.parameterCount;
    if (hasThis) {
      argumentCount++;
      // If the tearoff has a 'this' value, load it. It's the only field
      // in the tearoff class.
      assembler
          ..loadParameter(0)
          ..loadField(0);
    }
    for (int i = 0; i < signature.parameterCount; i++) {
      // The closure-class is at parameter index 0, so argument i is at
      // i + 1.
      assembler.loadParameter(i + 1);
    }
    int constId = functionBuilder.allocateConstantFromFunction(
        function.functionId);
    // TODO(ajohnsen): Create a tail-call bytecode, so we don't have to
    // load all the arguments.
    assembler
        ..invokeStatic(constId, argumentCount)
        ..ret()
        ..methodEnd();

    String symbol = systemBuilder.getCallSymbol(signature);
    int id = systemBuilder.getSymbolId(symbol);
    int dartinoSelector = DartinoSelector.encodeMethod(
        id,
        signature.parameterCount);
    tearoffClass.addToMethodTable(dartinoSelector, functionBuilder);

    if (!function.isInstanceMember) return tearoffClass;

    ClassElement classElement =
        systemBuilder.lookupClassBuilder(function.memberOf).element;
    if (classElement == null) return tearoffClass;

    // Create == function that tests for equality.
    int isSelector = systemBuilder.toDartinoTearoffIsSelector(
        function.name,
        classElement);
    tearoffClass.addIsSelector(isSelector);

    DartinoFunctionBuilder equal = systemBuilder.newFunctionBuilder(
        DartinoFunctionKind.NORMAL,
        2);

    BytecodeLabel isFalse = new BytecodeLabel();
    equal.assembler
      // First test for class. This ensures it's the exact function that
      // we expect.
      ..loadParameter(1)
      ..invokeTest(isSelector, 0)
      ..branchIfFalse(isFalse)
      // Then test that the receiver is identical.
      ..loadParameter(0)
      ..loadField(0)
      ..loadParameter(1)
      ..loadField(0)
      ..identicalNonNumeric()
      ..branchIfFalse(isFalse)
      ..loadLiteralTrue()
      ..ret()
      ..bind(isFalse)
      ..loadLiteralFalse()
      ..ret()
      ..methodEnd();

    id = systemBuilder.getSymbolId("==");
    int equalsSelector = DartinoSelector.encodeMethod(id, 1);
    tearoffClass.addToMethodTable(equalsSelector, equal);

    // Create hashCode getter. We simply add the object hashCode and the
    // method id of the tearoff'ed function.
    DartinoFunctionBuilder hashCode = systemBuilder.newFunctionBuilder(
        DartinoFunctionKind.ACCESSOR,
        1);

    int hashCodeSelector = DartinoSelector.encodeGetter(
        systemBuilder.getSymbolId("hashCode"));

    // TODO(ajohnsen): Use plus, we plus is always enqueued. Consider using
    // xor when we have a way to enqueue it from here.
    int plusSelector = DartinoSelector.encodeMethod(
        systemBuilder.getSymbolId("+"), 1);

    hashCode.assembler
      ..loadParameter(0)
      ..loadField(0)
      ..invokeMethod(hashCodeSelector, 0)
      ..loadLiteral(function.functionId)
      ..invokeMethod(plusSelector, 1)
      ..ret()
      ..methodEnd();

    tearoffClass.addToMethodTable(hashCodeSelector, hashCode);

    return tearoffClass;
  }

  DartinoFunctionBase getFunctionForElement(FunctionElement element) {
    assert(element.memberContext == element);

    DartinoFunctionBase function =
        systemBuilder.lookupFunctionByElement(element);
    if (function != null) return function;

    return createDartinoFunctionBuilder(element);
  }

  /// Get the constructor initializer function for [constructor]. The function
  /// will be created the first time it's called for [constructor].
  ///
  /// See [compilePendingConstructorInitializers] for an overview of
  /// constructor intializers and constructor bodies.
  DartinoFunctionBase getConstructorInitializerFunction(
      ConstructorElement constructor) {
    assert(constructor.isDeclaration);
    constructor = constructor.implementation;
    DartinoFunctionBase base =
        systemBuilder.lookupConstructorInitializerByElement(constructor);
    if (base != null) return base;

    DartinoFunctionBuilder builder = systemBuilder.newConstructorInitializer(
        constructor);
    pendingConstructorInitializers.addFirst(builder);

    return builder;
  }

  DartinoFunctionBuilder createDartinoFunctionBuilder(
      FunctionElement function) {
    assert(function.memberContext == function);

    DartinoClassBuilder holderClass;
    if (function.isInstanceMember || function.isGenerativeConstructor) {
      ClassElement enclosingClass = function.enclosingClass.declaration;
      holderClass = systemBuilder.getClassBuilder(enclosingClass);
    }
    return internalCreateDartinoFunctionBuilder(
        function,
        function.name,
        holderClass);
  }

  DartinoFunctionBuilder internalCreateDartinoFunctionBuilder(
      FunctionElement function,
      String name,
      DartinoClassBuilder holderClass) {
    DartinoFunctionBuilder functionBuilder =
        systemBuilder.lookupFunctionBuilderByElement(function.declaration);
    if (functionBuilder != null) return functionBuilder;

    FunctionTypedElement implementation = function.implementation;
    int memberOf = holderClass != null ? holderClass.classId : -1;
    return systemBuilder.newFunctionBuilderWithSignature(
        name,
        function,
        // Parameter initializers are expressed in the potential
        // implementation.
        implementation.functionSignature,
        memberOf,
        kind: function.isAccessor
            ? DartinoFunctionKind.ACCESSOR
            : DartinoFunctionKind.NORMAL,
        mapByElement: function.declaration);
  }

  ClassDebugInfo createClassDebugInfo(DartinoClass klass) {
    return new ClassDebugInfo(klass);
  }

  DebugInfo createDebugInfo(
      DartinoFunction function,
      DartinoSystem currentSystem) {
    DebugInfo debugInfo = new DebugInfo(function);
    AstElement element = function.element;
    if (element == null) return debugInfo;
    List<Bytecode> expectedBytecodes = function.bytecodes;
    element = element.implementation;
    TreeElements elements;
    if (element.resolvedAst.kind == ResolvedAstKind.PARSED) {
      elements = element.resolvedAst.elements;
    }

    ClosureEnvironment closureEnvironment = createClosureEnvironment(
        element,
        elements);
    CodegenVisitor codegen;
    DartinoFunctionBuilder builder =
        new DartinoFunctionBuilder.fromDartinoFunction(function);
    if (function.isLazyFieldInitializer) {
      codegen = new DebugInfoLazyFieldInitializerCodegen(
          debugInfo,
          builder,
          context,
          elements,
          closureEnvironment,
          element,
          compiler);
    } else if (function.isInitializerList) {
      ClassElement enclosingClass = element.enclosingClass;
      DartinoClassBase classBase = systemBuilder.lookupClassByElement(
          enclosingClass.declaration);
      codegen = new DebugInfoConstructorCodegen(
          debugInfo,
          builder,
          context,
          elements,
          closureEnvironment,
          element,
          classBase,
          compiler);
    } else {
      codegen = new DebugInfoFunctionCodegen(
          debugInfo,
          builder,
          context,
          elements,
          closureEnvironment,
          element,
          compiler);
    }
    if (isNative(element)) {
      compiler.reporter.withCurrentElement(element, () {
        codegenNativeFunction(element, codegen);
      });
    } else if (isExternal(element)) {
      compiler.reporter.withCurrentElement(element, () {
        codegenExternalFunction(element, codegen);
      });
    } else {
      compiler.reporter.withCurrentElement(element, () { codegen.compile(); });
    }
    // The debug codegen should generate the same bytecodes as the original
    // codegen. If that is not the case debug information will be useless.
    if (!Bytecode.identicalBytecodes(expectedBytecodes,
                                     codegen.assembler.bytecodes)) {
      throw 'Debug info code different from running code.';
    }
    // The debug codegen should not modify the system builder.
    assert(!systemBuilder.hasChanges);
    return debugInfo;
  }

  codegen(_) {
    new UnsupportedError(
        "Method [codegen] not supported, use [compileElement] instead");
  }

  /// Invoked by [DartinoEnqueuer] once per element that needs to be compiled.
  ///
  /// This is used to generate the bytecodes for [declaration].
  void compileElement(
      AstElement declaration,
      TreeElements treeElements,
      DartinoRegistry registry) {
    AstElement element = declaration.implementation;
    compiler.reporter.withCurrentElement(element, () {
      assert(declaration.isDeclaration);
      context.compiler.reportVerboseInfo(element, 'Compiling $element');
      if (element.isFunction ||
          element.isGetter ||
          element.isSetter ||
          element.isGenerativeConstructor ||
          element.isFactoryConstructor) {
        // For a generative constructor, this means compile the constructor
        // body. See [compilePendingConstructorInitializers] for an overview of
        // how constructor initializers and constructor bodies are compiled.
        codegenFunction(element, treeElements, registry);
      } else if (element.isField) {
        context.compiler.reportVerboseInfo(
            element, "Asked to compile a field, but don't know how");
      } else {
        compiler.reporter.internalError(
            element, "Uninimplemented element kind: ${element.kind}");
      }
    });
  }

  /// Invoked by [DartinoEnqueuer] once per [selector] that may invoke
  /// [declaration].
  ///
  /// This is used to generate stubs for [declaration].
  void compileElementUsage(
      AstElement declaration,
      Selector selector,
      TreeElements treeElements,
      DartinoRegistry registry) {
    AstElement element = declaration.implementation;
    compiler.reporter.withCurrentElement(element, () {
      assert(declaration.isDeclaration);
      context.compiler.reportVerboseInfo(element, 'Compiling $element');
      if (!element.isInstanceMember && !isLocalFunction(element)) {
        // No stub needed. Optional arguments are handled at call-site.
      } else if (element.isFunction) {
        DartinoFunctionBase function =
            systemBuilder.lookupFunctionByElement(element.declaration);
        CallStructure callStructure = selector.callStructure;
        FunctionSignature signature = function.signature;
        if (selector.isGetter) {
          if (shouldReportEnqueuingOfElement(compiler, element)) {
            context.compiler.reportVerboseInfo(
                element, 'Adding tear-off stub');
          }
          createTearoffGetterForFunction(
              function, isSpecialCallMethod: element.name == "call");
        } else if (selector.isCall &&
                   callStructure.signatureApplies(signature) &&
                   !isExactParameterMatch(signature, callStructure)) {
          if (shouldReportEnqueuingOfElement(compiler, element)) {
            context.compiler.reportVerboseInfo(
                element, 'Adding stub for $selector');
          }
          DartinoFunctionBase stub =
              createParameterStub(function, selector, registry);
          patchClassWithStub(
              stub, selector, function.memberOf, isLocalFunction(element));
        }
      } else if (element.isGetter || element.isSetter) {
        // No stub needed. If a getter returns a closure, the VM's
        // no-such-method handling will do the right thing.
      } else {
        context.compiler.reportVerboseInfo(
            element, "Asked to compile this, but don't know how");
      }
    });
  }

  /// Invoked by [DartinoEnqueuer] once per `call` [selector] that may invoke
  /// [declaration] as an implicit closure (for example, a tear-off).
  ///
  /// This is used to generate parameter stubs for the closures.
  void compileClosurizationUsage(
      AstElement declaration,
      Selector selector,
      TreeElements treeElements,
      DartinoRegistry registry,
      ClosureKind kind) {
    AstElement element = declaration.implementation;
    compiler.reporter.withCurrentElement(element, () {
      assert(declaration.isDeclaration);
      if (shouldReportEnqueuingOfElement(compiler, element)) {
        context.compiler.reportVerboseInfo(
            element, 'Need tear-off parameter stub $selector');
      }
      DartinoFunctionBase function =
          systemBuilder.lookupFunctionByElement(element.declaration);
      if (function == null) {
        compiler.reporter.internalError(
            element, "Has no dartino function, but used as tear-off");
      }
      if (selector.isGetter) {
        // This is a special tear-off getter.

        // TODO(ahe): This code should probably use [kind] to detect the
        // various cases instead of [isLocalFunction] and looking at names.

        assert(selector.memberName == Names.CALL_NAME);
        if (isLocalFunction(element) ||
            memberName(element) == Names.CALL_NAME) {
          createTearoffGetterForFunction(
              function, isSpecialCallMethod: true);
          return;
        }
        int stub = systemBuilder.lookupTearOffById(function.functionId);
        if (stub == null) {
          compiler.reporter.internalError(
              element, "No tear-off stub to compile `call` tear-off");
        } else {
          function = systemBuilder.lookupFunction(stub);
          createTearoffGetterForFunction(function, isSpecialCallMethod: true);
          return;
        }
      }
      switch (kind) {
        case ClosureKind.tearOff:
        case ClosureKind.superTearOff:
          if (memberName(element) == Names.CALL_NAME) {
            // This is really a functionLikeTearOff.
            break;
          }
          // A tear-off has a corresponding stub in a closure class. Look up
          // that stub. If the function is a modification of a previous
          // function we find the stub through that.
          int stub = systemBuilder.lookupTearOffById(function.functionId);
          if (stub == null) {
            DartinoFunction predecessorFunction = systemBuilder.
                predecessorSystem.lookupFunctionByElement(function.element);
            stub =
                systemBuilder.lookupTearOffById(predecessorFunction.functionId);
          }
          if (stub == null) {
            compiler.reporter
                .internalError(element, "Couldn't find tear-off stub");
          } else {
            function = systemBuilder.lookupFunction(stub);
          }
          break;

        case ClosureKind.localFunction:
          // A local function already is a member of its closure class, and
          // doesn't have a stub.
          break;

        case ClosureKind.functionLike:
        case ClosureKind.functionLikeTearOff:
          compiler.reporter.internalError(element, "Unimplemented: $kind");
          break;
      }

      if (!isExactParameterMatch(function.signature, selector.callStructure)) {
        DartinoFunctionBase stub =
            createParameterStub(function, selector, registry);
        patchClassWithStub(stub, selector, function.memberOf, true);
      }
    });
  }

  void codegenFunction(
      FunctionElement function,
      TreeElements elements,
      DartinoRegistry registry) {
    registry.registerStaticInvocation(dartinoSystemEntry);

    ClosureEnvironment closureEnvironment = createClosureEnvironment(
        function,
        elements);

    DartinoFunctionBuilder functionBuilder;

    bool isImplicitFunction = false;
    if (function.memberContext != function) {
      functionBuilder = systemBuilder.lookupFunctionBuilderByElement(function);
      assert(functionBuilder != null);
      isImplicitFunction = true;
    } else {
      functionBuilder = createDartinoFunctionBuilder(function);
      isImplicitFunction = function.isInstanceMember &&
          function.isFunction && // Not accessors.
          function.name == Identifiers.call;
    }

    if (isImplicitFunction) {
      // If [function] is a closure, or an instance method named "call", its
      // class implicitly implements Function.
      DartinoClassBuilder classBuilder =
          systemBuilder.lookupClassBuilder(functionBuilder.memberOf);
      classBuilder.createIsFunctionEntry(
          compiler.coreClasses.functionClass,
          function.functionSignature.parameterCount);
    }

    FunctionCodegen codegen = new FunctionCodegen(
        functionBuilder,
        context,
        elements,
        registry,
        closureEnvironment,
        function);

    if (isNative(function)) {
      codegenNativeFunction(function, codegen);
    } else if (isExternal(function)) {
      codegenExternalFunction(function, codegen);
    } else {
      codegen.compile();
    }

    if (functionBuilder.isInstanceMember && !function.isGenerativeConstructor) {
      Name name = function is MethodElement
          ? function.memberName
          : new Name(functionBuilder.name, function.library);
      // Inject the function into the method table of the 'holderClass' class.
      // Note that while constructor bodies has a this argument, we don't inject
      // them into the method table.
      String symbol = systemBuilder.getSymbolForFunction(name,
          function.functionSignature);
      int id = systemBuilder.getSymbolId(symbol);
      int arity = function.functionSignature.parameterCount;
      SelectorKind kind = SelectorKind.Method;
      if (function.isGetter) kind = SelectorKind.Getter;
      if (function.isSetter) kind = SelectorKind.Setter;
      int dartinoSelector = DartinoSelector.encode(id, kind, arity);
      DartinoClassBuilder classBuilder =
          systemBuilder.lookupClassBuilder(functionBuilder.memberOf);
      classBuilder.addToMethodTable(dartinoSelector, functionBuilder);
      // Inject method into all mixin usages.
      getMixinApplicationsOfClass(classBuilder).forEach((ClassElement usage) {
        DartinoClassBuilder compiledUsage =
            systemBuilder.getClassBuilder(usage);
        compiledUsage.addToMethodTable(dartinoSelector, functionBuilder);
      });
    }

    if (compiler.options.verbose) {
      context.compiler.reportVerboseInfo(
          function, functionBuilder.verboseToString());
    }
  }

  List<ClassElement> getMixinApplicationsOfClass(DartinoClassBuilder builder) {
    ClassElement element = builder.element;
    if (element == null) return [];
    List<ClassElement> mixinUsage =
        compiler.world.mixinUsesOf(element).toList();
    for (int i = 0; i < mixinUsage.length; i++) {
      ClassElement usage = mixinUsage[i];
      // Recursively add mixin-usage of the current 'usage'.
      assert(!compiler.world.mixinUsesOf(usage).any(mixinUsage.contains));
      mixinUsage.addAll(compiler.world.mixinUsesOf(usage));
    }
    return mixinUsage;
  }

  void codegenNativeFunction(
      FunctionElement function,
      FunctionCodegenBase codegen) {
    String name = '.${function.name}';

    ClassElement enclosingClass = function.enclosingClass;
    if (enclosingClass != null) name = '${enclosingClass.name}$name';

    DartinoNativeDescriptor descriptor = context.nativeDescriptors[name];
    if (descriptor == null) {
      throw "Unsupported native function: $name";
    }

    if (name == "Coroutine._coroutineNewStack") {
      // The static native method `Coroutine._coroutineNewStack` will invoke
      // the instance method `Coroutine._coroutineStart`.
      if (coroutineClass == null) {
        compiler.reporter.internalError(
            function, "required class [Coroutine] not found");
      }
      FunctionElement coroutineStart =
          coroutineClass.lookupLocalMember("_coroutineStart");
      Selector selector = new Selector.fromElement(coroutineStart);
      new DartinoRegistry(compiler)
          ..registerDynamicSelector(selector);
    } else if (name == "Process._spawn") {
      // The native method `Process._spawn` will do a closure invoke with 0, 1,
      // or 2 arguments.
      new DartinoRegistry(compiler)
          ..registerDynamicSelector(new Selector.callClosure(0))
          ..registerDynamicSelector(new Selector.callClosure(1))
          ..registerDynamicSelector(new Selector.callClosure(2));
    }

    int arity = codegen.assembler.functionArity;
    if (name == "Port.send" ||
        name == "Port._sendList" ||
        name == "Port._sendExit") {
      codegen.assembler.invokeNativeYield(arity, descriptor.index);
    } else {
      if (descriptor.isLeaf) {
        codegen.assembler.invokeLeafNative(arity, descriptor.index);
      } else {
        codegen.assembler.invokeNative(arity, descriptor.index);
      }
    }

    EmptyStatement empty = function.node.body.asEmptyStatement();
    if (empty != null) {
      // A native method without a body.
      codegen.assembler
          ..emitThrow()
          ..methodEnd();
    } else {
      codegen.compile();
    }
  }

  void codegenExternalFunction(
      FunctionElement function,
      FunctionCodegenBase codegen) {
    if (function == dartinoExternalYield) {
      codegenExternalYield(function, codegen);
    } else if (function == context.compiler.identicalFunction.implementation) {
      codegenIdentical(function, codegen);
    } else if (function == dartinoExternalInvokeMain) {
      codegenExternalInvokeMain(function, codegen);
    } else if (function.name == noSuchMethodTrampolineName &&
               function.library == compiler.coreLibrary) {
      codegenExternalNoSuchMethodTrampoline(function, codegen);
    } else {
      DiagnosticMessage message = context.compiler.reporter
          .createMessage(function.node,
              MessageKind.GENERIC,
              {'text':
                  'External function "${function.name}" is not supported'});
      compiler.reporter.reportError(message);
      codegen
          ..doCompileError(message)
          ..assembler.ret()
          ..assembler.methodEnd();
    }
  }

  void codegenIdentical(
      FunctionElement function,
      FunctionCodegenBase codegen) {
    codegen.assembler
        ..loadParameter(0)
        ..loadParameter(1)
        ..identical()
        ..ret()
        ..methodEnd();
  }

  void codegenExternalYield(
      FunctionElement function,
      FunctionCodegenBase codegen) {
    codegen.assembler
        ..loadParameter(0)
        ..processYield()
        ..ret()
        ..methodEnd();
  }

  void codegenExternalInvokeMain(
      FunctionElement function,
      FunctionCodegenBase codegen) {
    compiler.reporter.internalError(
        function, "[codegenExternalInvokeMain] not implemented.");
    // TODO(ahe): This code shouldn't normally be called, only if invokeMain is
    // torn off. Perhaps we should just say we don't support that.
  }

  void codegenExternalNoSuchMethodTrampoline(
      FunctionElement function,
      FunctionCodegenBase codegen) {
    // NOTE: The number of arguments to the [noSuchMethodName] function must be
    // kept in sync with:
    //     src/vm/interpreter.cc:HandleEnterNoSuchMethod
    int id = systemBuilder.getSymbolId(
        systemBuilder.mangleName(
            new Name(noSuchMethodName, compiler.coreLibrary)));
    int dartinoSelector = DartinoSelector.encodeMethod(id, 3);
    BytecodeLabel skipGetter = new BytecodeLabel();
    codegen.assembler
        ..enterNoSuchMethod(skipGetter)
        // First invoke the getter.
        ..invokeSelector(2)
        // Then invoke 'call', with the receiver being the result of the
        // previous invokeSelector.
        ..invokeSelector(1)
        ..exitNoSuchMethod()
        ..bind(skipGetter)
        ..invokeMethod(dartinoSelector, 1)
        ..exitNoSuchMethod()
        ..methodEnd();
  }

  bool isNative(Element element) {
    if (element is FunctionElement) {
      for (var metadata in element.metadata) {
        // TODO(ahe): This code should ensure that @native resolves to precisely
        // the native variable in dart:dartino._system.
        if (metadata.constant == null) continue;
        ConstantValue value = context.getConstantValue(metadata.constant);
        if (!value.isString) continue;
        StringConstantValue stringValue = value;
        if (stringValue.toDartString().slowToString() != 'native') continue;
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
      ExecutableElement element,
      TreeElements elements) {
    MemberElement member = element.memberContext;
    return closureEnvironments.putIfAbsent(member, () {
      ClosureVisitor environment = new ClosureVisitor(member, elements);
      return environment.compute();
    });
  }

  void markFunctionConstantAsUsed(FunctionConstantValue value) {
    // TODO(ajohnsen): Use registry in CodegenVisitor to register the used
    // constants.
    FunctionElement function = value.element;
    getTearoffClass(createDartinoFunctionBuilder(function));
    // Be sure to actually enqueue the function for compilation.
    DartinoRegistry registry = new DartinoRegistry(compiler);
    registry.registerStaticInvocation(function);
  }

  DartinoFunctionBase createParameterStub(
      DartinoFunctionBase function,
      Selector selector,
      DartinoRegistry registry) {
    CallStructure callStructure = selector.callStructure;
    assert(callStructure.signatureApplies(function.signature));
    ParameterStubSignature signature = new ParameterStubSignature(
        function.functionId, callStructure);
    DartinoFunctionBase stub = systemBuilder.lookupParameterStub(signature);
    if (stub != null) return stub;

    int arity = selector.argumentCount;
    if (function.isInstanceMember) arity++;

    DartinoFunctionBuilder builder = systemBuilder.newFunctionBuilder(
        DartinoFunctionKind.PARAMETER_STUB,
        arity);

    new ParameterStubCodegen(
        builder, context, registry, function.element, function, selector,
        signature, arity).compile();

    return builder;
  }

  void patchClassWithStub(
      DartinoFunctionBase stub,
      Selector selector,
      int classId,
      bool isClosureClass) {
    int dartinoSelector = systemBuilder.toDartinoSelector(selector);
    DartinoClassBuilder classBuilder =
        systemBuilder.lookupClassBuilder(classId);
    if (classBuilder == null) {
      if (isClosureClass) {
        classBuilder = systemBuilder.newPatchClassBuilder(
            classId, compiledClosureClass, new SchemaChange(null));
      } else {
        DartinoClass klass = systemBuilder.lookupClassById(classId);
        assert(klass.element != null);
        classBuilder = systemBuilder.getClassBuilder(klass.element);
      }
    }
    classBuilder.addToMethodTable(dartinoSelector, stub);

    // Inject parameter stub into all mixin usages.
    getMixinApplicationsOfClass(classBuilder).forEach((ClassElement usage) {
      DartinoClassBuilder classBuilder =
          systemBuilder.lookupClassBuilderByElement(usage);
      classBuilder.addToMethodTable(dartinoSelector, stub);
    });
  }

  /// Create a tear-off getter for [function].  If [isSpecialCallMethod] is
  /// `true`, this is the special case for `someClosure.call` which should
  /// always return `someClosure`. This implies that when [isSpecialCallMethod]
  /// is true, we assume [function] is already a member of a closure class (or
  /// a class with a `call` method [ClosureKind.functionLike]) and that the
  /// getter should be added to that class.
  void createTearoffGetterForFunction(
      DartinoFunctionBase function,
      {bool isSpecialCallMethod}) {
    if (isSpecialCallMethod == null) {
      throw new ArgumentError("isSpecialCallMethod");
    }

    int id = systemBuilder.lookupTearOffGetterById(function.functionId);
    if (id != null) {
      // A tearoff getter for [funcion] has already been created.
      assert(systemBuilder.lookupFunction(id) != null);
      return;
    }

    DartinoFunctionBuilder getter = systemBuilder.newTearOffGetter(function);
    // If the getter is of 'call', return the instance instead.
    if (isSpecialCallMethod) {
      getter.assembler
          ..loadParameter(0)
          ..ret()
          ..methodEnd();
    } else {
      DartinoClassBase tearoffClass;
      DartinoFunction predecessorFunction = systemBuilder.predecessorSystem
          .lookupFunctionByElement(function.element);
      if (predecessorFunction != null) {
        DartinoClassBase predecessorTearoffClass =
            systemBuilder.lookupTearoffClass(predecessorFunction);
        if (predecessorTearoffClass != null) {
          // No need to create a new tear-off class. The call methods of the old
          // one will be updated.
          tearoffClass = predecessorTearoffClass;
        }
      }

      if (tearoffClass == null) {
        tearoffClass = getTearoffClass(function);
      }

      int constId = getter.allocateConstantFromClass(tearoffClass.classId);
      getter.assembler
          ..loadParameter(0)
          ..allocate(constId, tearoffClass.fieldCount)
          ..ret()
          ..methodEnd();
    }
    // If the name is private, we need the library.
    // Invariant: We only generate public stubs, e.g. 'call'.
    LibraryElement library;
    if (function.element != null) {
      library = function.element.library;
    }
    // TODO(sigurdm): Avoid allocating new Name and Selector here.
    Name name = new Name(function.name, library);
    int dartinoSelector = systemBuilder.toDartinoSelector(
        new Selector.getter(name));
    DartinoClassBuilder classBuilder = systemBuilder.lookupClassBuilder(
        function.memberOf);
    classBuilder.addToMethodTable(dartinoSelector, getter);

    // Inject getter into all mixin usages.
    getMixinApplicationsOfClass(classBuilder).forEach((ClassElement usage) {
      DartinoClassBuilder classBuilder =
          systemBuilder.lookupClassBuilderByElement(usage);
      classBuilder.addToMethodTable(dartinoSelector, getter);
    });
  }

  void compileTypeTest(ClassElement element, InterfaceType type) {
    assert(element.isDeclaration);
    int dartinoSelector = systemBuilder.toDartinoIsSelector(type.element);
    DartinoClassBuilder builder =
        systemBuilder.lookupClassBuilderByElement(element);
    if (builder != null) {
      context.compiler.reportVerboseInfo(
          element, 'Adding is-selector for $type');
      builder.addIsSelector(dartinoSelector);
    }
  }

  int assembleProgram() => 0;

  DartinoDelta computeDelta() {

    if (dartinoSystemLibrary == null && compiler.compilationFailed) {
      // TODO(ahe): Ensure dartinoSystemLibrary is not null.
      return null;
    }

    List<VmCommand> commands = <VmCommand>[
        const NewMap(MapId.methods),
        const NewMap(MapId.classes),
        const NewMap(MapId.constants),
    ];

    DartinoSystem predecessorSystem = systemBuilder.predecessorSystem;
    DartinoSystem system = systemBuilder.computeSystem(
        compiler.reporter, commands, compiler.compilationFailed,
        context.enableBigint, bigintClass, uint32DigitsClass);
    assert(
        system.computeSymbolicSystemInfo(compiler.libraryLoader.libraries) !=
        null);

    // Reset the current system builder.
    newSystemBuilder(system);

    // Set the entry point.
    commands.add(new PushFromMap(
        MapId.methods,
        system.lookupFunctionByElement(dartinoSystemEntry).functionId));
    commands.add(new SetEntryPoint());

    return new DartinoDelta(system, predecessorSystem, commands);
  }

  bool enableCodegenWithErrorsIfSupported(Spannable spannable) {
    return true;
  }

  bool enableDeferredLoadingIfSupported(Spannable spannable,
                                        Registry registry) {
    return false;
  }

  bool registerDeferredLoading(Spannable node, Registry registry) {
    compiler.reporter.reportWarningMessage(
        node,
        MessageKind.GENERIC,
        {'text': "Deferred loading is not supported."});
    return false;
  }

  bool get supportsReflection => false;

  // TODO(sigurdm): Support async/await on the mobile platform.
  bool get supportsAsyncAwait {
    return !compiler.options.platformConfigUri.path.contains("embedded");
  }

  Future onLibraryScanned(LibraryElement library, LibraryLoader loader) {
    if (library.isPlatformLibrary) {
      String path = library.canonicalUri.path;
      switch(path) {
        case 'dartino._system':
          dartinoSystemLibrary = library;
          break;
        case 'dartino.ffi':
          dartinoFFILibrary = library;
          break;
        case 'dartino.collection':
          collectionLibrary = library;
          break;
        case 'math':
          mathLibrary = library;
          break;
        case 'dartino':
          dartinoLibrary = library;
          break;
      }

      if (!library.isPatched) {
        // Apply patch, if any.
        Uri patchUri = compiler.resolvePatchUri(library.canonicalUri.path);
        if (patchUri != null) {
          return compiler.patchParser.patchLibrary(loader, patchUri, library);
        }
      }
    }
    return null;
  }

  bool isBackendLibrary(LibraryElement library) {
    return library == dartinoSystemLibrary;
  }

  /// Return non-null to enable patching. Possible return values are 'new' and
  /// 'old'. Referring to old and new emitter. Since the new emitter is the
  /// future, we assume 'old' will go away. So it seems the best option for
  /// Dartino is 'new'.
  String get patchVersion => 'new';

  FunctionElement resolveExternalFunction(FunctionElement element) {
    if (element.isPatched) {
      FunctionElementX patch = element.patch;
      compiler.reporter.withCurrentElement(patch, () {
        patch.parseNode(compiler.parsingContext);
        patch.computeType(compiler.resolution);
      });
      element = patch;
      // TODO(ahe): Don't use ensureResolved (fix TODO in isNative instead).
      element.metadata.forEach((m) => m.ensureResolved(compiler.resolution));
    } else if (element.library == dartinoSystemLibrary) {
      // Nothing needed for now.
    } else if (element.library == compiler.coreLibrary) {
      // Nothing needed for now.
    } else if (element.library == mathLibrary) {
      // Nothing needed for now.
    } else if (element.library == asyncLibrary) {
      // Nothing needed for now.
    } else if (element.library == dartinoLibrary) {
      // Nothing needed for now.
    } else if (externals.contains(element)) {
      // Nothing needed for now.
    } else {
      compiler.reporter.reportErrorMessage(
          element, MessageKind.PATCH_EXTERNAL_WITHOUT_IMPLEMENTATION);
    }
    return element;
  }

  int compileLazyFieldInitializer(
      FieldElement field,
      DartinoRegistry registry) {
    int index = systemBuilder.getStaticFieldIndex(field, null);

    if (field.initializer == null) return index;

    int functionId = systemBuilder.lookupLazyFieldInitializerByElement(field);
    if (functionId != null) return index;

    DartinoFunctionBuilder functionBuilder =
        systemBuilder.newLazyFieldInitializer(field);

    TreeElements elements = field.resolvedAst.elements;

    ClosureEnvironment closureEnvironment = createClosureEnvironment(
        field,
        elements);

    LazyFieldInitializerCodegen codegen = new LazyFieldInitializerCodegen(
        functionBuilder,
        context,
        elements,
        registry,
        closureEnvironment,
        field);

    codegen.compile();

    return index;
  }

  /// Compiles the initializer part of a constructor.
  ///
  /// See [compilePendingConstructorInitializers] for an overview of how
  /// constructor initializer and bodies are compiled.
  void compileConstructorInitializer(DartinoFunctionBuilder functionBuilder) {
    ConstructorElement constructor = functionBuilder.element;
    assert(constructor.isImplementation);
    compiler.reporter.withCurrentElement(constructor, () {
      assert(functionBuilder ==
          systemBuilder.lookupConstructorInitializerByElement(constructor));
      context.compiler.reportVerboseInfo(
          constructor, 'Compiling constructor initializer $constructor');

      TreeElements elements;
      // TODO(sigurdm): We should not create the `codegen` when
      // `kind != PARSED`.
      if (constructor.resolvedAst.kind == ResolvedAstKind.PARSED) {
        elements = constructor.resolvedAst.elements;
      }

      // TODO(ahe): We shouldn't create a registry, but we have to as long as
      // the enqueuer doesn't support elements with more than one compilation
      // artifact.
      DartinoRegistry registry = new DartinoRegistry(compiler);

      DartinoClassBuilder classBuilder =
          systemBuilder.getClassBuilder(constructor.enclosingClass.declaration);

      ClosureEnvironment closureEnvironment =
          createClosureEnvironment(constructor, elements);

      ConstructorCodegen codegen = new ConstructorCodegen(
          functionBuilder,
          context,
          elements,
          registry,
          closureEnvironment,
          constructor,
          classBuilder);

      codegen.compile();

      if (compiler.options.verbose) {
        context.compiler.reportVerboseInfo(
            constructor, functionBuilder.verboseToString());
      }
    });
  }

  void forEachSubclassOf(ClassElement cls, void f(ClassElement cls)) {
    Queue<ClassElement> queue = new Queue<ClassElement>();
    queue.add(cls);
    while (queue.isNotEmpty) {
      ClassElement cls = queue.removeFirst();
      if (compiler.world.isInstantiated(cls.declaration)) {
        queue.addAll(compiler.world.strictSubclassesOf(cls));
      }
      f(cls);
    }
  }

  void forgetElement(Element element) {
    // TODO(ahe): The front-end should remove the element from
    // elementsWithCompileTimeErrors.
    compiler.elementsWithCompileTimeErrors.remove(element);
    DartinoFunctionBase function =
        systemBuilder.lookupFunctionByElement(element);
    if (function == null) return;
    systemBuilder.forgetFunction(function);

    int tearOffGetter =
        systemBuilder.lookupTearOffGetterById(function.functionId);
    if (tearOffGetter != null) {
      DartinoFunctionBase getter = systemBuilder.lookupFunction(tearOffGetter);
      systemBuilder.forgetFunction(getter);
    }

    PersistentSet<DartinoFunctionBase> stubs =
        systemBuilder.lookupParameterStubsForFunction(function.functionId);
    if (stubs != null) {
      stubs.forEach((DartinoFunctionBase stub) {
        systemBuilder.forgetFunction(stub);
      });
    }
  }

  void removeFunction(FunctionElement element) {
    DartinoFunctionBase function =
        systemBuilder.lookupFunctionByElement(element);
    if (function == null) return;
    if (element.isInstanceMember) {
      ClassElement enclosingClass = element.enclosingClass;
      DartinoClassBuilder classBuilder =
          systemBuilder.getClassBuilder(enclosingClass);
      classBuilder.removeFromMethodTable(function);

      // Remove associated parameter stubs.
      PersistentSet<DartinoFunctionBase> stubs =
          systemBuilder.lookupParameterStubsForFunction(function.functionId);
      if (stubs != null) {
        stubs.forEach((DartinoFunctionBase stub) {
          classBuilder.removeFromMethodTable(stub);
          systemBuilder.forgetFunction(stub);
        });
      }

      // Remove tear-off getter.
      int tearOffGetter =
          systemBuilder.lookupTearOffGetterById(function.functionId);
      if (tearOffGetter != null) {
        DartinoFunctionBase getterFunction =
            systemBuilder.lookupFunction(tearOffGetter);
        systemBuilder.forgetFunction(getterFunction);
        classBuilder.removeFromMethodTable(getterFunction);
      }

      // Remove call method and stubs from tear-off closure class.
      int tearOffId = systemBuilder.lookupTearOffById(function.functionId);
      if (tearOffId != null) {
        DartinoFunctionBase tearOff = systemBuilder.lookupFunction(tearOffId);
        int classId = tearOff.memberOf;
        DartinoClassBuilder closureClassBuilder =
            systemBuilder.lookupClassBuilder(classId);
        if (closureClassBuilder == null) {
          closureClassBuilder = systemBuilder.newPatchClassBuilder(
              classId, compiledClosureClass, new SchemaChange(null));
        }
        closureClassBuilder.removeFromMethodTable(tearOff);
        systemBuilder.forgetFunction(tearOff);

        PersistentSet<DartinoFunctionBase> stubs =
            systemBuilder.lookupParameterStubsForFunction(tearOff.functionId);
        if (stubs != null) {
          stubs.forEach((DartinoFunctionBase stub) {
            closureClassBuilder.removeFromMethodTable(stub);
            systemBuilder.forgetFunction(stub);
          });
        }
      }
    }
  }

  /// Invoked during codegen enqueuing to compile constructor initializers.
  ///
  /// There's only one [Element] representing a constructor, but Dartino uses
  /// two different functions for implementing a constructor.
  ///
  /// The first function takes care of allocating the instance and initializing
  /// fields (called the constructor initializer), the other function
  /// implements the body of the constructor (what is between the curly
  /// braces). A constructor initializer never calls constructor initializers
  /// of a superclass. Instead field initializers from the superclass are
  /// inlined in the constructor initializer. The constructor initializer will
  /// call all the constructor bodies from superclasses in the correct order.
  ///
  /// The constructor bodies are basically special instance methods that can
  /// only be called from constructor initializers.  Unlike constructor bodies,
  /// we only need constructor initializer for classes that are directly
  /// instantiated (excluding, for example, abstract classes).
  ///
  /// Given this, we compile constructor bodies when the normal enqueuer tells
  /// us to compile a generative constructor (see [codegen]), and track
  /// constructor initializers in a separate queue.
  void compilePendingConstructorInitializers() {
    while (pendingConstructorInitializers.isNotEmpty) {
      compileConstructorInitializer(
          pendingConstructorInitializers.removeLast());
    }
  }

  bool onQueueEmpty(Enqueuer enqueuer, Iterable<ClassElement> recentClasses) {
    if (enqueuer is! ResolutionEnqueuer) {
      compilePendingConstructorInitializers();
    }
    return true;
  }

  DartinoEnqueueTask makeEnqueuer() => new DartinoEnqueueTask(compiler);

  static bool isExactParameterMatch(
      FunctionSignature signature,
      CallStructure callStructure) {
    if (!callStructure.signatureApplies(signature)) {
      return false;
    }
    if (!signature.hasOptionalParameters) {
      // There are no optional parameters, and the signature applies, so this
      // is an exact match.
      return true;
    }
    if (!signature.optionalParametersAreNamed) {
      // The optional parameters aren't named which means that they are
      // optional positional parameters. So we have an exact match if the
      // number of parameters matches the number of arguments.
      return callStructure.argumentCount == signature.parameterCount;
    }
    // Otherwise, the optional parameters are named, and we have an exact match
    // if the named arguments in the call occur in the same order as the
    // parameters in the signature.
    if (callStructure.namedArguments.length !=
        signature.optionalParameterCount) {
      return false;
    }
    int index = 0;
    for (var parameter in signature.orderedOptionalParameters) {
      if (parameter.name != callStructure.namedArguments[index++]) return false;
    }
    return true;
  }

  static DartinoBackend createInstance(DartinoCompilerImplementation compiler) {
    return new DartinoBackend(compiler);
  }

  Uri resolvePatchUri(String libraryName, Uri libraryRoot) {
    throw "Not implemented";
  }
}

class DartinoImpactTransformer extends ImpactTransformer {
  final DartinoBackend backend;

  DartinoImpactTransformer(this.backend);

  @override
  WorldImpact transformResolutionImpact(ResolutionImpact worldImpact) {
    TransformedWorldImpact transformed =
        new TransformedWorldImpact(worldImpact);

    bool anyChange = false;

    if (worldImpact.constSymbolNames.isNotEmpty) {
      ClassElement symbolClass =
          backend.compiler.coreClasses.symbolClass.declaration;
      transformed.registerTypeUse(
          new TypeUse.instantiation(symbolClass.rawType));
      transformed.registerStaticUse(
          new StaticUse.foreignUse(
              symbolClass.lookupConstructor("")));
      anyChange = true;
    }

    for (MapLiteralUse mapLiteralUse in worldImpact.mapLiterals) {
      if (mapLiteralUse.isConstant) continue;
      transformed.registerTypeUse(
          new TypeUse.instantiation(backend.mapImplementation.rawType));
      transformed.registerStaticUse(
          new StaticUse.constructorInvoke(
              backend.mapImplementation.lookupConstructor(""),
              CallStructure.NO_ARGS));
      anyChange = true;
    }
    return anyChange ? transformed : worldImpact;
  }

  @override
  transformCodegenImpact(impact) => throw "unimplemented";
}

bool isLocalFunction(Element element) {
  if (!element.isFunction) return false;
  if (element is ExecutableElement) {
    return element.memberContext != element;
  }
  return false;
}

Name memberName(AstElement element) {
  if (isLocalFunction(element)) return null;
  MemberElement member = element;
  return member.memberName;
}
