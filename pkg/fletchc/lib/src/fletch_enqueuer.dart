// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_enqueuer;

import 'dart:collection' show Queue;

import 'package:compiler/src/dart2jslib.dart' show
    CodegenEnqueuer,
    CodegenWorkItem,
    Compiler,
    CompilerTask,
    EnqueueTask,
    ItemCompilationContextCreator,
    QueueFilter,
    Registry,
    ResolutionEnqueuer,
    WorkItem,
    WorldImpact;

import 'package:compiler/src/util/util.dart' show
    Hashing;

import 'package:compiler/src/universe/universe.dart' show
    CallStructure,
    Universe,
    UniverseSelector;

import 'package:compiler/src/dart_types.dart' show
    DartType,
    InterfaceType;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    ConstructorElement,
    Element,
    FunctionElement,
    LibraryElement,
    LocalFunctionElement,
    Name,
    TypedElement;

import 'fletch_compiler_implementation.dart' show
    FletchCompilerImplementation;

part 'enqueuer_mixin.dart';

// TODO(ahe): Delete this constant when FletchEnqueuer is complete.
const bool useCustomEnqueuer = const bool.fromEnvironment(
    "fletchc.use-custom-enqueuer", defaultValue: false);

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
class TransitionalFletchEnqueuer extends CodegenEnqueuer {
  final Set<Element> _processedElements = new Set<Element>();

  TransitionalFletchEnqueuer(
      FletchCompilerImplementation compiler,
      ItemCompilationContextCreator itemCompilationContextCreator)
      : super(compiler, itemCompilationContextCreator);

  bool isProcessed(Element member) {
    return member.isAbstract || _processedElements.contains(member);
  }

  void applyImpact(Element element, WorldImpact worldImpact) {
    assert(isProcessed(element) || worldImpact == null);
    _processedElements.add(element);
  }

  void forgetElement(Element element) {
    super.forgetElement(element);
    _processedElements.remove(element);
  }
}

class FletchEnqueuer extends EnqueuerMixin implements CodegenEnqueuer {
  final ItemCompilationContextCreator itemCompilationContextCreator;

  final FletchCompilerImplementation compiler;

  final Map generatedCode = new Map();

  bool queueIsClosed = false;

  bool hasEnqueuedReflectiveElements = false;

  bool hasEnqueuedReflectiveStaticFields = false;

  EnqueueTask task;

  // TODO(ahe): Get rid of this?
  var nativeEnqueuer;

  final Universe universe = new Universe();

  final Set<Element> newlyEnqueuedElements;

  final Set<UniverseSelector> newlySeenSelectors;

  final Set<ClassElement> _instantiatedClasses = new Set<ClassElement>();

  final Queue<ClassElement> _pendingInstantiatedClasses =
      new Queue<ClassElement>();

  final Set<Element> _enqueuedElements = new Set<Element>();

  final Queue<Element> _pendingEnqueuedElements = new Queue<Element>();

  final Set<UntypedSelector> _enqueuedSelectors = new Set<UntypedSelector>();

  final Queue<UntypedSelector> _pendingSelectors =
      new Queue<UntypedSelector>();

  final Set<Element> _processedElements = new Set<Element>();

  FletchEnqueuer(
      FletchCompilerImplementation compiler,
      this.itemCompilationContextCreator)
      : compiler = compiler,
        newlyEnqueuedElements = compiler.cacheStrategy.newSet(),
        newlySeenSelectors = compiler.cacheStrategy.newSet();


  bool get queueIsEmpty => _pendingEnqueuedElements.isEmpty;

  bool get isResolutionQueue => false;

  QueueFilter get filter => compiler.enqueuerFilter;

  void forgetElement(Element element) {
    // TODO(ahe): Implement
    print("FletchEnqueuer.forgetElement isn't implemented");
  }

  void registerInstantiatedType(
      InterfaceType type,
      Registry registry,
      {bool mirrorUsage: false}) {
    ClassElement cls = type.element.declaration;
    if (_instantiatedClasses.add(cls)) {
      _pendingInstantiatedClasses.addLast(cls);
    }
  }

  void registerStaticUse(Element element) {
    _enqueueElement(element);
  }

  void addToWorkList(Element element) {
    _enqueueElement(element);
  }

  void forEach(void f(WorkItem work)) {
    do {
      do {
        while (!queueIsEmpty) {
          Element element = _pendingEnqueuedElements.removeFirst();
          if (element.isField) continue;
          CodegenWorkItem workItem = new CodegenWorkItem(
              compiler, element, itemCompilationContextCreator());
          filter.processWorkItem(f, workItem);
          _processedElements.add(element);
        }
        _enqueueInstanceMethods();
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
    log('Compiled ${generatedCode.length} methods.');
    nativeEnqueuer.logSummary(log);
  }

  bool isProcessed(Element member) => _processedElements.contains(member);

  void registerDynamicInvocation(UniverseSelector selector) {
    _enqueueDynamicSelector(selector);
  }

  void applyImpact(Element element, WorldImpact worldImpact) {
    assert(worldImpact == null);
  }

  void registerDynamicGetter(UniverseSelector selector) {
    _enqueueDynamicSelector(selector);
  }

  void registerDynamicSetter(UniverseSelector selector) {
    _enqueueDynamicSelector(selector);
  }

  void _enqueueElement(Element element) {
    if (_enqueuedElements.add(element)) {
      _pendingEnqueuedElements.addLast(element);
      newlyEnqueuedElements.add(element);
      compiler.reportVerboseInfo(element, "enqueued this", forceVerbose: true);
    }
  }

  Element _enqueueApplicableMembers(
      ClassElement cls,
      UntypedSelector selector) {
    Element member = cls.lookupByName(selector.name);
    if (member != null && task.resolution.isProcessed(member)) {
      // TODO(ahe): Check if selector applies; Don't consult resolution.
      _enqueueElement(member);
    }
  }

  void _enqueueInstanceMethods() {
    while (!_pendingInstantiatedClasses.isEmpty) {
      ClassElement cls = _pendingInstantiatedClasses.removeFirst();
      compiler.reportVerboseInfo(cls, "was instantiated", forceVerbose: true);
      for (UntypedSelector selector in _enqueuedSelectors) {
        // TODO(ahe): As we iterate over _enqueuedSelectors, we may end up
        // processing calling _enqueueApplicableMembers twice for newly
        // instantiated classes. Once here, and then once more in the while
        // loop below.
        _enqueueApplicableMembers(cls, selector);
      }
    }
    while (!_pendingSelectors.isEmpty) {
      UntypedSelector selector = _pendingSelectors.removeFirst();
      compiler.reportVerboseInfo(
          null, "$selector was called", forceVerbose: true);
      for (ClassElement cls in _instantiatedClasses) {
        _enqueueApplicableMembers(cls, selector);
      }
    }
  }

  void _enqueueDynamicSelector(UniverseSelector universeSelector) {
    UntypedSelector selector =
        new UntypedSelector.fromUniverseSelector(universeSelector);
    if (_enqueuedSelectors.add(selector)) {
      _pendingSelectors.add(selector);
      newlySeenSelectors.add(universeSelector);
    }
  }
}

/// Represents information about a call site.
///
/// This class differ from [UniverseSelector] in two key areas:
///
/// 1. Implements `operator ==` (and is thus suitable for use in a [Set])
/// 2. Has no type mask
class UntypedSelector {
  final Name name;

  final bool isGetter;

  final bool isSetter;

  final CallStructure structure;

  final int hashCode;

  UntypedSelector(
      this.name,
      this.isGetter,
      this.isSetter,
      this.structure,
      this.hashCode);

  factory UntypedSelector.fromUniverseSelector(UniverseSelector selector) {
    if (selector.mask != null) {
      throw new ArgumentError("[selector] has non-null type mask");
    }
    Name name = selector.selector.memberName;
    CallStructure structure = selector.selector.callStructure;
    bool isGetter = selector.selector.isGetter;
    bool isSetter = selector.selector.isSetter;
    int hash = Hashing.mixHashCodeBits(name.hashCode, structure.hashCode);
    hash = Hashing.mixHashCodeBits(hash, isSetter.hashCode);
    hash = Hashing.mixHashCodeBits(hash, isGetter.hashCode);
    return new UntypedSelector(name, isGetter, isSetter, structure, hash);
  }

  bool operator ==(other) {
    if (other is UntypedSelector) {
      return name == other.name &&
          isGetter == other.isGetter && isSetter == other.isSetter &&
          structure == other.structure;
    } else {
      return false;
    }
  }

  String toString() {
    return
        'UntypedSelector($name, '
        '${isGetter ? "getter, " : ""}'
        '${isSetter ? "setter, " : ""}'
        '$structure)';
  }
}
