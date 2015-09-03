// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.dynamic_call_enqueuer;

import 'dart:collection' show
    Queue;

import 'package:compiler/src/dart2jslib.dart' show
    EnqueueTask;

import 'package:compiler/src/universe/universe.dart' show
    CallStructure,
    UniverseSelector;

import 'package:compiler/src/dart_types.dart' show
    InterfaceType;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    Element,
    Name;

import 'package:compiler/src/util/util.dart' show
    Hashing;

import 'fletch_compiler_implementation.dart' show
    FletchCompilerImplementation;

/// Implements the dynamic part of the tree-shaking algorithm.
///
/// By "dynamic" part we mean the part that is about matching instantiated
/// classes with called instance methods.
class DynamicCallEnqueuer {
  final FletchCompilerImplementation compiler;

  final Set<ClassElement> instantiatedClasses = new Set<ClassElement>();

  final Queue<ClassElement> pendingInstantiatedClasses =
      new Queue<ClassElement>();

  final Set<UntypedSelector> enqueuedSelectors = new Set<UntypedSelector>();

  final Queue<UntypedSelector> pendingSelectors =
      new Queue<UntypedSelector>();

  final Set<UniverseSelector> newlySeenSelectors;

  EnqueueTask task;

  DynamicCallEnqueuer(FletchCompilerImplementation compiler)
      : compiler = compiler,
        newlySeenSelectors = compiler.cacheStrategy.newSet();

  void registerInstantiatedType(InterfaceType type) {
    ClassElement cls = type.element.declaration;
    if (instantiatedClasses.add(cls)) {
      pendingInstantiatedClasses.addLast(cls);
    }
  }

  void enqueueApplicableMembers(
      ClassElement cls,
      UntypedSelector selector,
      void enqueueElement(Element element)) {
    Element member = cls.lookupByName(selector.name);
    if (member != null && task.resolution.isProcessed(member)) {
      // TODO(ahe): Check if selector applies; Don't consult resolution.
      enqueueElement(member);
    }
  }

  void enqueueInstanceMethods(void enqueueElement(Element element)) {
    while (!pendingInstantiatedClasses.isEmpty) {
      ClassElement cls = pendingInstantiatedClasses.removeFirst();
      compiler.reportVerboseInfo(cls, "was instantiated", forceVerbose: true);
      for (UntypedSelector selector in enqueuedSelectors) {
        // TODO(ahe): As we iterate over enqueuedSelectors, we may end up
        // processing calling _enqueueApplicableMembers twice for newly
        // instantiated classes. Once here, and then once more in the while
        // loop below.
        enqueueApplicableMembers(cls, selector, enqueueElement);
      }
    }
    while (!pendingSelectors.isEmpty) {
      UntypedSelector selector = pendingSelectors.removeFirst();
      compiler.reportVerboseInfo(
          null, "$selector was called", forceVerbose: true);
      for (ClassElement cls in instantiatedClasses) {
        enqueueApplicableMembers(cls, selector, enqueueElement);
      }
    }
  }

  void enqueueSelector(UniverseSelector universeSelector) {
    UntypedSelector selector =
        new UntypedSelector.fromUniverseSelector(universeSelector);
    if (enqueuedSelectors.add(selector)) {
      pendingSelectors.add(selector);
      newlySeenSelectors.add(universeSelector);
    }
  }

  void forgetElement(Element element) {
    // TODO(ahe): Make sure that the incremental compiler
    // (library_updater.dart) registers classes with schema changes as having
    // been instantiated.
    instantiatedClasses.remove(element);
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
