// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_backend;

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
    DartType,
    InterfaceType;

import 'package:compiler/src/tree/tree.dart' show
    DartString,
    EmptyStatement,
    Expression;

import 'package:compiler/src/elements/elements.dart' show
    AbstractFieldElement,
    AstElement,
    ClassElement,
    ConstructorElement,
    Element,
    ExecutableElement,
    FieldElement,
    FormalElement,
    FunctionElement,
    FunctionSignature,
    FunctionTypedElement,
    LibraryElement,
    MemberElement,
    Name,
    ParameterElement,
    PublicName;

import 'package:compiler/src/universe/selector.dart' show
    Selector;

import 'package:compiler/src/universe/use.dart' show
    DynamicUse,
    StaticUse,
    TypeUse,
    TypeUseKind;

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
    ConstructedConstantValue,
    FunctionConstantValue,
    ListConstantValue,
    MapConstantValue,
    StringConstantValue;

import 'package:compiler/src/constants/expressions.dart' show
    ConstantExpression;

import 'package:compiler/src/resolution/tree_elements.dart' show
    TreeElements;

import 'package:compiler/src/library_loader.dart' show
    LibraryLoader;

import 'package:persistent/persistent.dart' show
    PersistentMap;

import 'fletch_function_builder.dart' show
    FletchFunctionBuilder;

import 'fletch_class_builder.dart' show
    FletchClassBuilder;

import 'fletch_system_builder.dart' show
    FletchSystemBuilder;

import '../incremental_backend.dart' show
    IncrementalFletchBackend;

import 'fletch_enqueuer.dart' show
    FletchEnqueueTask,
    shouldReportEnqueuingOfElement;

import 'fletch_registry.dart' show
    ClosureKind,
    FletchRegistry;

import 'diagnostic.dart' show
   throwInternalError;

import 'package:compiler/src/common/names.dart' show
    Identifiers,
    Names;

import 'package:compiler/src/universe/world_impact.dart' show
    TransformedWorldImpact,
    WorldImpact,
    WorldImpactBuilder;

import 'class_debug_info.dart';
import 'codegen_visitor.dart';
import 'debug_info.dart';
import 'debug_info_constructor_codegen.dart';
import 'debug_info_function_codegen.dart';
import 'debug_info_lazy_field_initializer_codegen.dart';
import 'fletch_context.dart';
import 'fletch_selector.dart';
import 'function_codegen.dart';
import 'lazy_field_initializer_codegen.dart';
import 'constructor_codegen.dart';
import 'closure_environment.dart';

import '../bytecodes.dart';
import '../vm_commands.dart';
import '../fletch_system.dart';
import 'package:compiler/src/common/resolution.dart';

const FletchSystem BASE_FLETCH_SYSTEM = const FletchSystem(
    const PersistentMap<int, FletchFunction>(),
    const PersistentMap<Element, FletchFunction>(),
    const PersistentMap<ConstructorElement, FletchFunction>(),
    const PersistentMap<int, int>(),
    const PersistentMap<int, FletchClass>(),
    const PersistentMap<ClassElement, FletchClass>(),
    const PersistentMap<int, FletchConstant>(),
    const PersistentMap<ConstantValue, FletchConstant>(),
    const PersistentMap<int, String>(),
    const PersistentMap<int, int>(),
    const PersistentMap<int, int>(),
    const PersistentMap<ParameterStubSignature, FletchFunction>());

class FletchBackend extends Backend
    implements IncrementalFletchBackend {
  static const String growableListName = '_GrowableList';
  static const String constantListName = '_ConstantList';
  static const String constantByteListName = '_ConstantByteList';
  static const String constantMapName = '_ConstantMap';
  static const String fletchNoSuchMethodErrorName = 'FletchNoSuchMethodError';
  static const String noSuchMethodName = '_noSuchMethod';
  static const String noSuchMethodTrampolineName = '_noSuchMethodTrampoline';

  final FletchContext context;

  final DartConstantTask constantCompilerTask;

  /// Constructors that need to have an initilizer compiled. See
  /// [compilePendingConstructorInitializers].
  final Queue<FletchFunctionBuilder> pendingConstructorInitializers =
      new Queue<FletchFunctionBuilder>();

  final Set<FunctionElement> externals = new Set<FunctionElement>();

  // TODO(ahe): This should be queried from World.
  final Map<ClassElement, Set<ClassElement>> directSubclasses =
      <ClassElement, Set<ClassElement>>{};

  /// Set of classes that have special meaning to the Fletch VM. They're
  /// created using [PushBuiltinClass] instead of [PushNewClass].
  // TODO(ahe): Move this to FletchSystem?
  final Set<ClassElement> builtinClasses = new Set<ClassElement>();

  // TODO(ahe): This should be invalidated by a new [FletchSystem].
  final Map<MemberElement, ClosureEnvironment> closureEnvironments =
      <MemberElement, ClosureEnvironment>{};

  // TODO(ahe): This should be moved to [FletchSystem].
  final Map<FunctionElement, FletchClassBuilder> closureClasses =
      <FunctionElement, FletchClassBuilder>{};

  // TODO(ahe): This should be moved to [FletchSystem].
  final Map<FieldElement, FletchFunctionBuilder> lazyFieldInitializers =
      <FieldElement, FletchFunctionBuilder>{};

  // TODO(ahe): This should be moved to [FletchSystem].
  Map<FletchClassBuilder, FletchFunctionBuilder> tearoffFunctions;

  FletchCompilerImplementation get compiler => super.compiler;

  LibraryElement fletchSystemLibrary;
  LibraryElement fletchFFILibrary;
  LibraryElement collectionLibrary;
  LibraryElement mathLibrary;
  LibraryElement get asyncLibrary => compiler.asyncLibrary;
  LibraryElement fletchLibrary;

  FunctionElement fletchSystemEntry;

  FunctionElement fletchExternalInvokeMain;

  FunctionElement fletchExternalYield;

  FunctionElement fletchExternalNativeError;

  FunctionElement fletchExternalCoroutineChange;

  FunctionElement fletchUnresolved;
  FunctionElement fletchCompileError;

  FletchClassBuilder compiledObjectClass;

  ClassElement smiClass;
  ClassElement mintClass;
  ClassElement growableListClass;
  ClassElement fletchNoSuchMethodErrorClass;
  ClassElement bigintClass;
  ClassElement uint32DigitsClass;

  FletchClassBuilder compiledClosureClass;

  /// Holds a reference to the class Coroutine if it exists.
  ClassElement coroutineClass;

  FletchSystemBuilder systemBuilder;

  final Set<FunctionElement> alwaysEnqueue = new Set<FunctionElement>();

  FletchImpactTransformer impactTransformer;

  FletchBackend(FletchCompilerImplementation compiler)
      : this.context = compiler.context,
        this.constantCompilerTask = new DartConstantTask(compiler),
        this.systemBuilder = new FletchSystemBuilder(BASE_FLETCH_SYSTEM),
        super(compiler) {
    this.impactTransformer = new FletchImpactTransformer(this);
  }

  void newSystemBuilder(FletchSystem predecessorSystem) {
    systemBuilder = new FletchSystemBuilder(predecessorSystem);
  }

  // TODO(zarah): Move to FletchSystemBuilder.
  FletchClassBuilder getClassBuilderOfExistingClass(int id) {
    FletchClassBuilder classBuilder = systemBuilder.lookupClassBuilder(id);
    if (classBuilder != null) return classBuilder;
    FletchClass klass = systemBuilder.lookupClass(id);
    if (klass.element != null) return registerClassElement(klass.element);
    // [klass] is a tearoff class
    return systemBuilder.newPatchClassBuilder(id, compiledClosureClass);
  }

  FletchClassBuilder registerClassElement(ClassElement element) {
    if (element == null) return null;
    assert(element.isDeclaration);

    FletchClassBuilder classBuilder =
        systemBuilder.lookupClassBuilderByElement(element);
    if (classBuilder != null) return classBuilder;

    directSubclasses[element] = new Set<ClassElement>();
    FletchClassBuilder superclass = registerClassElement(element.superclass);
    if (superclass != null) {
      Set<ClassElement> subclasses = directSubclasses[element.superclass];
      subclasses.add(element);
    }
    classBuilder = systemBuilder.newClassBuilder(
        element, superclass, builtinClasses.contains(element));

    // TODO(ajohnsen): Currently, the FletchRegistry does not enqueue fields.
    // This is a workaround, where we basically add getters for all fields.
    classBuilder.updateImplicitAccessors(this);

    Element callMember = element.lookupLocalMember(Identifiers.call);
    if (callMember != null && callMember.isFunction) {
      FunctionElement function = callMember;
      classBuilder.createIsFunctionEntry(
          this, function.functionSignature.parameterCount);
    }
    return classBuilder;
  }

  FletchClassBuilder createCallableStubClass(
      int fields, int arity, FletchClassBuilder superclass) {
    FletchClassBuilder classBuilder = systemBuilder.newClassBuilder(
        null, superclass, false, extraFields: fields);
    classBuilder.createIsFunctionEntry(this, arity);
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
    FletchRegistry registry = new FletchRegistry(compiler);
    compiler.patchAnnotationClass = patchAnnotationClass;

    bool hasMissingHelpers = false;
    loadHelperMethods((String name) {
      LibraryElement library = fletchSystemLibrary;
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
        new StaticUse.staticInvoke(fletchCompileError, CallStructure.ONE_ARG));
    world.registerStaticUse(
        new StaticUse.staticInvoke(fletchSystemEntry, CallStructure.ONE_ARG));
    world.registerStaticUse(
        new StaticUse.staticInvoke(fletchUnresolved, CallStructure.ONE_ARG));

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
      if (builtin) builtinClasses.add(classImpl);
      {
        // TODO(ahe): Register in ResolutionCallbacks. The lines in this block
        // should not happen at this point in time.
        classImpl.ensureResolved(compiler.resolution);
        world.registerInstantiatedType(classImpl.rawType);
        // TODO(ahe): This is a hack to let both the world and the codegen know
        // about the instantiated type.
        registry.registerInstantiatedType(classImpl.rawType);
      }
      return registerClassElement(classImpl);
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
      builtinClasses.add(coroutineClass);
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

    fletchSystemEntry = findHelper('entry');
    fletchExternalInvokeMain = findExternal('invokeMain');
    fletchExternalYield = findExternal('yield');
    fletchExternalCoroutineChange = findExternal('coroutineChange');
    fletchExternalNativeError = findExternal('nativeError');
    fletchUnresolved = findExternal('unresolved');
    fletchCompileError = findExternal('compileError');
  }

  void loadHelperClasses(
      FletchClassBuilder loadClass(
          String name,
          LibraryElement library,
          {bool builtin})) {
    compiledObjectClass =
        loadClass("Object", compiler.coreLibrary, builtin: true);
    compiledClosureClass =
        loadClass("_TearOffClosure", compiler.coreLibrary, builtin: true);
    smiClass = loadClass("_Smi", compiler.coreLibrary, builtin: true)?.element;
    mintClass =
        loadClass("_Mint", compiler.coreLibrary, builtin: true)?.element;
    loadClass("_OneByteString", compiler.coreLibrary, builtin: true);
    loadClass("_TwoByteString", compiler.coreLibrary, builtin: true);
    // TODO(ahe): Register _ConstantList through ResolutionCallbacks.
    loadClass(constantListName, fletchSystemLibrary, builtin: true);
    loadClass(constantByteListName, fletchSystemLibrary, builtin: true);
    loadClass(constantMapName, fletchSystemLibrary, builtin: true);
    loadClass("_DoubleImpl", compiler.coreLibrary, builtin: true);
    loadClass("Null", compiler.coreLibrary, builtin: true);
    loadClass("bool", compiler.coreLibrary, builtin: true);
    loadClass("StackOverflowError", compiler.coreLibrary, builtin: true);
    loadClass("Port", fletchLibrary, builtin: true);
    loadClass("Process", fletchLibrary, builtin: true);
    loadClass("ProcessDeath", fletchLibrary, builtin: true);
    loadClass("ForeignMemory", fletchFFILibrary, builtin: true);
    if (context.enableBigint) {
      bigintClass = loadClass("_Bigint", compiler.coreLibrary)?.element;
      uint32DigitsClass =
          loadClass("_Uint32Digits", compiler.coreLibrary)?.element;
    }
    growableListClass =
        loadClass(growableListName, fletchSystemLibrary)?.element;
    fletchNoSuchMethodErrorClass =
        loadClass(fletchNoSuchMethodErrorName,
                  fletchSystemLibrary,
                  builtin: true)?.element;

    // This class is optional.
    coroutineClass = fletchSystemLibrary.implementation.find("Coroutine");
    if (coroutineClass != null) {
      coroutineClass.ensureResolved(compiler.resolution);
    }
  }

  void onElementResolved(Element element, TreeElements elements) {
    if (alwaysEnqueue.contains(element)) {
      var registry = new FletchRegistry(compiler);
      if (element.isStatic || element.isTopLevel) {
        registry.registerStaticUse(new StaticUse.foreignUse(element));
      } else {
        registry.registerDynamicUse(new Selector.fromElement(element));
      }
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
    // now, we simply put "const patch = "patch";" in fletch._system.
    return super.stringImplementation;
  }

  FletchClassBuilder createClosureClass(
      FunctionElement closure,
      ClosureEnvironment closureEnvironment) {
    return closureClasses.putIfAbsent(closure, () {
      ClosureInfo info = closureEnvironment.closures[closure];
      int fields = info.free.length;
      if (info.isThisFree) fields++;
      return createCallableStubClass(
          fields,
          closure.functionSignature.parameterCount,
          compiledClosureClass);
    });
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
  FletchClassBuilder createTearoffClass(FletchFunctionBase function) {
    FletchClassBuilder tearoffClass =
        systemBuilder.getTearoffClassBuilder(function, compiledClosureClass);
    if (tearoffClass != null) return tearoffClass;
    FunctionSignature signature = function.signature;
    bool hasThis = function.isInstanceMember;
    tearoffClass = createCallableStubClass(
        hasThis ? 1 : 0,
        signature.parameterCount,
        compiledClosureClass);

    FletchFunctionBuilder functionBuilder =
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

    String symbol = context.getCallSymbol(signature);
    int id = context.getSymbolId(symbol);
    int fletchSelector = FletchSelector.encodeMethod(
        id,
        signature.parameterCount);
    tearoffClass.addToMethodTable(fletchSelector, functionBuilder);

    if (!function.isInstanceMember) return tearoffClass;

    ClassElement classElement =
        systemBuilder.lookupClassBuilder(function.memberOf).element;
    if (classElement == null) return tearoffClass;

    // Create == function that tests for equality.
    int isSelector = context.toFletchTearoffIsSelector(
        function.name,
        classElement);
    tearoffClass.addIsSelector(isSelector);

    FletchFunctionBuilder equal = systemBuilder.newFunctionBuilder(
        FletchFunctionKind.NORMAL,
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

    id = context.getSymbolId("==");
    int equalsSelector = FletchSelector.encodeMethod(id, 1);
    tearoffClass.addToMethodTable(equalsSelector, equal);

    // Create hashCode getter. We simply add the object hashCode and the
    // method id of the tearoff'ed function.
    FletchFunctionBuilder hashCode = systemBuilder.newFunctionBuilder(
        FletchFunctionKind.ACCESSOR,
        1);

    int hashCodeSelector = FletchSelector.encodeGetter(
        context.getSymbolId("hashCode"));

    // TODO(ajohnsen): Use plus, we plus is always enqueued. Consider using
    // xor when we have a way to enqueue it from here.
    int plusSelector = FletchSelector.encodeMethod(
        context.getSymbolId("+"), 1);

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

  FletchFunctionBase getFunctionForElement(FunctionElement element) {
    assert(element.memberContext == element);

    FletchFunctionBase function =
        systemBuilder.lookupFunctionByElement(element);
    if (function != null) return function;

    return createFletchFunctionBuilder(element);
  }

  /// Get the constructor initializer function for [constructor]. The function
  /// will be created the first time it's called for [constructor].
  ///
  /// See [compilePendingConstructorInitializers] for an overview of
  /// constructor intializers and constructor bodies.
  FletchFunctionBase getConstructorInitializerFunction(
      ConstructorElement constructor) {
    assert(constructor.isDeclaration);
    constructor = constructor.implementation;
    FletchFunctionBase base =
        systemBuilder.lookupConstructorInitializerByElement(constructor);
    if (base != null) return base;

    FletchFunctionBuilder builder = systemBuilder.newConstructorInitializer(
        constructor);
    pendingConstructorInitializers.addFirst(builder);

    return builder;
  }

  FletchFunctionBuilder createFletchFunctionBuilder(FunctionElement function) {
    assert(function.memberContext == function);

    FletchClassBuilder holderClass;
    if (function.isInstanceMember || function.isGenerativeConstructor) {
      ClassElement enclosingClass = function.enclosingClass.declaration;
      holderClass = registerClassElement(enclosingClass);
    }
    return internalCreateFletchFunctionBuilder(
        function,
        function.name,
        holderClass);
  }

  FletchFunctionBuilder internalCreateFletchFunctionBuilder(
      FunctionElement function,
      String name,
      FletchClassBuilder holderClass) {
    FletchFunctionBuilder functionBuilder =
        systemBuilder.lookupFunctionBuilderByElement(function.declaration);
    if (functionBuilder != null) return functionBuilder;

    FunctionTypedElement implementation = function.implementation;
    int memberOf = holderClass != null ? holderClass.classId : null;
    return systemBuilder.newFunctionBuilderWithSignature(
        name,
        function,
        // Parameter initializers are expressed in the potential
        // implementation.
        implementation.functionSignature,
        memberOf,
        kind: function.isAccessor
            ? FletchFunctionKind.ACCESSOR
            : FletchFunctionKind.NORMAL,
        mapByElement: function.declaration);
  }

  ClassDebugInfo createClassDebugInfo(FletchClass klass) {
    return new ClassDebugInfo(klass);
  }

  DebugInfo createDebugInfo(
      FletchFunction function,
      FletchSystem currentSystem) {
    DebugInfo debugInfo = new DebugInfo(function);
    AstElement element = function.element;
    if (element == null) return debugInfo;
    List<Bytecode> expectedBytecodes = function.bytecodes;
    element = element.implementation;
    TreeElements elements = element.resolvedAst.elements;
    ClosureEnvironment closureEnvironment = createClosureEnvironment(
        element,
        elements);
    CodegenVisitor codegen;
    FletchFunctionBuilder builder =
        new FletchFunctionBuilder.fromFletchFunction(function);
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
      // TODO(ajohnsen): Don't depend on the class builder.
      FletchClassBuilder classBuilder =
          systemBuilder.lookupClassBuilderByElement(enclosingClass.declaration);
      codegen = new DebugInfoConstructorCodegen(
          debugInfo,
          builder,
          context,
          elements,
          closureEnvironment,
          element,
          classBuilder,
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
    return debugInfo;
  }

  codegen(_) {
    new UnsupportedError(
        "Method [codegen] not supported, use [compileElement] instead");
  }

  /// Invoked by [FletchEnqueuer] once per element that needs to be compiled.
  ///
  /// This is used to generate the bytecodes for [declaration].
  void compileElement(
      AstElement declaration,
      TreeElements treeElements,
      FletchRegistry registry) {
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

  /// Invoked by [FletchEnqueuer] once per [selector] that may invoke
  /// [declaration].
  ///
  /// This is used to generate stubs for [declaration].
  void compileElementUsage(
      AstElement declaration,
      Selector selector,
      TreeElements treeElements,
      FletchRegistry registry) {
    AstElement element = declaration.implementation;
    compiler.reporter.withCurrentElement(element, () {
      assert(declaration.isDeclaration);
      context.compiler.reportVerboseInfo(element, 'Compiling $element');
      if (!element.isInstanceMember && !isLocalFunction(element)) {
        // No stub needed. Optional arguments are handled at call-site.
      } else if (element.isFunction) {
        FletchFunctionBase function =
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
          createParameterStub(function, selector);
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

  /// Invoked by [FletchEnqueuer] once per `call` [selector] that may invoke
  /// [declaration] as an implicit closure (for example, a tear-off).
  ///
  /// This is used to generate parameter stubs for the closures.
  void compileClosurizationUsage(
      AstElement declaration,
      Selector selector,
      TreeElements treeElements,
      FletchRegistry registry,
      ClosureKind kind) {
    AstElement element = declaration.implementation;
    compiler.reporter.withCurrentElement(element, () {
      assert(declaration.isDeclaration);
      if (shouldReportEnqueuingOfElement(compiler, element)) {
        context.compiler.reportVerboseInfo(
            element, 'Need tear-off parameter stub $selector');
      }
      FletchFunctionBase function =
          systemBuilder.lookupFunctionByElement(element.declaration);
      if (function == null) {
        compiler.reporter.internalError(
            element, "Has no fletch function, but used as tear-off");
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
          // that stub:
          int stub = systemBuilder.lookupTearOffById(function.functionId);
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
        createParameterStub(function, selector);
      }
    });
  }

  void codegenFunction(
      FunctionElement function,
      TreeElements elements,
      FletchRegistry registry) {
    registry.registerStaticUse(new StaticUse.foreignUse(fletchSystemEntry));

    ClosureEnvironment closureEnvironment = createClosureEnvironment(
        function,
        elements);

    FletchFunctionBuilder functionBuilder;

    if (function.memberContext != function) {
      functionBuilder = internalCreateFletchFunctionBuilder(
          function,
          Identifiers.call,
          createClosureClass(function, closureEnvironment));
    } else {
      functionBuilder = createFletchFunctionBuilder(function);
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
      // Inject the function into the method table of the 'holderClass' class.
      // Note that while constructor bodies has a this argument, we don't inject
      // them into the method table.
      String symbol = context.getSymbolForFunction(
          functionBuilder.name,
          function.functionSignature,
          function.library);
      int id = context.getSymbolId(symbol);
      int arity = function.functionSignature.parameterCount;
      SelectorKind kind = SelectorKind.Method;
      if (function.isGetter) kind = SelectorKind.Getter;
      if (function.isSetter) kind = SelectorKind.Setter;
      int fletchSelector = FletchSelector.encode(id, kind, arity);
      FletchClassBuilder classBuilder =
          systemBuilder.lookupClassBuilder(functionBuilder.memberOf);
      classBuilder.addToMethodTable(fletchSelector, functionBuilder);
      // Inject method into all mixin usages.
      getMixinApplicationsOfClass(classBuilder).forEach((ClassElement usage) {
        FletchClassBuilder compiledUsage = registerClassElement(usage);
        compiledUsage.addToMethodTable(fletchSelector, functionBuilder);
      });
    }

    if (compiler.verbose) {
      context.compiler.reportVerboseInfo(
          function, functionBuilder.verboseToString());
    }
  }

  List<ClassElement> getMixinApplicationsOfClass(FletchClassBuilder builder) {
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
      FunctionCodegen codegen) {
    String name = '.${function.name}';

    ClassElement enclosingClass = function.enclosingClass;
    if (enclosingClass != null) name = '${enclosingClass.name}$name';

    FletchNativeDescriptor descriptor = context.nativeDescriptors[name];
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
      new FletchRegistry(compiler)
          ..registerDynamicUse(selector);
    } else if (name == "Process._spawn") {
      // The native method `Process._spawn` will do a closure invoke with 0, 1,
      // or 2 arguments.
      new FletchRegistry(compiler)
          ..registerDynamicUse(new Selector.callClosure(0))
          ..registerDynamicUse(new Selector.callClosure(1))
          ..registerDynamicUse(new Selector.callClosure(2));
    }

    int arity = codegen.assembler.functionArity;
    if (name == "Port.send" ||
        name == "Port._sendList" ||
        name == "Port._sendExit") {
      codegen.assembler.invokeNativeYield(arity, descriptor.index);
    } else {
      if (descriptor.isDetachable) {
        codegen.assembler.invokeDetachableNative(arity, descriptor.index);
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
      FunctionCodegen codegen) {
    if (function == fletchExternalYield) {
      codegenExternalYield(function, codegen);
    } else if (function == context.compiler.identicalFunction.implementation) {
      codegenIdentical(function, codegen);
    } else if (function == fletchExternalInvokeMain) {
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
      FunctionCodegen codegen) {
    codegen.assembler
        ..loadParameter(0)
        ..loadParameter(1)
        ..identical()
        ..ret()
        ..methodEnd();
  }

  void codegenExternalYield(
      FunctionElement function,
      FunctionCodegen codegen) {
    codegen.assembler
        ..loadParameter(0)
        ..processYield()
        ..ret()
        ..methodEnd();
  }

  void codegenExternalInvokeMain(
      FunctionElement function,
      FunctionCodegen codegen) {
    compiler.reporter.internalError(
        function, "[codegenExternalInvokeMain] not implemented.");
    // TODO(ahe): This code shouldn't normally be called, only if invokeMain is
    // torn off. Perhaps we should just say we don't support that.
  }

  void codegenExternalNoSuchMethodTrampoline(
      FunctionElement function,
      FunctionCodegen codegen) {
    // NOTE: The number of arguments to the [noSuchMethodName] function must be
    // kept in sync with:
    //     src/vm/interpreter.cc:HandleEnterNoSuchMethod
    int id = context.getSymbolId(
        context.mangleName(new Name(noSuchMethodName, compiler.coreLibrary)));
    int fletchSelector = FletchSelector.encodeMethod(id, 3);
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
        ..invokeMethod(fletchSelector, 1)
        ..exitNoSuchMethod()
        ..methodEnd();
  }

  bool isNative(Element element) {
    if (element is FunctionElement) {
      for (var metadata in element.metadata) {
        // TODO(ahe): This code should ensure that @native resolves to precisely
        // the native variable in dart:fletch._system.
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
    createTearoffClass(createFletchFunctionBuilder(function));
    // Be sure to actually enqueue the function for compilation.
    FletchRegistry registry = new FletchRegistry(compiler);
    registry.registerStaticUse(new StaticUse.foreignUse(function));
  }

  FletchFunctionBase createParameterStub(
      FletchFunctionBase function,
      Selector selector) {
    CallStructure callStructure = selector.callStructure;
    assert(callStructure.signatureApplies(function.signature));
    ParameterStubSignature signature = new ParameterStubSignature(
        function.functionId, callStructure);
    FletchFunctionBase stub = systemBuilder.lookupParameterStub(signature);
    if (stub != null) return stub;

    int arity = selector.argumentCount;
    if (function.isInstanceMember) arity++;

    FletchFunctionBuilder builder = systemBuilder.newFunctionBuilder(
        FletchFunctionKind.PARAMETER_STUB,
        arity);

    BytecodeAssembler assembler = builder.assembler;

    void loadInitializerOrNull(ParameterElement parameter) {
      Expression initializer = parameter.initializer;
      if (initializer != null) {
        ConstantExpression expression = context.compileConstant(
            initializer,
            parameter.memberContext.resolvedAst.elements,
            isConst: true);
        int constId = builder.allocateConstant(
            context.getConstantValue(expression));
        assembler.loadConst(constId);
      } else {
        assembler.loadLiteralNull();
      }
    }

    // Load this.
    if (function.isInstanceMember) assembler.loadParameter(0);

    int index = function.isInstanceMember ? 1 : 0;
    function.signature.orderedForEachParameter((ParameterElement parameter) {
      if (!parameter.isOptional) {
        assembler.loadParameter(index);
      } else if (parameter.isNamed) {
        int parameterIndex = selector.namedArguments.indexOf(parameter.name);
        if (parameterIndex >= 0) {
          if (function.isInstanceMember) parameterIndex++;
          int position = selector.positionalArgumentCount + parameterIndex;
          assembler.loadParameter(position);
        } else {
          loadInitializerOrNull(parameter);
        }
      } else {
        if (index < arity) {
          assembler.loadParameter(index);
        } else {
          loadInitializerOrNull(parameter);
        }
      }
      index++;
    });

    // TODO(ajohnsen): We have to be extra careful when overriding a
    // method that takes optional arguments. We really should
    // enumerate all the stubs in the superclasses and make sure
    // they're overridden.
    int constId = builder.allocateConstantFromFunction(function.functionId);
    assembler
        ..invokeStatic(constId, index)
        ..ret()
        ..methodEnd();

    if (function.isInstanceMember) {
      int fletchSelector = context.toFletchSelector(selector);
      FletchClassBuilder classBuilder = getClassBuilderOfExistingClass(function.memberOf);
      classBuilder.addToMethodTable(fletchSelector, builder);

      // Inject parameter stub into all mixin usages.
      getMixinApplicationsOfClass(classBuilder).forEach((ClassElement usage) {
        FletchClassBuilder classBuilder =
            systemBuilder.lookupClassBuilderByElement(usage);
        classBuilder.addToMethodTable(fletchSelector, builder);
      });
    }

    systemBuilder.registerParameterStub(signature, builder);

    return builder;
  }

  /// Create a tear-off getter for [function].  If [isSpecialCallMethod] is
  /// `true`, this is the special case for `someClosure.call` which should
  /// always return `someClosure`. This implies that when [isSpecialCallMethod]
  /// is true, we assume [function] is already a member of a closure class (or
  /// a class with a `call` method [ClosureKind.functionLike]) and that the
  /// getter should be added to that class.
  void createTearoffGetterForFunction(
      FletchFunctionBuilder function,
      {bool isSpecialCallMethod}) {
    if (isSpecialCallMethod == null) {
      throw new ArgumentError("isSpecialCallMethod");
    }
    FletchFunctionBuilder getter = systemBuilder.newFunctionBuilder(
        FletchFunctionKind.ACCESSOR,
        1);
    // If the getter is of 'call', return the instance instead.
    if (isSpecialCallMethod) {
      getter.assembler
          ..loadParameter(0)
          ..ret()
          ..methodEnd();
    } else {
      FletchClassBuilder tearoffClass = createTearoffClass(function);
      int constId = getter.allocateConstantFromClass(tearoffClass.classId);
      getter.assembler
          ..loadParameter(0)
          ..allocate(constId, tearoffClass.fields)
          ..ret()
          ..methodEnd();
    }
    // If the name is private, we need the library.
    // Invariant: We only generate public stubs, e.g. 'call'.
    LibraryElement library;
    if (function.element != null) {
      library = function.element.library;
    }
    // TODO(sigurdm): Avoid allocating new name here.
    Name name = new Name(function.name, library);
    int fletchSelector = context.toFletchSelector(
        new Selector.getter(name));
    FletchClassBuilder classBuilder = systemBuilder.lookupClassBuilder(
        function.memberOf);
    classBuilder.addToMethodTable(fletchSelector, getter);

    // Inject getter into all mixin usages.
    getMixinApplicationsOfClass(classBuilder).forEach((ClassElement usage) {
      FletchClassBuilder classBuilder =
          systemBuilder.lookupClassBuilderByElement(usage);
      classBuilder.addToMethodTable(fletchSelector, getter);
    });
  }

  void compileTypeTest(ClassElement element, InterfaceType type) {
    assert(element.isDeclaration);
    int fletchSelector = context.toFletchIsSelector(type.element);
    FletchClassBuilder builder =
        systemBuilder.lookupClassBuilderByElement(element);
    if (builder != null) {
      context.compiler.reportVerboseInfo(
          element, 'Adding is-selector for $type');
      builder.addIsSelector(fletchSelector);
    }
  }

  int assembleProgram() => 0;

  FletchDelta computeDelta() {

    if (fletchSystemLibrary == null && compiler.compilationFailed) {
      // TODO(ahe): Ensure fletchSystemLibrary is not null.
      return null;
    }

    List<VmCommand> commands = <VmCommand>[
        const NewMap(MapId.methods),
        const NewMap(MapId.classes),
        const NewMap(MapId.constants),
    ];

    FletchSystem system = systemBuilder.computeSystem(context, commands);

    commands.add(const PushNewInteger(0));
    commands.add(new PushFromMap(
        MapId.methods,
        system.lookupFunctionByElement(fletchSystemEntry).functionId));

    return new FletchDelta(system, systemBuilder.predecessorSystem, commands);
  }

  bool enableCodegenWithErrorsIfSupported(Spannable spannable) {
    return true;
  }

  bool enableDeferredLoadingIfSupported(Spannable spannable, Registry registry) {
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
    return !compiler.platformConfigUri.path.contains("embedded");
  }

  Future onLibraryScanned(LibraryElement library, LibraryLoader loader) {
    if (library.isPlatformLibrary) {
      String path = library.canonicalUri.path;
      switch(path) {
        case 'fletch._system':
          fletchSystemLibrary = library;
          break;
        case 'fletch.ffi':
          fletchFFILibrary = library;
          break;
        case 'fletch.collection':
          collectionLibrary = library;
          break;
        case 'math':
          mathLibrary = library;
          break;
        case 'fletch':
          fletchLibrary = library;
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
      compiler.reporter.withCurrentElement(patch, () {
        patch.parseNode(compiler.parsing);
        patch.computeType(compiler.resolution);
      });
      element = patch;
      // TODO(ahe): Don't use ensureResolved (fix TODO in isNative instead).
      element.metadata.forEach((m) => m.ensureResolved(compiler.resolution));
    } else if (element.library == fletchSystemLibrary) {
      // Nothing needed for now.
    } else if (element.library == compiler.coreLibrary) {
      // Nothing needed for now.
    } else if (element.library == mathLibrary) {
      // Nothing needed for now.
    } else if (element.library == asyncLibrary) {
      // Nothing needed for now.
    } else if (element.library == fletchLibrary) {
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
      FletchRegistry registry) {
    int index = context.getStaticFieldIndex(field, null);

    if (field.initializer == null) return index;

    if (lazyFieldInitializers.containsKey(field)) return index;

    FletchFunctionBuilder functionBuilder = systemBuilder.newFunctionBuilder(
        FletchFunctionKind.LAZY_FIELD_INITIALIZER,
        0,
        name: "${field.name} lazy initializer",
        element: field);
    lazyFieldInitializers[field] = functionBuilder;

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
  void compileConstructorInitializer(FletchFunctionBuilder functionBuilder) {
    ConstructorElement constructor = functionBuilder.element;
    assert(constructor.isImplementation);
    compiler.reporter.withCurrentElement(constructor, () {
      assert(functionBuilder ==
          systemBuilder.lookupConstructorInitializerByElement(constructor));
      context.compiler.reportVerboseInfo(
          constructor, 'Compiling constructor initializer $constructor');

      TreeElements elements = constructor.resolvedAst.elements;

      // TODO(ahe): We shouldn't create a registry, but we have to as long as
      // the enqueuer doesn't support elements with more than one compilation
      // artifact.
      FletchRegistry registry = new FletchRegistry(compiler);

      FletchClassBuilder classBuilder =
          registerClassElement(constructor.enclosingClass.declaration);

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

      if (compiler.verbose) {
        context.compiler.reportVerboseInfo(
            constructor, functionBuilder.verboseToString());
      }
    });
  }

  /**
   * Generate a getter for field [fieldIndex].
   */
  int makeGetter(int fieldIndex) {
    return systemBuilder.getGetterByFieldIndex(fieldIndex);
  }

  /**
   * Generate a setter for field [fieldIndex].
   */
  int makeSetter(int fieldIndex) {
    return systemBuilder.getSetterByFieldIndex(fieldIndex);
  }

  void generateUnimplementedError(
      Spannable spannable,
      String reason,
      FletchFunctionBuilder function,
      {bool suppressHint: false}) {
    if (!suppressHint) {
      compiler.reporter.reportHintMessage(
          spannable, MessageKind.GENERIC, {'text': reason});
    }
    var constString = constantSystem.createString(
        new DartString.literal(reason));
    context.markConstantUsed(constString);
    function
        ..assembler.loadConst(function.allocateConstant(constString))
        ..assembler.emitThrow();
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

  void newElement(Element element) {
    if (element.isField && element.isInstanceMember) {
      forEachSubclassOf(element.enclosingClass, (ClassElement cls) {
        FletchClassBuilder builder = registerClassElement(cls);
        builder.addField(element);
      });
    }
  }

  void replaceFunctionUsageElement(Element element, List<Element> users) {
    for (Element user in users) {
      systemBuilder.replaceUsage(user, element);
    }
  }

  void forgetElement(Element element) {
    // TODO(ahe): The front-end should remove the element from
    // elementsWithCompileTimeErrors.
    compiler.elementsWithCompileTimeErrors.remove(element);
    FletchFunctionBase function =
        systemBuilder.lookupFunctionByElement(element);
    if (function == null) return;
    systemBuilder.forgetFunction(function);
  }

  void removeField(FieldElement element) {
    if (!element.isInstanceMember) return;
    ClassElement enclosingClass = element.enclosingClass;
    forEachSubclassOf(enclosingClass, (ClassElement cls) {
      FletchClassBuilder builder = registerClassElement(cls);
      builder.removeField(element);
    });
  }

  void removeFunction(FunctionElement element) {
    FletchFunctionBase function =
        systemBuilder.lookupFunctionByElement(element);
    if (function == null) return;
    if (element.isInstanceMember) {
      ClassElement enclosingClass = element.enclosingClass;
      FletchClassBuilder builder = registerClassElement(enclosingClass);
      builder.removeFromMethodTable(function);
    }
  }

  /// Invoked during codegen enqueuing to compile constructor initializers.
  ///
  /// There's only one [Element] representing a constructor, but Fletch uses
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

  FletchEnqueueTask makeEnqueuer() => new FletchEnqueueTask(compiler);

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

  static FletchBackend createInstance(FletchCompilerImplementation compiler) {
    return new FletchBackend(compiler);
  }

  Uri resolvePatchUri(String libraryName, Uri libraryRoot) {
    throw "Not implemented";
  }

}

class FletchImpactTransformer extends ImpactTransformer {
  final FletchBackend backend;

  FletchImpactTransformer(this.backend);

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
