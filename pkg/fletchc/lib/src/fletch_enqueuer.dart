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

import 'package:compiler/src/util/util.dart' show
    SpannableAssertionFailure;

import 'fletch_compiler_implementation.dart' show
    FletchCompilerImplementation;

import 'dynamic_call_enqueuer.dart' show
    DynamicCallEnqueuer;

import 'fletch_codegen_work_item.dart' show
    FletchCodegenWorkItem;

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
    if (codegen is FletchEnqueuer) {
      FletchEnqueuer fletchEnqueuer = codegen;
      fletchEnqueuer.dynamicCallEnqueuer.task = this;
    }
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

  final Set<Element> _enqueuedElements = new Set<Element>();

  final Queue<Element> _pendingEnqueuedElements = new Queue<Element>();

  final Set<Element> _processedElements = new Set<Element>();

  final DynamicCallEnqueuer dynamicCallEnqueuer;

  FletchEnqueuer(
      FletchCompilerImplementation compiler,
      this.itemCompilationContextCreator)
      : compiler = compiler,
        newlyEnqueuedElements = compiler.cacheStrategy.newSet(),
        dynamicCallEnqueuer = new DynamicCallEnqueuer(compiler);

  bool get queueIsEmpty => _pendingEnqueuedElements.isEmpty;

  bool get isResolutionQueue => false;

  QueueFilter get filter => compiler.enqueuerFilter;

  Set<UniverseSelector> get newlySeenSelectors {
    return dynamicCallEnqueuer.newlySeenSelectors;
  }

  void forgetElement(Element element) {
    newlyEnqueuedElements.remove(element);
    _enqueuedElements.remove(element);
    _processedElements.remove(element);
    dynamicCallEnqueuer.forgetElement(element);
  }

  void registerInstantiatedType(
      InterfaceType type,
      Registry registry,
      {bool mirrorUsage: false}) {
    dynamicCallEnqueuer.registerInstantiatedType(type);
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
          FletchCodegenWorkItem workItem = new FletchCodegenWorkItem(
              compiler, element, itemCompilationContextCreator());
          filter.processWorkItem(f, workItem);
          _processedElements.add(element);
        }
        dynamicCallEnqueuer.enqueueInstanceMethods(_enqueueElement);
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

  void _enqueueElement(Element element) {
    if (_enqueuedElements.add(element)) {
      _pendingEnqueuedElements.addLast(element);
      newlyEnqueuedElements.add(element);
      compiler.reportVerboseInfo(element, "enqueued this", forceVerbose: true);
    }
  }
}
