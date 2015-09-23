// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.dynamic_call_enqueuer;

import 'dart:collection' show
    Queue;

import 'package:compiler/src/universe/universe.dart' show
    CallStructure,
    Selector,
    UniverseSelector;

import 'package:compiler/src/dart_types.dart' show
    InterfaceType;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    Element,
    FunctionElement,
    LibraryElement,
    Name;

import 'fletch_compiler_implementation.dart' show
    FletchCompilerImplementation;

import 'fletch_enqueuer.dart' show
    shouldReportEnqueuingOfElement;

typedef void ElementUsage(Element element, Selector selector, {bool tearOff});

/// Implements the dynamic part of the tree-shaking algorithm.
///
/// By "dynamic" part we mean the part that is about matching instantiated
/// classes with called instance methods.
class DynamicCallEnqueuer {
  final FletchCompilerImplementation compiler;

  final Set<ClassElement> instantiatedClasses = new Set<ClassElement>();

  final Queue<ClassElement> pendingInstantiatedClasses =
      new Queue<ClassElement>();

  final Set<Selector> enqueuedSelectors = new Set<Selector>();

  final Queue<Selector> pendingSelectors = new Queue<Selector>();

  /// Set of functions that have been implicitly closurized aka tear-off.
  final Set<FunctionElement> implicitClosurizations =
      new Set<FunctionElement>();

  /// Queue of functions that have been implicitly closurized aka tear-off and
  /// have yet to be processed.
  final Queue<FunctionElement> pendingImplicitClosurizations =
      new Queue<FunctionElement>();

  DynamicCallEnqueuer(this.compiler);

  void registerInstantiatedType(InterfaceType type) {
    ClassElement cls = type.element.declaration;
    if (instantiatedClasses.add(cls)) {
      pendingInstantiatedClasses.addLast(cls);
    }
  }

  void enqueueApplicableMembers(
      ClassElement cls,
      Selector selector,
      ElementUsage enqueueElement) {
    Element member = cls.lookupByName(selector.memberName);
    if (member == null) return;
    if (!member.isInstanceMember) return;
    if (selector.isGetter) {
      if (member.isField || member.isGetter) {
        enqueueElement(member, selector);
      } else {
        // Tear-off.
        compiler.reportVerboseInfo(member, "enqueued as tear-off");
        // This lets the backend generate the tear-off getter because it is
        // told that [member] is used as a getter.
        enqueueElement(member, selector);
        // This registers [member] as an instantiated closure class.
        enqueueTearOff(member);
      }
    } else if (selector.isSetter) {
      if (member.isField || member.isSetter) {
        enqueueElement(member, selector);
      }
    } else if (member.isFunction && selector.signatureApplies(member)) {
      enqueueElement(member, selector);
    }
  }

  void enqueueTearOffIfApplicable(
      FunctionElement function,
      Selector selector,
      ElementUsage enqueueElement) {
    if (selector.isClosureCall && selector.signatureApplies(function)) {
      enqueueElement(function, selector, tearOff: true);
    }
  }

  void enqueueInstanceMethods(ElementUsage enqueueElement) {
    // TODO(ahe): Implement a faster way to iterate through selectors. For
    // example, use the same approach as dart2js uses where selectors are
    // grouped by name. This applies both to enqueuedSelectors and
    // pendingSelectors.
    while (pendingInstantiatedClasses.isNotEmpty) {
      ClassElement cls = pendingInstantiatedClasses.removeFirst();
      if (shouldReportEnqueuingOfElement(cls)) {
        compiler.reportVerboseInfo(cls, "was instantiated");
      }
      for (Selector selector in enqueuedSelectors) {
        // TODO(ahe): As we iterate over enqueuedSelectors, we may end up
        // processing calling _enqueueApplicableMembers twice for newly
        // instantiated classes. Once here, and then once more in the while
        // loop below.
        enqueueApplicableMembers(cls, selector, enqueueElement);
      }
    }
    while (pendingImplicitClosurizations.isNotEmpty) {
      FunctionElement function = pendingImplicitClosurizations.removeFirst();
      if (shouldReportEnqueuingOfElement(function)) {
        compiler.reportVerboseInfo(function, "was closurized");
      }
      for (Selector selector in enqueuedSelectors) {
        enqueueTearOffIfApplicable(function, selector, enqueueElement);
      }
    }
    while (pendingSelectors.isNotEmpty) {
      Selector selector = pendingSelectors.removeFirst();
      for (ClassElement cls in instantiatedClasses) {
        enqueueApplicableMembers(cls, selector, enqueueElement);
      }
      for (FunctionElement function in implicitClosurizations) {
        enqueueTearOffIfApplicable(function, selector, enqueueElement);
      }
    }
  }

  void enqueueSelector(UniverseSelector universeSelector) {
    assert(universeSelector.mask == null);
    Selector selector = universeSelector.selector;
    if (enqueuedSelectors.add(selector)) {
      pendingSelectors.add(selector);
    }
  }

  void enqueueTearOff(FunctionElement function) {
    if (implicitClosurizations.add(function)) {
      pendingImplicitClosurizations.add(function);
    }
  }

  void forgetElement(Element element) {
    // TODO(ahe): Make sure that the incremental compiler
    // (library_updater.dart) registers classes with schema changes as having
    // been instantiated.
    instantiatedClasses.remove(element);
  }
}
