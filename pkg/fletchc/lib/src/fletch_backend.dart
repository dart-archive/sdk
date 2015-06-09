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
    MemberElement;

import 'package:compiler/src/elements/modelx.dart' show
    LibraryElementX;

import 'package:compiler/src/dart_types.dart' show
    DartType,
    InterfaceType;

import 'package:compiler/src/universe/universe.dart'
    show Selector;

import 'package:compiler/src/util/util.dart'
    show Spannable;

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
    ListConstantValue,
    MapConstantValue,
    StringConstantValue;

import 'package:compiler/src/constants/expressions.dart' show
    ConstantExpression;

import 'package:compiler/src/resolution/resolution.dart' show
    TreeElements;

import 'package:compiler/src/library_loader.dart' show
    LibraryLoader;

import 'fletch_constants.dart' show
    FletchClassConstant,
    FletchFunctionConstant,
    FletchClassInstanceConstant;

import 'fletch_function_builder.dart' show
    FletchFunctionBuilderKind,
    FletchFunctionBuilder,
    DebugInfo;

import 'fletch_class_builder.dart' show
    FletchClassBuilder;

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

class FletchBackend extends Backend {
  static const String growableListName = '_GrowableList';
  static const String constantListName = '_ConstantList';
  static const String constantMapName = '_ConstantMap';
  static const String linkedHashMapName = '_CompactLinkedHashMap';
  static const String noSuchMethodName = '_noSuchMethod';
  static const String noSuchMethodTrampolineName = '_noSuchMethodTrampoline';

  final FletchContext context;

  final DartConstantTask constantCompilerTask;

  final Map<FunctionElement, FletchFunctionBuilder> functionBuilders =
      <FunctionElement, FletchFunctionBuilder>{};

  final Map<ConstructorElement, FletchFunctionBuilder> constructors =
      <ConstructorElement, FletchFunctionBuilder>{};

  final List<FletchFunctionBuilder> functions = <FletchFunctionBuilder>[];

  final Set<FunctionElement> externals = new Set<FunctionElement>();

  final Map<ClassElement, FletchClassBuilder> classBuilders =
      <ClassElement, FletchClassBuilder>{};
  final Map<ClassElement, Set<ClassElement>> directSubclasses =
      <ClassElement, Set<ClassElement>>{};

  final List<FletchClassBuilder> classes = <FletchClassBuilder>[];

  final Set<ClassElement> builtinClasses = new Set<ClassElement>();

  final Map<MemberElement, ClosureEnvironment> closureEnvironments =
      <MemberElement, ClosureEnvironment>{};

  final Map<FunctionElement, FletchClassBuilder> closureClasses =
      <FunctionElement, FletchClassBuilder>{};

  final Map<FieldElement, FletchFunctionBuilder> lazyFieldInitializers =
      <FieldElement, FletchFunctionBuilder>{};

  final Map<FletchFunctionBuilder, FletchClassBuilder> tearoffClasses =
      <FletchFunctionBuilder, FletchClassBuilder>{};

  final Map<int, int> getters = <int, int>{};
  final Map<int, int> setters = <int, int>{};

  Map<FletchClassBuilder, FletchFunctionBuilder> tearoffFunctions;

  List<Command> commands;

  LibraryElement fletchSystemLibrary;
  LibraryElement fletchFFILibrary;
  LibraryElement fletchIOSystemLibrary;
  LibraryElement collectionLibrary;
  LibraryElement mathLibrary;

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

  final Set<FunctionElement> alwaysEnqueue = new Set<FunctionElement>();

  FletchBackend(FletchCompiler compiler)
      : this.context = compiler.context,
        this.constantCompilerTask = new DartConstantTask(compiler),
        super(compiler) {
    context.resolutionCallbacks = new FletchResolutionCallbacks(context);
  }

  FletchClassBuilder registerClassElement(ClassElement element) {
    if (element == null) return null;
    assert(element.isDeclaration);
    return classBuilders.putIfAbsent(element, () {
      directSubclasses[element] = new Set<ClassElement>();
      FletchClassBuilder superclass = registerClassElement(element.superclass);
      if (superclass != null) {
        Set<ClassElement> subclasses = directSubclasses[element.superclass];
        subclasses.add(element);
      }
      int id = classes.length;
      FletchClassBuilder classBuilder = new FletchClassBuilder(
          id, element, superclass);
      if (element.lookupLocalMember(Compiler.CALL_OPERATOR_NAME) != null) {
        classBuilder.createIsFunctionEntry(this);
      }
      classes.add(classBuilder);
      return classBuilder;
    });
  }

  FletchClassBuilder createCallableStubClass(
      int fields, FletchClassBuilder superclass) {
    int id = classes.length;
    FletchClassBuilder classBuilder = new FletchClassBuilder(
        id, null, superclass, extraFields: fields);
    classes.add(classBuilder);
    classBuilder.createIsFunctionEntry(this);
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

    FunctionElement findHelper(String name) {
      Element helper = fletchSystemLibrary.findLocal(name);
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
    fletchExternalCoroutineChange = findExternal('coroutineChange');
    fletchExternalNativeError = findExternal('nativeError');
    fletchUnresolved = findExternal('unresolved');
    world.registerStaticUse(fletchUnresolved);
    fletchCompileError = findExternal('compileError');
    world.registerStaticUse(fletchCompileError);

    FletchClassBuilder loadClass(String name, LibraryElement library) {
      var classImpl = library.findLocal(name);
      if (classImpl == null) classImpl = library.implementation.find(name);
      if (classImpl == null) {
        compiler.internalError(library, "Internal class '$name' not found.");
        return null;
      }
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

    FletchClassBuilder loadBuiltinClass(String name, LibraryElement library) {
      FletchClassBuilder classBuilder = loadClass(name, library);
      builtinClasses.add(classBuilder.element);
      return classBuilder;
    }

    compiledObjectClass = loadBuiltinClass("Object", compiler.coreLibrary);
    smiClass = loadBuiltinClass("_Smi", compiler.coreLibrary).element;
    mintClass = loadBuiltinClass("_Mint", compiler.coreLibrary).element;
    stringClass = loadBuiltinClass("_StringImpl", compiler.coreLibrary).element;
    // TODO(ahe): Register _ConstantList through ResolutionCallbacks.
    loadBuiltinClass(constantListName, fletchSystemLibrary);
    loadBuiltinClass(constantMapName, fletchSystemLibrary);
    loadBuiltinClass("_DoubleImpl", compiler.coreLibrary);
    loadBuiltinClass("Null", compiler.coreLibrary);
    loadBuiltinClass("bool", compiler.coreLibrary);
    coroutineClass =
        loadBuiltinClass("Coroutine", compiler.coreLibrary).element;
    loadBuiltinClass("Port", compiler.coreLibrary);
    loadBuiltinClass("Foreign", fletchFFILibrary);

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
    world.registerDynamicInvocation(new Selector.binaryOperator('+'));
    world.registerDynamicInvocation(new Selector.call('add', null, 1));

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
      return createCallableStubClass(fields, compiledObjectClass);
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
  FletchClassBuilder createTearoffClass(FletchFunctionBuilder function) {
    return tearoffClasses.putIfAbsent(function, () {
      FunctionSignature signature = function.signature;
      bool hasThis = function.hasThisArgument;
      FletchClassBuilder classBuilder = createCallableStubClass(
          hasThis ? 1 : 0,
          compiledObjectClass);
      FletchFunctionBuilder functionBuilder = new FletchFunctionBuilder(
          functions.length,
          'call',
          null,
          signature,
          classBuilder);
      functions.add(functionBuilder);

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
          function.methodId);
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
      classBuilder.addToMethodTable(fletchSelector, functionBuilder);

      if (hasThis && function.memberOf.element != null) {
        // Create == function that tests for equality.
        int isSelector = context.toFletchTearoffIsSelector(
            function.name,
            function.memberOf.element);
        classBuilder.addIsSelector(isSelector);

        FletchFunctionBuilder equal = new FletchFunctionBuilder.normal(
            functions.length,
            2);
        functions.add(equal);

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

        int id = context.getSymbolId("==");
        int equalsSelector = FletchSelector.encodeMethod(id, 1);
        classBuilder.addToMethodTable(equalsSelector, equal);

        // Create hashCode getter. We simply xor the object hashCode and the
        // method id of the tearoff'ed function.
        FletchFunctionBuilder hashCode = new FletchFunctionBuilder.accessor(
            functions.length,
            false);
        functions.add(hashCode);

        int hashCodeSelector = FletchSelector.encodeGetter(
            context.getSymbolId("hashCode"));
        int xorSelector = FletchSelector.encodeMethod(
            context.getSymbolId("^"), 1);
        hashCode.assembler
          ..loadParameter(0)
          ..loadField(0)
          ..invokeMethod(hashCodeSelector, 0)
          ..loadLiteral(function.methodId)
          ..invokeMethod(xorSelector, 1)
          ..ret()
          ..methodEnd();

        classBuilder.addToMethodTable(hashCodeSelector, hashCode);
      }
      return classBuilder;
    });
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
    return functionBuilders.putIfAbsent(function.declaration, () {
      FunctionTypedElement implementation = function.implementation;
      FletchFunctionBuilder functionBuilder = new FletchFunctionBuilder(
          functions.length,
          name,
          function,
          // Parameter initializers are expressed in the potential
          // implementation.
          implementation.functionSignature,
          holderClass,
          kind: function.isAccessor
              ? FletchFunctionBuilderKind.ACCESSOR
              : FletchFunctionBuilderKind.NORMAL);
      functions.add(functionBuilder);
      return functionBuilder;
    });
  }

  int functionMethodId(FunctionElement function) {
    return createFletchFunctionBuilder(function).methodId;
  }

  FletchFunctionBuilder functionBuilderFromTearoffClass(
      FletchClassBuilder klass) {
    if (tearoffFunctions == null) {
      tearoffFunctions = <FletchClassBuilder, FletchFunctionBuilder>{};
      tearoffClasses.forEach((k, v) => tearoffFunctions[v] = k);
    }
    return tearoffFunctions[klass];
  }

  void ensureDebugInfo(FletchFunctionBuilder function) {
    if (function.debugInfo != null) return;
    function.debugInfo = new DebugInfo(function);
    AstElement element = function.element;
    if (element == null) return;
    List<Bytecode> expectedBytecodes = function.assembler.bytecodes;
    element = element.implementation;
    TreeElements elements = element.resolvedAst.elements;
    ClosureEnvironment closureEnvironment = createClosureEnvironment(
        element,
        elements);
    CodegenVisitor codegen;
    if (function.isLazyFieldInitializer) {
      codegen = new DebugInfoLazyFieldInitializerCodegen(
          function,
          context,
          elements,
          null,
          closureEnvironment,
          element,
          compiler);
    } else if (function.isInitializerList) {
      ClassElement enclosingClass = element.enclosingClass;
      FletchClassBuilder classBuilder = classBuilders[enclosingClass];
      codegen = new DebugInfoConstructorCodegen(
          function,
          context,
          elements,
          null,
          closureEnvironment,
          element,
          classBuilder,
          compiler);
    } else {
      codegen = new DebugInfoFunctionCodegen(
          function,
          context,
          elements,
          null,
          closureEnvironment,
          element,
          compiler);
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

    if (functionBuilder.memberOf != null &&
        !function.isGenerativeConstructor) {
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
      int methodId = functionBuilder.methodId;
      functionBuilder.memberOf.addToMethodTable(
          fletchSelector, functionBuilder);
      // Inject method into all mixin usages.
      Iterable<ClassElement> mixinUsage =
          compiler.world.mixinUsesOf(function.enclosingClass);
      for (ClassElement usage in mixinUsage) {
        // TODO(ajohnsen): Consider having multiple 'memberOf' in
        // FletchFunctionBuilder, to avoid duplicates.
        // Create a copy with a unique 'memberOf', so we can detect missing
        // stubs for the mixin applications as well.
        FletchClassBuilder compiledUsage = registerClassElement(usage);
        FunctionTypedElement implementation = function.implementation;
        FletchFunctionBuilder copy = new FletchFunctionBuilder(
            functions.length,
            function.name,
            implementation,
            implementation.functionSignature,
            compiledUsage,
            kind: function.isAccessor
                ? FletchFunctionBuilderKind.ACCESSOR
                : FletchFunctionBuilderKind.NORMAL);
        functions.add(copy);
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
    codegen.assembler
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

  void createParameterMatchingStubs() {
    int length = functions.length;
    for (int i = 0; i < length; i++) {
      FletchFunctionBuilder function = functions[i];
      if (!function.hasThisArgument || function.isAccessor) continue;
      String name = function.name;
      Set<Selector> usage = compiler.resolverWorld.invokedNames[name];
      if (usage == null) continue;
      for (Selector use in usage) {
        // TODO(ajohnsen): Somehow filter out private selectors of other
        // libraries.
        if (function.canBeCalledAs(use) &&
            !function.matchesSelector(use)) {
          function.createParameterMappingFor(use, context);
        }
      }
    }
  }

  void createTearoffStubs() {
    int length = functions.length;
    for (int i = 0; i < length; i++) {
      FletchFunctionBuilder function = functions[i];
      if (!function.hasThisArgument || function.isAccessor) continue;
      String name = function.name;
      if (compiler.resolverWorld.invokedGetters.containsKey(name)) {
        createTearoffGetterForFunction(function);
      }
    }
  }

  void createTearoffGetterForFunction(FletchFunctionBuilder function) {
    FletchClassBuilder tearoffClass = createTearoffClass(function);
    FletchFunctionBuilder getter = new FletchFunctionBuilder.accessor(
        functions.length,
        false);
    functions.add(getter);
    int constId = getter.allocateConstantFromClass(tearoffClass.id);
    getter.assembler
        ..loadParameter(0)
        ..allocate(constId, tearoffClass.fields)
        ..ret()
        ..methodEnd();
    // If the name is private, we need the library.
    // Invariant: We only generate public stubs, e.g. 'call'.
    LibraryElement library;
    if (function.memberOf.element != null) {
      library = function.memberOf.element.library;
    }
    int fletchSelector = context.toFletchSelector(
        new Selector.getter(function.name, library));
    function.memberOf.addToMethodTable(fletchSelector, getter);
  }

  int assembleProgram() {
    createTearoffStubs();
    createParameterMatchingStubs();

    for (FletchClassBuilder classBuilder in classes) {
      classBuilder.createIsEntries(this);
      // TODO(ajohnsen): Currently, the CodegenRegistry does not enqueue fields.
      // This is a workaround, where we basically add getters for all fields.
      classBuilder.createImplicitAccessors(this);
    }

    List<Command> commands = <Command>[
        const NewMap(MapId.methods),
        const NewMap(MapId.classes),
        const NewMap(MapId.constants),
    ];

    List<Function> deferredActions = <Function>[];

    functions.forEach((f) => pushNewFunction(f, commands, deferredActions));

    int changes = 0;

    for (FletchClassBuilder classBuilder in classes) {
      ClassElement element = classBuilder.element;
      if (builtinClasses.contains(element)) {
        int nameId = context.getSymbolId(element.name);
        commands.add(new PushBuiltinClass(nameId, classBuilder.fields));
      } else {
        commands.add(new PushNewClass(classBuilder.fields));
      }

      commands.add(const Dup());
      commands.add(new PopToMap(MapId.classes, classBuilder.id));

      Map<int, int> methodTable = classBuilder.computeMethodTable(this);
      methodTable.forEach((int selector, int methodId) {
        commands.add(new PushNewInteger(selector));
        commands.add(new PushFromMap(MapId.methods, methodId));
      });
      commands.add(new ChangeMethodTable(methodTable.length));

      changes++;
    }

    context.forEachStatic((element, index) {
      FletchFunctionBuilder initializer = lazyFieldInitializers[element];
      if (initializer != null) {
        commands.add(new PushFromMap(MapId.methods, initializer.methodId));
        commands.add(const PushNewInitializer());
      } else {
        commands.add(const PushNull());
      }
    });
    commands.add(new ChangeStatics(context.staticIndices.length));
    changes++;

    context.compiledConstants.forEach((constant, id) {
      void addList(List<ConstantValue> list) {
        for (ConstantValue entry in list) {
          int entryId = context.compiledConstants[entry];
          commands.add(new PushFromMap(MapId.constants, entryId));
        }
        commands.add(new PushConstantList(list.length));
      }

      if (constant.isInt) {
        commands.add(new PushNewInteger(constant.primitiveValue));
      } else if (constant.isDouble) {
        commands.add(new PushNewDouble(constant.primitiveValue));
      } else if (constant.isTrue) {
        commands.add(new PushBoolean(true));
      } else if (constant.isFalse) {
        commands.add(new PushBoolean(false));
      } else if (constant.isNull) {
        commands.add(const PushNull());
      } else if (constant.isString) {
        commands.add(
            new PushNewString(constant.primitiveValue.slowToString()));
      } else if (constant.isList) {
        ListConstantValue value = constant;
        addList(constant.entries);
      } else if (constant.isMap) {
        MapConstantValue value = constant;
        addList(value.keys);
        addList(value.values);
        commands.add(new PushConstantMap(value.length * 2));
      } else if (constant.isConstructedObject) {
        ConstructedConstantValue value = constant;
        ClassElement classElement = value.type.element;
        FletchClassBuilder classBuilder = classBuilders[classElement];
        for (ConstantValue field in value.fields.values) {
          int fieldId = context.compiledConstants[field];
          commands.add(new PushFromMap(MapId.constants, fieldId));
        }
        commands
            ..add(new PushFromMap(MapId.classes, classBuilder.id))
            ..add(const PushNewInstance());
      } else if (constant is FletchClassInstanceConstant) {
        commands
            ..add(new PushFromMap(MapId.classes, constant.classId))
            ..add(const PushNewInstance());
      } else {
        throw "Unsupported constant: ${constant.toStructuredString()}";
      }
      commands.add(new PopToMap(MapId.constants, id));
    });

    for (FletchClassBuilder classBuilder in classes) {
      FletchClassBuilder superclass = classBuilder.superclass;
      if (superclass == null) continue;
      commands.add(new PushFromMap(MapId.classes, classBuilder.id));
      commands.add(new PushFromMap(MapId.classes, superclass.id));
      commands.add(const ChangeSuperClass());
      changes++;
    }

    for (Function action in deferredActions) {
      action();
      changes++;
    }

    commands.add(new CommitChanges(changes));

    commands.add(const PushNewInteger(0));

    commands.add(new PushFromMap(
        MapId.methods,
        functionBuilders[fletchSystemEntry].methodId));

    this.commands = commands;

    return 0;
  }

  void pushNewFunction(
      FletchFunctionBuilder functionBuilder,
      List<Command> commands,
      List<Function> deferredActions) {
    int arity = functionBuilder.assembler.functionArity;
    int constantCount = functionBuilder.constants.length;
    int methodId = functionBuilder.methodId;

    assert(functions[methodId] == functionBuilder);
    assert(functionBuilder.assembler.bytecodes.isNotEmpty);

    functionBuilder.constants.forEach((constant, int index) {
      if (constant is ConstantValue) {
        if (constant is FletchFunctionConstant) {
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
          commands.add(const PushNull());
          deferredActions.add(() {
            int id = context.compiledConstants[constant];
            if (id == null) {
              throw "Unsupported constant: ${constant.toStructuredString()}";
            }
            commands
                ..add(new PushFromMap(MapId.methods, methodId))
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

    commands.add(new PopToMap(MapId.methods, methodId));
  }

  bool registerDeferredLoading(Spannable node, Registry registry) {
    compiler.reportWarning(
        node,
        MessageKind.GENERIC,
        {'text': "Deferred loading is not supported."});
    return false;
  }

  Future onLibraryScanned(LibraryElement library, LibraryLoader loader) {
    // TODO(ajohnsen): Find a better way to do this.
    // Inject non-patch members in a patch library, into the declaration
    // library.
    if (library.isPatch && library.declaration == compiler.coreLibrary) {
      library.entryCompilationUnit.forEachLocalMember((element) {
        if (!element.isPatch && !isPrivateName(element.name)) {
          LibraryElementX declaration = library.declaration;
          declaration.addToScope(element, compiler);
        }
      });
    }

    if (Uri.parse('dart:_fletch_system') == library.canonicalUri) {
      fletchSystemLibrary = library;
    } else if (Uri.parse('dart:ffi') == library.canonicalUri) {
      fletchFFILibrary = library;
    } else if (Uri.parse('dart:system') == library.canonicalUri) {
      fletchIOSystemLibrary = library;
    } else if (Uri.parse('dart:collection') == library.canonicalUri) {
      collectionLibrary = library;
    } else if (Uri.parse('dart:math') == library.canonicalUri) {
      mathLibrary = library;
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

    FletchFunctionBuilder functionBuilder = new FletchFunctionBuilder.lazyInit(
        functions.length,
        "${field.name} lazy initializer",
        field,
        0);
    functions.add(functionBuilder);
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

  FletchFunctionBuilder compileConstructor(ConstructorElement constructor,
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

    functionBuilder = new FletchFunctionBuilder(
        functions.length,
        implementation.name,
        implementation,
        implementation.functionSignature,
        null,
        kind: FletchFunctionBuilderKind.INITIALIZER_LIST);
    functions.add(functionBuilder);
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
      FletchFunctionBuilder stub = new FletchFunctionBuilder.accessor(
          functions.length,
          false);
      functions.add(stub);
      stub.assembler
          ..loadParameter(0)
          ..loadField(fieldIndex)
          ..ret()
          ..methodEnd();
      return stub.methodId;
    });
  }

  /**
   * Generate a setter for field [fieldIndex].
   */
  int makeSetter(int fieldIndex) {
    return setters.putIfAbsent(fieldIndex, () {
      FletchFunctionBuilder stub = new FletchFunctionBuilder.accessor(
          functions.length,
          true);
      functions.add(stub);
      stub.assembler
          ..loadParameter(0)
          ..loadParameter(1)
          ..storeField(fieldIndex)
          // Top is at this point the rhs argument, thus the return value.
          ..ret()
          ..methodEnd();
      return stub.methodId;
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
    FletchFunctionBuilder functionBuilder = functionBuilders[element];
    if (functionBuilder == null) return;
    functionBuilder.reuse();
  }
}
