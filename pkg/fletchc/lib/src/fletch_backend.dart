// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_backend;

import 'dart:async' show
    Future;

import 'package:compiler/src/dart2jslib.dart' show
    Backend,
    BackendConstantEnvironment,
    CodegenRegistry,
    CodegenWorkItem,
    Compiler,
    CompilerTask,
    ConstantCompilerTask,
    Enqueuer,
    MessageKind,
    Registry,
    ResolutionEnqueuer,
    WorldImpact,
    isPrivateName;

import 'package:compiler/src/tree/tree.dart' show
    DartString,
    EmptyStatement,
    Expression;

import 'package:compiler/src/elements/elements.dart' show
    AstElement,
    AbstractFieldElement,
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
    ParameterElement;

import 'package:compiler/src/universe/universe.dart' show
    CallStructure,
    Selector,
    UniverseSelector;

import 'package:compiler/src/util/util.dart' show
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

import 'package:compiler/src/resolution/resolution.dart' show
    TreeElements;

import 'package:compiler/src/library_loader.dart' show
    LibraryLoader;

import 'package:persistent/persistent.dart' show
    PersistentMap;

import 'fletch_constants.dart' show
    FletchClassConstant,
    FletchFunctionConstant,
    FletchClassInstanceConstant;

import 'fletch_function_builder.dart' show
    FletchFunctionKind,
    FletchFunctionBuilder,
    DebugInfo;

import 'fletch_class_builder.dart' show
    FletchClassBuilder;

import 'fletch_system_builder.dart' show
    FletchSystemBuilder;

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
import '../commands.dart';
import '../fletch_system.dart';

const FletchSystem BASE_FLETCH_SYSTEM = const FletchSystem(
    const PersistentMap<int, FletchFunction>(),
    const PersistentMap<Element, FletchFunction>(),
    const PersistentMap<int, FletchClass>(),
    const PersistentMap<ClassElement, FletchClass>(),
    const <FletchConstant>[]);

class FletchBackend extends Backend {
  static const String growableListName = '_GrowableList';
  static const String constantListName = '_ConstantList';
  static const String constantMapName = '_ConstantMap';
  static const String linkedHashMapName = '_CompactLinkedHashMap';
  static const String noSuchMethodName = '_noSuchMethod';
  static const String noSuchMethodTrampolineName = '_noSuchMethodTrampoline';

  final FletchContext context;

  final DartConstantTask constantCompilerTask;

  final Map<ConstructorElement, FletchFunctionBuilder> constructors =
      <ConstructorElement, FletchFunctionBuilder>{};

  final Set<FunctionElement> externals = new Set<FunctionElement>();

  final Map<ClassElement, Set<ClassElement>> directSubclasses =
      <ClassElement, Set<ClassElement>>{};

  final Set<ClassElement> builtinClasses = new Set<ClassElement>();

  final Map<MemberElement, ClosureEnvironment> closureEnvironments =
      <MemberElement, ClosureEnvironment>{};

  final Map<FunctionElement, FletchClassBuilder> closureClasses =
      <FunctionElement, FletchClassBuilder>{};

  final Map<FieldElement, FletchFunctionBuilder> lazyFieldInitializers =
      <FieldElement, FletchFunctionBuilder>{};

  final Map<FletchFunctionBase, FletchClassBuilder> tearoffClasses =
      <FletchFunctionBase, FletchClassBuilder>{};

  final Map<int, int> getters = <int, int>{};
  final Map<int, int> setters = <int, int>{};

  Map<FletchClassBuilder, FletchFunctionBuilder> tearoffFunctions;

  LibraryElement fletchSystemLibrary;
  LibraryElement fletchFFILibrary;
  LibraryElement fletchIOSystemLibrary;
  LibraryElement collectionLibrary;
  LibraryElement mathLibrary;
  LibraryElement asyncLibrary;
  LibraryElement fletchLibrary;

  FunctionElement fletchSystemEntry;

  FunctionElement fletchExternalInvokeMain;

  FunctionElement fletchExternalYield;

  FunctionElement fletchExternalNativeError;

  FunctionElement fletchExternalCoroutineChange;

  FunctionElement fletchUnresolved;
  FunctionElement fletchCompileError;

  FletchClassBuilder compiledObjectClass;

  ClassElement stringClass;
  ClassElement smiClass;
  ClassElement mintClass;
  ClassElement growableListClass;
  ClassElement linkedHashMapClass;
  ClassElement coroutineClass;

  FletchSystemBuilder systemBuilder;

  final Set<FunctionElement> alwaysEnqueue = new Set<FunctionElement>();

  FletchBackend(FletchCompiler compiler)
      : this.context = compiler.context,
        this.constantCompilerTask = new DartConstantTask(compiler),
        this.systemBuilder = new FletchSystemBuilder(BASE_FLETCH_SYSTEM),
        super(compiler) {
    context.resolutionCallbacks = new FletchResolutionCallbacks(context);
  }

  void newSystemBuilder(FletchSystem predecessorSystem) {
    systemBuilder = new FletchSystemBuilder(predecessorSystem);
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

    // TODO(ajohnsen): Currently, the CodegenRegistry does not enqueue fields.
    // This is a workaround, where we basically add getters for all fields.
    classBuilder.createImplicitAccessors(this);

    Element callMember = element.lookupLocalMember(
        Compiler.CALL_OPERATOR_NAME);
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
      CodegenRegistry registry) {
    compiler.patchAnnotationClass = patchAnnotationClass;

    FunctionElement findHelper(String name, [LibraryElement library]) {
      if (library == null) library = fletchSystemLibrary;
      Element helper = library.findLocal(name);
      // TODO(ahe): Make it cleaner.
      if (helper.isAbstractField) {
        AbstractFieldElement abstractField = helper;
        helper = abstractField.getter;
      }
      if (helper == null) {
        compiler.reportError(
            fletchSystemLibrary, MessageKind.GENERIC,
            {'text': "Required implementation method '$name' not found."});
      }
      return helper;
    }

    FunctionElement findExternal(String name, [LibraryElement library]) {
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
    fletchExternalCoroutineChange =
        findExternal('coroutineChange', fletchLibrary);
    fletchExternalNativeError = findExternal('nativeError');
    fletchUnresolved = findExternal('unresolved');
    world.registerStaticUse(fletchUnresolved);
    fletchCompileError = findExternal('compileError');
    world.registerStaticUse(fletchCompileError);

    FletchClassBuilder loadClass(
        String name,
        LibraryElement library,
        [bool builtin = false]) {
      var classImpl = library.findLocal(name);
      if (classImpl == null) classImpl = library.implementation.find(name);
      if (classImpl == null) {
        compiler.internalError(library, "Internal class '$name' not found.");
        return null;
      }
      if (builtin) builtinClasses.add(classImpl);
      // TODO(ahe): Register in ResolutionCallbacks. The 3 lines below should
      // not happen at this point in time.
      classImpl.ensureResolved(compiler);
      FletchClassBuilder classBuilder = registerClassElement(classImpl);
      world.registerInstantiatedType(classImpl.rawType, registry);
      // TODO(ahe): This is a hack to let both the world and the codegen know
      // about the instantiated type.
      registry.registerInstantiatedType(classImpl.rawType);
      return classBuilder;
    }

    compiledObjectClass = loadClass("Object", compiler.coreLibrary, true);
    smiClass = loadClass("_Smi", compiler.coreLibrary, true).element;
    mintClass = loadClass("_Mint", compiler.coreLibrary, true).element;
    stringClass = loadClass("_StringImpl", compiler.coreLibrary, true).element;
    // TODO(ahe): Register _ConstantList through ResolutionCallbacks.
    loadClass(constantListName, fletchSystemLibrary, true);
    loadClass(constantMapName, fletchSystemLibrary, true);
    loadClass("_DoubleImpl", compiler.coreLibrary, true);
    loadClass("Null", compiler.coreLibrary, true);
    loadClass("bool", compiler.coreLibrary, true);
    coroutineClass = loadClass("Coroutine", fletchLibrary, true).element;
    loadClass("Port", fletchLibrary, true);
    loadClass("ForeignMemory", fletchFFILibrary, true);
    loadClass("ForeignPointer", fletchFFILibrary, true);

    growableListClass =
        loadClass(growableListName, fletchSystemLibrary).element;
    // The linked hash map depends on LinkedHashMap.
    loadClass("LinkedHashMap", collectionLibrary).element;
    linkedHashMapClass =
        loadClass(linkedHashMapName, collectionLibrary).element;
    // Register list constructors to world.
    // TODO(ahe): Register growableListClass through ResolutionCallbacks.
    growableListClass.constructors.forEach(world.registerStaticUse);
    linkedHashMapClass.constructors.forEach(world.registerStaticUse);

    // TODO(ajohnsen): Remove? String interpolation does not enqueue '+'.
    // Investigate what else it may enqueue, could be StringBuilder, and then
    // consider using that instead.
    var selector = new UniverseSelector(new Selector.binaryOperator('+'), null);
    world.registerDynamicInvocation(selector);

    selector = new UniverseSelector(new Selector.call('add', null, 1), null);
    world.registerDynamicInvocation(selector);

    alwaysEnqueue.add(coroutineClass.lookupLocalMember('_coroutineStart'));
    alwaysEnqueue.add(compiler.objectClass.implementation.lookupLocalMember(
        noSuchMethodTrampolineName));
    alwaysEnqueue.add(compiler.objectClass.implementation.lookupLocalMember(
        noSuchMethodName));

    for (FunctionElement element in alwaysEnqueue) {
      world.registerStaticUse(element);
    }
  }

  void onElementResolved(Element element, TreeElements elements) {
    if (alwaysEnqueue.contains(element)) {
      var registry = new CodegenRegistry(compiler, elements);
      registry.registerStaticInvocation(element);
    }
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
          compiledObjectClass);
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
    return tearoffClasses.putIfAbsent(function, () {
      FunctionSignature signature = function.signature;
      bool hasThis = function.isInstanceMember;
      FletchClassBuilder tearoffClass = createCallableStubClass(
          hasThis ? 1 : 0,
          signature.parameterCount,
          compiledObjectClass);

      FletchFunctionBuilder functionBuilder =
          systemBuilder.newFunctionBuilderWithSignature(
              'call',
              null,
              signature,
              tearoffClass.classId);

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

      // Create hashCode getter. We simply xor the object hashCode and the
      // method id of the tearoff'ed function.
      FletchFunctionBuilder hashCode = systemBuilder.newFunctionBuilder(
          FletchFunctionKind.ACCESSOR,
          1);

      int hashCodeSelector = FletchSelector.encodeGetter(
          context.getSymbolId("hashCode"));
      int xorSelector = FletchSelector.encodeMethod(
          context.getSymbolId("^"), 1);
      hashCode.assembler
        ..loadParameter(0)
        ..loadField(0)
        ..invokeMethod(hashCodeSelector, 0)
        ..loadLiteral(function.functionId)
        ..invokeMethod(xorSelector, 1)
        ..ret()
        ..methodEnd();

      tearoffClass.addToMethodTable(hashCodeSelector, hashCode);

      return tearoffClass;
    });
  }

  FletchFunctionBase getFunctionForElement(FunctionElement element) {
    assert(element.memberContext == element);

    FletchFunctionBase function =
        systemBuilder.lookupFunctionByElement(element);
    if (function != null) return function;

    return createFletchFunctionBuilder(element);
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

  DebugInfo createDebugInfo(FletchFunction function) {
    DebugInfo debugInfo = new DebugInfo(function);
    AstElement element = function.element;
    if (element == null) return debugInfo;
    List<Bytecode> expectedBytecodes;
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
          null,
          closureEnvironment,
          element,
          compiler);
      expectedBytecodes = lazyFieldInitializers[element].assembler.bytecodes;
    } else if (function.isInitializerList) {
      ClassElement enclosingClass = element.enclosingClass;
      // TODO(ajohnsen): Don't depend on the class builder.
      FletchClassBuilder classBuilder =
          systemBuilder.lookupClassBuilderByElement(enclosingClass);
      codegen = new DebugInfoConstructorCodegen(
          debugInfo,
          builder,
          context,
          elements,
          null,
          closureEnvironment,
          element,
          classBuilder,
          compiler);
      expectedBytecodes = constructors[element.declaration].assembler.bytecodes;
    } else {
      codegen = new DebugInfoFunctionCodegen(
          debugInfo,
          builder,
          context,
          elements,
          null,
          closureEnvironment,
          element,
          compiler);
      expectedBytecodes =
          systemBuilder.lookupFunctionBuilderByElement(element.declaration)
              .assembler.bytecodes;
    }
    if (isNative(element)) {
      compiler.withCurrentElement(element, () {
        codegenNativeFunction(element, codegen);
      });
    } else if (isExternal(element)) {
      compiler.withCurrentElement(element, () {
        codegenExternalFunction(element, codegen);
      });
    } else {
      compiler.withCurrentElement(element, () { codegen.compile(); });
    }
    // The debug codegen should generate the same bytecodes as the original
    // codegen. If that is not the case debug information will be useless.
    assert(Bytecode.identicalBytecodes(expectedBytecodes,
                                       codegen.assembler.bytecodes));
    return debugInfo;
  }

  WorldImpact codegen(CodegenWorkItem work) {
    Element element = work.element;
    if (compiler.verbose) {
      // TODO(johnniwinther): Use reportVerboseInfo once added.
      compiler.reportHint(
          element, MessageKind.GENERIC, {'text': 'Compiling ${element.name}'});
    }

    if (element.isFunction ||
        element.isGetter ||
        element.isSetter ||
        element.isGenerativeConstructor) {
      compiler.withCurrentElement(element.implementation, () {
        codegenFunction(
            element.implementation, work.resolutionTree, work.registry);
      });
    } else {
      compiler.internalError(
          element, "Uninimplemented element kind: ${element.kind}");
    }

    return const WorldImpact();
  }

  void codegenFunction(
      FunctionElement function,
      TreeElements elements,
      Registry registry) {
    registry.registerStaticInvocation(fletchSystemEntry);

    ClosureEnvironment closureEnvironment = createClosureEnvironment(
        function,
        elements);

    FletchFunctionBuilder functionBuilder;

    if (function.memberContext != function) {
      functionBuilder = internalCreateFletchFunctionBuilder(
          function,
          Compiler.CALL_OPERATOR_NAME,
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

    // TODO(ahe): Don't do this.
    compiler.enqueuer.codegen.generatedCode[function.declaration] = null;

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
      List<ClassElement> mixinUsage =
          compiler.world.mixinUsesOf(function.enclosingClass).toList();
      for (int i = 0; i < mixinUsage.length; i++) {
        ClassElement usage = mixinUsage[i];
        // Also add to mixin-usage of the current 'usage'.
        assert(!compiler.world.mixinUsesOf(usage).any(mixinUsage.contains));
        mixinUsage.addAll(compiler.world.mixinUsesOf(usage));
        // TODO(ajohnsen): Consider having multiple 'memberOf' in
        // FletchFunctionBuilder, to avoid duplicates.
        // Create a copy with a unique 'memberOf', so we can detect missing
        // stubs for the mixin applications as well.
        FletchClassBuilder compiledUsage = registerClassElement(usage);
        FunctionTypedElement implementation = function.implementation;
        FletchFunctionBuilder copy =
            systemBuilder.newFunctionBuilderWithSignature(
                function.name,
                implementation,
                implementation.functionSignature,
                compiledUsage.classId,
                kind: function.isAccessor
                    ? FletchFunctionKind.ACCESSOR
                    : FletchFunctionKind.NORMAL);
        compiledUsage.addToMethodTable(fletchSelector, copy);
        copy.copyFrom(functionBuilder);
      }
    }

    if (compiler.verbose) {
      compiler.log(functionBuilder.verboseToString());
    }
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

    int arity = codegen.assembler.functionArity;
    if (name == "Port.send" ||
        name == "Port._sendList" ||
        name == "Port._sendExit" ||
        name == "Process._divide") {
      codegen.assembler.invokeNativeYield(arity, descriptor.index);
    } else {
      codegen.assembler.invokeNative(arity, descriptor.index);
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
      compiler.reportError(
          function.node,
          MessageKind.GENERIC,
          {'text': 'External function is not supported'});
      codegen
          ..doCompileError()
          ..assembler.ret()
          ..assembler.methodEnd();
    }
  }

  void codegenIdentical(
      FunctionElement function,
      FunctionCodegen codegen) {
    codegen.assembler
        ..loadLocal(2)
        ..loadLocal(2)
        ..identical()
        ..ret()
        ..methodEnd();
  }

  void codegenExternalYield(
      FunctionElement function,
      FunctionCodegen codegen) {
    codegen.assembler
        ..loadLocal(1)
        ..processYield()
        ..ret()
        ..methodEnd();
  }

  void codegenExternalInvokeMain(
      FunctionElement function,
      FunctionCodegen codegen) {
    compiler.internalError(
        function, "[codegenExternalInvokeMain] not implemented.");
    // TODO(ahe): This code shouldn't normally be called, only if invokeMain is
    // torn off. Perhaps we should just say we don't support that.
  }

  void codegenExternalNoSuchMethodTrampoline(
      FunctionElement function,
      FunctionCodegen codegen) {
    int id = context.getSymbolId(
        context.mangleName(noSuchMethodName, compiler.coreLibrary));
    int fletchSelector = FletchSelector.encodeMethod(id, 1);
    BytecodeLabel skipGetter = new BytecodeLabel();
    codegen.assembler
        ..enterNoSuchMethod(skipGetter)
        // First invoke the getter.
        ..invokeSelector()
        // Then invoke 'call', with the receiver being the result of the
        // previous invokeSelector.
        ..invokeSelector()
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
        // the native variable in fletch:system.
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
    var registry = new CodegenRegistry(compiler, function.resolvedAst.elements);
    registry.registerStaticInvocation(function);
  }

  void createParameterMatchingStubs() {
    List<FletchFunctionBuilder> functions = systemBuilder.getNewFunctions();
    int length = functions.length;
    for (int i = 0; i < length; i++) {
      FletchFunctionBuilder function = functions[i];
      if (!function.isInstanceMember || function.isAccessor) continue;
      Map selectors = compiler.codegenWorld.invocationsByName(function.name);
      if (selectors == null) continue;
      for (Selector use in selectors.keys) {
        CallStructure callStructure = use.callStructure;
        FunctionSignature signature = function.signature;
        // TODO(ajohnsen): Somehow filter out private selectors of other
        // libraries.
        if (callStructure.signatureApplies(signature) &&
            !isExactParameterMatch(signature, callStructure)) {
          createParameterStubFor(function, use);
        }
      }
    }
  }

  FletchFunctionBase createParameterStubFor(
      FletchFunctionBase function,
      Selector selector) {
    CallStructure callStructure = selector.callStructure;
    assert(callStructure.signatureApplies(function.signature));
    FletchFunctionBase stub = systemBuilder.parameterStubFor(
        function,
        callStructure);
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
      FletchClassBuilder classBuilder = systemBuilder.lookupClassBuilder(
          function.memberOf);
      classBuilder.addToMethodTable(fletchSelector, builder);
    }

    systemBuilder.registerParameterStubFor(function, callStructure, builder);

    return builder;
  }

  void createTearoffStubs() {
    List<FletchFunctionBuilder> functions = systemBuilder.getNewFunctions();
    int length = functions.length;
    for (int i = 0; i < length; i++) {
      FletchFunctionBuilder function = functions[i];
      if (!function.isInstanceMember || function.isAccessor) continue;
      // TODO(ajohnsen/johnniwinther): Expose test on Universe.
      compiler.codegenWorld.forEachInvokedGetter((name, _) {
        if (function.name != name) return;
        createTearoffGetterForFunction(function);
      });
    }
  }

  void createTearoffGetterForFunction(FletchFunctionBuilder function) {
    FletchClassBuilder tearoffClass = createTearoffClass(function);
    FletchFunctionBuilder getter = systemBuilder.newFunctionBuilder(
        FletchFunctionKind.ACCESSOR,
        1);
    int constId = getter.allocateConstantFromClass(tearoffClass.classId);
    getter.assembler
        ..loadParameter(0)
        ..allocate(constId, tearoffClass.fields)
        ..ret()
        ..methodEnd();
    // If the name is private, we need the library.
    // Invariant: We only generate public stubs, e.g. 'call'.
    LibraryElement library;
    if (function.element != null) {
      library = function.element.library;
    }
    int fletchSelector = context.toFletchSelector(
        new Selector.getter(function.name, library));
    FletchClassBuilder classBuilder = systemBuilder.lookupClassBuilder(
        function.memberOf);
    classBuilder.addToMethodTable(fletchSelector, getter);
  }

  int assembleProgram() {
    createTearoffStubs();
    createParameterMatchingStubs();

    for (FletchClassBuilder classBuilder in systemBuilder.getNewClasses()) {
      classBuilder.createIsEntries(this);
    }
    return 0;
  }

  FletchDelta computeDelta() {
    List<Command> commands = <Command>[
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

  // TODO(ajohnsen): Remove when incremental has moved to FletchSystem.
  void pushNewFunction(
      FletchFunctionBuilder functionBuilder,
      List<Command> commands,
      List<Function> deferredActions) {
    int arity = functionBuilder.assembler.functionArity;
    int constantCount = functionBuilder.constants.length;
    int functionId = functionBuilder.functionId;

    assert(systemBuilder.lookupFunctionBuilder(functionId) == functionBuilder);
    assert(functionBuilder.assembler.bytecodes.isNotEmpty);

    functionBuilder.constants.forEach((constant, int index) {
      if (constant is ConstantValue) {
        if (constant is FletchFunctionConstant) {
          commands.add(const PushNull());
          deferredActions.add(() {
            commands
                ..add(new PushFromMap(MapId.methods, functionId))
                ..add(new PushFromMap(MapId.methods, constant.functionId))
                ..add(new ChangeMethodLiteral(index));
          });
        } else if (constant is FletchClassConstant) {
          commands.add(const PushNull());
          deferredActions.add(() {
            commands
                ..add(new PushFromMap(MapId.methods, functionId))
                ..add(new PushFromMap(MapId.classes, constant.classId))
                ..add(new ChangeMethodLiteral(index));
          });
        } else {
          commands.add(const PushNull());
          deferredActions.add(() {
            int id = context.compiledConstants[constant];
            if (id == null) {
              throw "Unsupported constant: ${constant.toStructuredString()}";
            }
            commands
                ..add(new PushFromMap(MapId.methods, functionId))
                ..add(new PushFromMap(MapId.constants, id))
                ..add(new ChangeMethodLiteral(index));
          });
        }
      } else {
        throw "Unsupported constant: ${constant.runtimeType}";
      }
    });

    commands.add(
        new PushNewFunction(
            arity,
            constantCount,
            functionBuilder.assembler.bytecodes,
            functionBuilder.assembler.catchRanges));

    commands.add(new PopToMap(MapId.methods, functionId));
  }

  bool enableCodegenWithErrorsIfSupported(Spannable spannable) {
    return true;
  }

  bool enableDeferredLoadingIfSupported(Spannable spannable, Registry registry) {
    return false;
  }

  bool registerDeferredLoading(Spannable node, Registry registry) {
    compiler.reportWarning(
        node,
        MessageKind.GENERIC,
        {'text': "Deferred loading is not supported."});
    return false;
  }

  bool get supportsReflection => false;

  Future onLibraryScanned(LibraryElement library, LibraryLoader loader) {
    if (Uri.parse('dart:_fletch_system') == library.canonicalUri) {
      fletchSystemLibrary = library;
    } else if (Uri.parse('dart:fletch.ffi') == library.canonicalUri) {
      fletchFFILibrary = library;
    } else if (Uri.parse('dart:system') == library.canonicalUri) {
      fletchIOSystemLibrary = library;
    } else if (Uri.parse('dart:collection') == library.canonicalUri) {
      collectionLibrary = library;
    } else if (Uri.parse('dart:math') == library.canonicalUri) {
      mathLibrary = library;
    } else if (Uri.parse('dart:async') == library.canonicalUri) {
      asyncLibrary = library;
    } else if (Uri.parse('dart:fletch') == library.canonicalUri) {
      fletchLibrary = library;
    }

    if (library.isPlatformLibrary && !library.isPatched) {
      // Apply patch, if any.
      Uri patchUri = compiler.resolvePatchUri(library.canonicalUri.path);
      if (patchUri != null) {
        return compiler.patchParser.patchLibrary(loader, patchUri, library);
      }
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
      // TODO(ahe): Don't use ensureResolved (fix TODO in isNative instead).
      element.metadata.forEach((m) => m.ensureResolved(compiler));
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
    } else if (element.library == fletchFFILibrary) {
      // Nothing needed for now.
    } else if (element.library == fletchIOSystemLibrary) {
      // Nothing needed for now.
    } else if (externals.contains(element)) {
      // Nothing needed for now.
    } else {
      compiler.reportError(
          element, MessageKind.PATCH_EXTERNAL_WITHOUT_IMPLEMENTATION);
    }
    return element;
  }

  int compileLazyFieldInitializer(FieldElement field, Registry registry) {
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

  FletchFunctionBase compileConstructor(
      ConstructorElement constructor,
      Registry registry) {
    assert(constructor.isDeclaration);
    FletchFunctionBuilder functionBuilder = constructors[constructor];
    if (functionBuilder != null) return functionBuilder;

    ClassElement classElement = constructor.enclosingClass;
    FletchClassBuilder classBuilder = registerClassElement(classElement);

    ConstructorElement implementation = constructor.implementation;

    if (compiler.verbose) {
      // TODO(johnniwinther): Use reportVerboseInfo once added.
      compiler.reportHint(
          constructor,
          MessageKind.GENERIC,
          {'text': 'Compiling constructor ${implementation.name}'});
    }

    TreeElements elements = implementation.resolvedAst.elements;

    ClosureEnvironment closureEnvironment = createClosureEnvironment(
        implementation,
        elements);

    functionBuilder = systemBuilder.newFunctionBuilderWithSignature(
        implementation.name,
        implementation,
        implementation.functionSignature,
        null,
        kind: FletchFunctionKind.INITIALIZER_LIST);
    constructors[constructor] = functionBuilder;

    ConstructorCodegen codegen = new ConstructorCodegen(
        functionBuilder,
        context,
        elements,
        registry,
        closureEnvironment,
        implementation,
        classBuilder);

    codegen.compile();

    if (compiler.verbose) {
      compiler.log(functionBuilder.verboseToString());
    }

    return functionBuilder;
  }

  /**
   * Generate a getter for field [fieldIndex].
   */
  int makeGetter(int fieldIndex) {
    return getters.putIfAbsent(fieldIndex, () {
      FletchFunctionBuilder stub = systemBuilder.newFunctionBuilder(
          FletchFunctionKind.ACCESSOR,
          1);
      stub.assembler
          ..loadParameter(0)
          ..loadField(fieldIndex)
          ..ret()
          ..methodEnd();
      return stub.functionId;
    });
  }

  /**
   * Generate a setter for field [fieldIndex].
   */
  int makeSetter(int fieldIndex) {
    return setters.putIfAbsent(fieldIndex, () {
      FletchFunctionBuilder stub = systemBuilder.newFunctionBuilder(
          FletchFunctionKind.ACCESSOR,
          2);
      stub.assembler
          ..loadParameter(0)
          ..loadParameter(1)
          ..storeField(fieldIndex)
          // Top is at this point the rhs argument, thus the return value.
          ..ret()
          ..methodEnd();
      return stub.functionId;
    });
  }

  void generateUnimplementedError(
      Spannable spannable,
      String reason,
      FletchFunctionBuilder function) {
    compiler.reportError(
        spannable, MessageKind.GENERIC, {'text': reason});
    var constString = constantSystem.createString(
        new DartString.literal(reason));
    context.markConstantUsed(constString);
    function
        ..assembler.loadConst(function.allocateConstant(constString))
        ..assembler.emitThrow();
  }

  void forgetElement(Element element) {
    // TODO(ajohnsen): Remove this check.
    if (!systemBuilder.predecessorSystem.isEmpty) {
      FletchFunctionBase function =
          systemBuilder.lookupFunctionByElement(element);
      if (function != null) {
        systemBuilder.forgetFunction(function);
      }
      ClassElement enclosingClass = element.enclosingClass;
      if (enclosingClass != null) {
        FletchClassBuilder builder = registerClassElement(enclosingClass);
        builder.removeFromMethodTable(function);
      }
    }
    FletchFunctionBuilder functionBuilder =
        systemBuilder.lookupFunctionBuilderByElement(element);
    if (functionBuilder == null) return;
    functionBuilder.reuse();
  }

  static bool isExactParameterMatch(
      FunctionSignature signature,
      CallStructure callStructure) {
    if (!callStructure.signatureApplies(signature)) {
      return false;
    }
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
}
