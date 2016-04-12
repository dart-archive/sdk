// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_enqueuer;

import 'dart:collection' show
    Queue;

import 'package:compiler/src/common/tasks.dart' show
  CompilerTask;

import 'package:compiler/src/universe/world_impact.dart' show
    WorldImpact;

import 'package:compiler/src/types/types.dart' show
    TypeMaskStrategy;

import 'package:compiler/src/enqueue.dart' show
    ResolutionEnqueuer,
    CodegenEnqueuer,
    TreeShakingEnqueuerStrategy;

import 'package:compiler/src/compiler.dart' show
    Compiler;

import 'package:compiler/src/enqueue.dart' show
    QueueFilter,
    EnqueueTask;

import 'package:compiler/src/universe/selector.dart' show
    Selector;

import 'package:compiler/src/universe/universe.dart' show
    Universe;

import 'package:compiler/src/dart_types.dart' show
    DartType,
    InterfaceType;

import 'package:compiler/src/elements/elements.dart' show
    AstElement,
    ClassElement,
    Element,
    FunctionElement;

import 'package:compiler/src/resolution/tree_elements.dart' show
    TreeElements;

import 'package:compiler/src/util/util.dart' show
    Hashing;

import 'dartino_compiler_implementation.dart' show
    DartinoCompilerImplementation;

import 'dynamic_call_enqueuer.dart' show
    Closurization,
    DynamicCallEnqueuer,
    UsageRecorder;

import 'dartino_registry.dart' show
    ClosureKind,
    DartinoRegistry;

import 'package:compiler/src/enqueue.dart' show
    EnqueuerStrategy,
    ItemCompilationContextCreator;

import 'enqueuer_mixin.dart' show
    EnqueuerMixin;

/// True if enqueuing of system libraries should be reported in verbose mode.
const bool logSystemLibraries =
    const bool.fromEnvironment("dartino_compiler.logSystemLibraries");

/// Returns true if enqueuing of [element] should be reported in verbose
/// mode. See [logSystemLibraries].
bool shouldReportEnqueuingOfElement(Compiler compiler, Element element) {
  if (logSystemLibraries) return true;
  return compiler.inUserCode(element);
}

/// Custom enqueuer for Dartino.
class DartinoEnqueueTask extends CompilerTask implements EnqueueTask {
  final ResolutionEnqueuer resolution;

  final DartinoEnqueuer codegen;

  DartinoEnqueueTask(DartinoCompilerImplementation compiler)
    : resolution = new ResolutionEnqueuer(
          compiler, compiler.backend.createItemCompilationContext,
          compiler.analyzeOnly && compiler.analyzeMain
              ? const EnqueuerStrategy() : const TreeShakingEnqueuerStrategy()),
      codegen = new DartinoEnqueuer(
          compiler, compiler.backend.createItemCompilationContext),
      super(compiler) {
    codegen.task = this;
    resolution.task = this;
    codegen.nativeEnqueuer = compiler.backend.nativeCodegenEnqueuer(codegen);

    resolution.nativeEnqueuer =
        compiler.backend.nativeResolutionEnqueuer(resolution);
  }

  String get name => 'Dartino enqueue';

  void forgetElement(Element element) {
    resolution.forgetElement(element);
    codegen.forgetElement(element);
  }
}

class DartinoEnqueuer extends EnqueuerMixin
    implements CodegenEnqueuer, UsageRecorder {
  final ItemCompilationContextCreator itemCompilationContextCreator;

  final DartinoCompilerImplementation compiler;

  bool queueIsClosed = false;

  bool hasEnqueuedReflectiveElements = false;

  bool hasEnqueuedReflectiveStaticFields = false;

  EnqueueTask task;

  // TODO(ahe): Get rid of this?
  var nativeEnqueuer;

  final Universe universe = new Universe(const TypeMaskStrategy());

  final Set<ElementUsage> _enqueuedUsages = new Set<ElementUsage>();
  final Map<Element, List<ElementUsage>> _enqueuedUsagesByElement =
      <Element, List<ElementUsage>>{};

  final Queue<ElementUsage> _pendingEnqueuedUsages =
      new Queue<ElementUsage>();

  final Set<TypeTest> _typeTests = new Set<TypeTest>();

  final Queue<TypeTest> _pendingTypeTests = new Queue<TypeTest>();

  final DynamicCallEnqueuer dynamicCallEnqueuer;

  DartinoEnqueuer(
      DartinoCompilerImplementation compiler,
      this.itemCompilationContextCreator)
      : compiler = compiler,
        dynamicCallEnqueuer = new DynamicCallEnqueuer(compiler);

  bool get queueIsEmpty {
    return _pendingEnqueuedUsages.isEmpty && _pendingTypeTests.isEmpty;
  }

  bool get isResolutionQueue => false;

  QueueFilter get filter => compiler.enqueuerFilter;

  void forgetElement(Element element) {
    List<ElementUsage> usages = _enqueuedUsagesByElement[element];
    if (usages != null) {
      _enqueuedUsages.removeAll(usages);
    }
    dynamicCallEnqueuer.forgetElement(element);
  }

  void registerInstantiatedType(
      InterfaceType type,
      {bool mirrorUsage: false}) {
    dynamicCallEnqueuer.registerInstantiatedType(type);
  }

  // TODO(ahe): Remove this method.
  void registerStaticInvocation(FunctionElement function) {
    _enqueueElement(function, null, null);
  }

  // TODO(ahe): Remove this method.
  void addToWorkList(Element element) {
    _enqueueElement(element, null, null);
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
            DartinoRegistry registry = new DartinoRegistry(compiler);
            Selector selector = usage.selector;
            if (usage.closureKind != null) {
              compiler.context.backend.compileClosurizationUsage(
                  element, selector, treeElements, registry, usage.closureKind);
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

  void registerDynamicSelector(Selector selector) {
    dynamicCallEnqueuer.enqueueSelector(selector);
  }

  void applyImpact(Element element, WorldImpact worldImpact) {
    assert(worldImpact == null);
  }

  void registerIsCheck(DartType type) {
    dynamicCallEnqueuer.enqueueTypeTest(type);
  }

  void _enqueueElement(
      Element element,
      Selector selector,
      ClosureKind closureKind) {
    if (selector != null) {
      _enqueueElement(element, null, null);
    } else {
      assert(closureKind == null);
    }
    ElementUsage usage = new ElementUsage(element, selector, closureKind);
    if (_enqueuedUsages.add(usage)) {
      _enqueuedUsagesByElement
          .putIfAbsent(element, () => <ElementUsage>[]).add(usage);
      _pendingEnqueuedUsages.addLast(usage);
      if (shouldReportEnqueuingOfElement(compiler, element)) {
        compiler.reportVerboseInfo(element, "called as $selector");
      }
    }
  }

  void recordElementUsage(Element element, Selector selector) {
    if (!element.isParameter) {
      _enqueueElement(element, selector, null);
    }
  }

  void recordClosurizationUsage(
      Closurization closurization,
      Selector selector) {
    _enqueueElement(closurization.function, selector, closurization.kind);
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

  /// Non-null if this is a usage of [element] as a closure, for example, a
  /// tear-off
  final ClosureKind closureKind;

  ElementUsage(Element element, Selector selector, ClosureKind closureKind)
      : element = element,
        selector = selector,
        closureKind = closureKind,
        hashCode = Hashing.mixHashCodeBits(
            Hashing.mixHashCodeBits(element.hashCode, selector.hashCode),
            closureKind.hashCode);

  bool operator ==(other) {
    return other is ElementUsage &&
        element == other.element && selector == other.selector &&
        closureKind == other.closureKind;
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
