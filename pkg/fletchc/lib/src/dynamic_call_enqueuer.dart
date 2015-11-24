// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.dynamic_call_enqueuer;

import 'dart:collection' show
    Queue;

import 'package:compiler/src/universe/selector.dart' show
    Selector;

import 'package:compiler/src/universe/use.dart' show
    DynamicUse;

import 'package:compiler/src/dart_types.dart' show
    DartType,
    InterfaceType,
    TypeKind;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    Element,
    FunctionElement,
    LibraryElement,
    MemberElement,
    Name;

import 'package:compiler/src/common/names.dart' show
    Identifiers,
    Names;

import 'package:compiler/src/util/util.dart' show
    Hashing;

import 'fletch_compiler_implementation.dart' show
    FletchCompilerImplementation;

import 'fletch_enqueuer.dart' show
    shouldReportEnqueuingOfElement;

import 'fletch_registry.dart' show
    ClosureKind;

abstract class UsageRecorder {
  void recordElementUsage(Element element, Selector selector);

  void recordClosurizationUsage(Closurization closurization, Selector selector);

  void recordTypeTest(ClassElement element, InterfaceType type);
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

  /// Set of functions that have been closurized
  final Set<Closurization> implicitClosurizations = new Set<Closurization>();

  /// Queue of functions that have been closurized and have yet to be
  /// processed
  final Queue<Closurization> pendingImplicitClosurizations =
      new Queue<Closurization>();

  final Set<InterfaceType> typeTests = new Set<InterfaceType>();

  final Queue<InterfaceType> pendingTypeTests = new Queue<InterfaceType>();

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
      UsageRecorder recorder) {
    Element member = cls.lookupByName(selector.memberName);
    if (member == null) return;
    if (!member.isInstanceMember) return;
    if (selector.isGetter) {
      if (member.isField || member.isGetter) {
        recorder.recordElementUsage(member, selector);
      } else {
        // Tear-off.
        compiler.reportVerboseInfo(member, "enqueued as tear-off");
        // This lets the backend generate the tear-off getter because it is
        // told that [member] is used as a getter.
        recorder.recordElementUsage(member, selector);
        // This registers [member] as an instantiated closure class.
        enqueueClosure(member, ClosureKind.tearOff);
      }
    } else if (selector.isSetter) {
      if (member.isField || member.isSetter) {
        recorder.recordElementUsage(member, selector);
      }
    } else if (member.isFunction && selector.signatureApplies(member)) {
      recorder.recordElementUsage(member, selector);
    } else if (member.isGetter || member.isField) {
      // A getter/field can be invoked as a method, for example, if the getter
      // returns a closure.
      recorder.recordElementUsage(member, selector);
    }
  }

  void enqueueClosureIfApplicable(
      Closurization closurization,
      Selector selector,
      UsageRecorder recorder) {
    FunctionElement function = closurization.function;
    if ((selector.isGetter || selector.isCall) &&
        selector.memberName == Names.call &&
        selector.signatureApplies(function)) {
      recorder.recordClosurizationUsage(closurization, selector);
    }
  }

  void enqueueApplicableTypeTests(
      ClassElement cls,
      InterfaceType type,
      UsageRecorder recorder) {
    if (cls == type.element) {
      recorder.recordTypeTest(cls, type);
      return;
    }
    for (DartType supertype in cls.allSupertypes) {
      if (supertype.element == type.element) {
        recorder.recordTypeTest(cls, type);
        return;
      }
    }
  }

  void enqueueInstanceMethods(UsageRecorder recorder) {
    // TODO(ahe): Implement a faster way to iterate through selectors. For
    // example, use the same approach as dart2js uses where selectors are
    // grouped by name. This applies both to enqueuedSelectors and
    // pendingSelectors.
    while (pendingInstantiatedClasses.isNotEmpty) {
      ClassElement cls = pendingInstantiatedClasses.removeFirst();
      if (shouldReportEnqueuingOfElement(compiler, cls)) {
        compiler.reportVerboseInfo(cls, "was instantiated");
      }
      for (Selector selector in enqueuedSelectors) {
        // TODO(ahe): As we iterate over enqueuedSelectors, we may end up
        // processing calling _enqueueApplicableMembers twice for newly
        // instantiated classes. Once here, and then once more in the while
        // loop below.
        enqueueApplicableMembers(cls, selector, recorder);
      }
      for (InterfaceType type in typeTests) {
        enqueueApplicableTypeTests(cls, type, recorder);
      }
    }
    while (pendingImplicitClosurizations.isNotEmpty) {
      Closurization closurization = pendingImplicitClosurizations.removeFirst();
      if (shouldReportEnqueuingOfElement(compiler, closurization.function)) {
        compiler.reportVerboseInfo(closurization.function, "was closurized");
      }
      for (Selector selector in enqueuedSelectors) {
        enqueueClosureIfApplicable(closurization, selector, recorder);
      }
      // TODO(ahe): Also enqueue type tests here.
    }
    while (pendingSelectors.isNotEmpty) {
      Selector selector = pendingSelectors.removeFirst();
      for (ClassElement cls in instantiatedClasses) {
        enqueueApplicableMembers(cls, selector, recorder);
      }
      for (Closurization closurization in implicitClosurizations) {
        enqueueClosureIfApplicable(closurization, selector, recorder);
      }
    }
    while(!pendingTypeTests.isEmpty) {
      InterfaceType type = pendingTypeTests.removeFirst();
      for (ClassElement cls in instantiatedClasses) {
        enqueueApplicableTypeTests(cls, type, recorder);
      }
      // TODO(ahe): Also enqueue type tests for closures.
    }
  }

  void enqueueSelector(DynamicUse use) {
    assert(use.mask == null);
    Selector selector = use.selector;
    if (enqueuedSelectors.add(selector)) {
      pendingSelectors.add(selector);
    }
  }

  void enqueueClosure(FunctionElement function, ClosureKind kind) {
    Closurization closurization = new Closurization(function, kind);
    if (implicitClosurizations.add(closurization)) {
      pendingImplicitClosurizations.add(closurization);
    }
  }

  void forgetElement(Element element) {
    void revisitClass(ClassElement cls) {
      if (instantiatedClasses.remove(cls)) {
        // [cls] was already instantiated, now we need to make sure enqueue its
        // members again in [enqueueInstanceMethods] above.
        pendingInstantiatedClasses.add(cls);
      }
    }
    if (!instantiatedClasses.remove(element)) {
      // If a class is removed, the incremental compiler will first forget its
      // members. This can move the class to pendingInstantiatedClasses.
      pendingInstantiatedClasses.remove(element);
    }
    if (element.isInstanceMember) {
      ClassElement modifiedClass = element.enclosingClass;
      revisitClass(modifiedClass);
      MemberElement member = element;
      for (ClassElement cls in instantiatedClasses) {
        // TODO(ahe): Make O(1).
        if (cls.lookupByName(member.memberName) == member) {
          revisitClass(cls);
          // Once we have found one class that implements [member], we're
          // done. When we later call [enqueueInstanceMethods] (via
          // [FletchEnqueuer.processQueue]) the method will be enqueued again
          // (if it exists).
          break;
        }
      }
    }
    List<Closurization> toBeRemoved = <Closurization>[];
    for (Closurization closurization in implicitClosurizations) {
      if (closurization.function == element) {
        toBeRemoved.add(closurization);
      }
    }
    implicitClosurizations.removeAll(toBeRemoved);
  }

  void enqueueTypeTest(DartType type) {
    type = type.asRaw();
    switch (type.kind) {
      case TypeKind.INTERFACE:
        enqueueRawInterfaceType(type);
        break;

      default:
        // Ignored.
        break;
    }
  }

  void enqueueRawInterfaceType(InterfaceType type) {
    assert(type.isRaw);
    if (typeTests.add(type)) {
      pendingTypeTests.add(type);
    }
  }
}

/// Track that [function] is used as a closure. This can happen for various
/// reasons, see [ClosureKind] for more details. In practical terms, this means
/// that we need a class whose `call` method invokes [function]. For
/// [ClosureKind.functionLike], the class is a normal class with source
/// code. For most other kinds, the class is synthetic and doesn't have a
/// corresponding element.
class Closurization {
  final FunctionElement function;

  final ClosureKind kind;

  final int hashCode;

  Closurization(FunctionElement function, ClosureKind kind)
      : function = function,
        kind = kind,
        hashCode = Hashing.mixHashCodeBits(function.hashCode, kind.hashCode);

  bool operator ==(other) {
    return other is Closurization &&
        function == other.function && kind == other.kind;
  }

  String toString() => "Closurization($function, $kind)";
}
