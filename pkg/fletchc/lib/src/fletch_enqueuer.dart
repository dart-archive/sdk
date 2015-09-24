// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_enqueuer;

import 'dart:collection' show
    Queue;

import 'package:compiler/src/dart2jslib.dart' show
    CodegenEnqueuer,
    Compiler,
    CompilerTask,
    EnqueueTask,
    ItemCompilationContextCreator,
    QueueFilter,
    Registry,
    ResolutionEnqueuer,
    WorkItem,
    WorldImpact;

import 'package:compiler/src/universe/universe.dart' show
    CallStructure,
    Selector,
    Universe,
    UniverseSelector;

import 'package:compiler/src/dart_types.dart' show
    DartType,
    InterfaceType;

import 'package:compiler/src/elements/elements.dart' show
    AstElement,
    ClassElement,
    ConstructorElement,
    Element,
    FunctionElement,
    LibraryElement,
    LocalFunctionElement,
    Name,
    TypedElement;

import 'package:compiler/src/resolution/resolution.dart' show
    TreeElements;

import 'package:compiler/src/util/util.dart' show
    Hashing,
    SpannableAssertionFailure;

import 'fletch_compiler_implementation.dart' show
    FletchCompilerImplementation;

import 'dynamic_call_enqueuer.dart' show
    DynamicCallEnqueuer,
    UsageRecorder;

import 'fletch_codegen_work_item.dart' show
    FletchCodegenWorkItem;

import 'fletch_registry.dart' show
    FletchRegistry,
    FletchRegistryImplementation;

part 'enqueuer_mixin.dart';

// TODO(ahe): Delete this constant when FletchEnqueuer is complete.
const bool useCustomEnqueuer = const bool.fromEnvironment(
    "fletchc.use-custom-enqueuer", defaultValue: false);

/// True if enqueuing of system libraries should be reported in verbose mode.
const bool logSystemLibraries =
    const bool.fromEnvironment("fletchc.logSystemLibraries");

/// Returns true if enqueuing of [element] should be reported in verbose
/// mode. See [logSystemLibraries].
bool shouldReportEnqueuingOfElement(Compiler compiler, Element element) {
  if (logSystemLibraries) return true;
  return compiler.inUserCode(element);
}

// TODO(ahe): Delete this method when FletchEnqueuer is complete.
CodegenEnqueuer makeCodegenEnqueuer(FletchCompilerImplementation compiler) {
  ItemCompilationContextCreator itemCompilationContextCreator =
      compiler.backend.createItemCompilationContext;
  return useCustomEnqueuer
      ? new FletchEnqueuer(compiler, itemCompilationContextCreator)
      : new TransitionalFletchEnqueuer(compiler, itemCompilationContextCreator);
}

/// Custom enqueuer for Fletch.
class FletchEnqueueTask extends CompilerTask implements EnqueueTask {
  final ResolutionEnqueuer resolution;

  // TODO(ahe): Should be typed [FletchEnqueuer].
  final CodegenEnqueuer codegen;

  FletchEnqueueTask(FletchCompilerImplementation compiler)
    : resolution = new ResolutionEnqueuer(
          compiler, compiler.backend.createItemCompilationContext),
      codegen = makeCodegenEnqueuer(compiler),
      super(compiler) {
    codegen.task = this;
    resolution.task = this;
    codegen.nativeEnqueuer = compiler.backend.nativeCodegenEnqueuer(codegen);

    resolution.nativeEnqueuer =
        compiler.backend.nativeResolutionEnqueuer(resolution);
  }

  String get name => 'Fletch enqueue';

  void forgetElement(Element element) {
    resolution.forgetElement(element);
    codegen.forgetElement(element);
  }
}

// TODO(ahe): Delete this class when FletchEnqueuer is complete.
class TransitionalFletchEnqueuer extends CodegenEnqueuer
    implements FletchEnqueuer {
  final Set<Element> _processedElements = new Set<Element>();

  TransitionalFletchEnqueuer(
      FletchCompilerImplementation compiler,
      ItemCompilationContextCreator itemCompilationContextCreator)
      : super(compiler, itemCompilationContextCreator);

  bool isProcessed(Element member) {
    return member.isAbstract || _processedElements.contains(member);
  }

  void applyImpact(Element element, WorldImpact worldImpact) {
    assert(worldImpact == null);
    _processedElements.add(element);
  }

  void forgetElement(Element element) {
    super.forgetElement(element);
    _processedElements.remove(element);
  }

  bool internalAddToWorkList(Element element) {
    // This is a copy of CodegenEnqueuer.internalAddToWorkList except that it
    // uses FletchCodegenWorkItem.

    // Don't generate code for foreign elements.
    if (compiler.backend.isForeign(element)) return false;

    // Codegen inlines field initializers. It only needs to generate
    // code for checked setters.
    if (element.isField && element.isInstanceMember) {
      if (!compiler.enableTypeAssertions
          || element.enclosingElement.isClosure) {
        return false;
      }
    }

    if (compiler.hasIncrementalSupport && !isProcessed(element)) {
      newlyEnqueuedElements.add(element);
    }

    if (queueIsClosed) {
      throw new SpannableAssertionFailure(element,
          "Codegen work list is closed. Trying to add $element");
    }
    FletchCodegenWorkItem workItem = new FletchCodegenWorkItem(
        compiler, element, itemCompilationContextCreator());
    queue.add(workItem);
    return true;
  }

  DynamicCallEnqueuer get dynamicCallEnqueuer => notImplemented;

  Set<ElementUsage> get _enqueuedUsages => notImplemented;

  Queue<ElementUsage> get _pendingEnqueuedUsages => notImplemented;

  void _enqueueElement(element, selector, {tearOff}) => notImplemented;

  void processQueue() => notImplemented;

  void recordElementUsage(element, selector, {tearOff}) => notImplemented;

  void recordTypeTest(element, type) => notImplemented;

  Set<TypeTest> get _typeTests => notImplemented;

  Queue<TypeTest> get _pendingTypeTests => notImplemented;
}

class FletchEnqueuer extends EnqueuerMixin
    implements CodegenEnqueuer, UsageRecorder {
  final ItemCompilationContextCreator itemCompilationContextCreator;

  final FletchCompilerImplementation compiler;

  bool queueIsClosed = false;

  bool hasEnqueuedReflectiveElements = false;

  bool hasEnqueuedReflectiveStaticFields = false;

  EnqueueTask task;

  // TODO(ahe): Get rid of this?
  var nativeEnqueuer;

  final Universe universe = new Universe();

  final Set<ElementUsage> _enqueuedUsages = new Set<ElementUsage>();

  final Queue<ElementUsage> _pendingEnqueuedUsages =
      new Queue<ElementUsage>();

  final Set<TypeTest> _typeTests = new Set<TypeTest>();

  final Queue<TypeTest> _pendingTypeTests = new Queue<TypeTest>();

  final DynamicCallEnqueuer dynamicCallEnqueuer;

  FletchEnqueuer(
      FletchCompilerImplementation compiler,
      this.itemCompilationContextCreator)
      : compiler = compiler,
        dynamicCallEnqueuer = new DynamicCallEnqueuer(compiler);

  bool get queueIsEmpty {
    return _pendingEnqueuedUsages.isEmpty && _pendingTypeTests.isEmpty;
  }

  bool get isResolutionQueue => false;

  QueueFilter get filter => compiler.enqueuerFilter;

  void forgetElement(Element element) {
    _enqueuedUsages.remove(element);
    dynamicCallEnqueuer.forgetElement(element);
  }

  void registerInstantiatedType(
      InterfaceType type,
      Registry registry,
      {bool mirrorUsage: false}) {
    dynamicCallEnqueuer.registerInstantiatedType(type);
  }

  // TODO(ahe): Remove this method.
  void registerStaticUse(Element element) {
    _enqueueElement(element, null);
  }

  // TODO(ahe): Remove this method.
  void addToWorkList(Element element) {
    _enqueueElement(element, null);
  }

  // TODO(ahe): Remove this method.
  void forEach(_) {
    processQueue();
  }

  void processQueue() {
    do {
      do {
        while (!queueIsEmpty) {
          if (!_pendingEnqueuedUsages.isEmpty) {
            ElementUsage usage = _pendingEnqueuedUsages.removeFirst();
            AstElement element = usage.element;
            TreeElements treeElements = element.resolvedAst.elements;
            FletchRegistry registry =
                new FletchRegistryImplementation(compiler, treeElements);
            Selector selector = usage.selector;
            if (usage.tearOff) {
              compiler.context.backend.compileFunctionTearOffUsage(
                  element, selector, treeElements, registry);
            } else if (selector != null) {
              compiler.context.backend.compileElementUsage(
                  element, selector, treeElements, registry);
            } else {
              compiler.context.backend.compileElement(
                  element, treeElements, registry);
            }
          }
          if (!_pendingTypeTests.isEmpty) {
            TypeTest test = _pendingTypeTests.removeFirst();
            compiler.context.backend.compileTypeTest(test.element, test.type);
          }
        }
        dynamicCallEnqueuer.enqueueInstanceMethods(this);
      } while (!queueIsEmpty);
      // TODO(ahe): Pass recentClasses?
      compiler.backend.onQueueEmpty(this, null);
    } while (!queueIsEmpty);
  }

  bool checkNoEnqueuedInvokedInstanceMethods() {
    // TODO(ahe): Implement
    return true;
  }

  void logSummary(log(message)) {
    // TODO(ahe): Implement this.
  }

  void registerDynamicInvocation(UniverseSelector selector) {
    dynamicCallEnqueuer.enqueueSelector(selector);
  }

  void applyImpact(Element element, WorldImpact worldImpact) {
    assert(worldImpact == null);
  }

  void registerDynamicGetter(UniverseSelector selector) {
    dynamicCallEnqueuer.enqueueSelector(selector);
  }

  void registerDynamicSetter(UniverseSelector selector) {
    dynamicCallEnqueuer.enqueueSelector(selector);
  }

  void registerIsCheck(DartType type) {
    dynamicCallEnqueuer.enqueueTypeTest(type);
  }

  void _enqueueElement(
      Element element,
      Selector selector,
      {bool tearOff: false}) {
    if (selector != null) {
      _enqueueElement(element, null, tearOff: false);
    } else {
      assert(!tearOff);
    }
    ElementUsage usage = new ElementUsage(element, selector, tearOff);
    if (_enqueuedUsages.add(usage)) {
      _pendingEnqueuedUsages.addLast(usage);
      if (shouldReportEnqueuingOfElement(compiler, element)) {
        compiler.reportVerboseInfo(element, "called as $selector");
      }
    }
  }

  void recordElementUsage(
      Element element,
      Selector selector,
      {bool tearOff: false}) {
    _enqueueElement(element, selector, tearOff: tearOff);
  }

  void recordTypeTest(ClassElement element, InterfaceType type) {
    compiler.reportVerboseInfo(element, "type test $type");
    TypeTest test = new TypeTest(element, type);
    if (_typeTests.add(test)) {
      _pendingTypeTests.addLast(test);
    }
  }
}

class ElementUsage {
  final AstElement element;

  /// If selector is [null], this represents that [element] needs to be
  /// compiled.
  final Selector selector;

  final int hashCode;

  final bool tearOff;

  ElementUsage(Element element, Selector selector, bool tearOff)
      : element = element,
        selector = selector,
        tearOff = tearOff,
        hashCode = Hashing.mixHashCodeBits(
            Hashing.mixHashCodeBits(element.hashCode, selector.hashCode),
            tearOff.hashCode);

  bool operator ==(other) {
    return other is ElementUsage &&
        element == other.element && selector == other.selector &&
        tearOff == other.tearOff;
  }
}

class TypeTest {
  final ClassElement element;

  final InterfaceType type;

  final int hashCode;

  TypeTest(ClassElement element, InterfaceType type)
      : element = element,
        type = type,
        hashCode = Hashing.mixHashCodeBits(element.hashCode, type.hashCode);

  bool operator ==(other) {
    return other is TypeTest && element == other.element && type == other.type;
  }
}
