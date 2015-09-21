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

/// True if enqueuing of system libraries should be reported in verbose mode.
const bool logSystemLibraries =
    const bool.fromEnvironment("fletchc.logSystemLibraries");

typedef void ElementUsage(Element element, Selector selector);

/// Returns true if enqueuing of [element] should be reported in verbose
/// mode. See [logSystemLibraries].
bool shouldReportEnqueuingOfElement(Element element) {
  if (logSystemLibraries) return true;
  LibraryElement library = element.library;
  return !library.isPlatformLibrary && !library.isInternalLibrary;
}

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
        enqueueElement(member, selector);
      }
    } else if (selector.isSetter) {
      if (member.isField || member.isSetter) {
        enqueueElement(member, selector);
      }
    } else if (member.isFunction && selector.signatureApplies(member)) {
      enqueueElement(member, selector);
    }
  }

  void enqueueInstanceMethods(ElementUsage enqueueElement) {
    while (!pendingInstantiatedClasses.isEmpty) {
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
    while (!pendingSelectors.isEmpty) {
      Selector selector = pendingSelectors.removeFirst();
      for (ClassElement cls in instantiatedClasses) {
        enqueueApplicableMembers(cls, selector, enqueueElement);
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

  void forgetElement(Element element) {
    // TODO(ahe): Make sure that the incremental compiler
    // (library_updater.dart) registers classes with schema changes as having
    // been instantiated.
    instantiatedClasses.remove(element);
  }
}
