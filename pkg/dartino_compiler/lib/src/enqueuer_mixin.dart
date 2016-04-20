// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:collection' show
    Queue;

import 'package:compiler/src/enqueue.dart' show
    CodegenEnqueuer,
    EnqueueTask,
    EnqueuerStrategy,
    ItemCompilationContextCreator,
    QueueFilter;

import 'package:compiler/src/compiler.dart' show
    Compiler;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    ConstructorElement,
    Element,
    LibraryElement,
    TypedElement;

import 'package:compiler/src/universe/universe.dart' show
    Universe;

import 'package:compiler/src/universe/use.dart' show
    DynamicUse,
    StaticUse,
    TypeUse;

import 'package:compiler/src/universe/world_impact.dart' show
    ImpactUseCase,
    WorldImpact;

import 'package:compiler/src/dart_types.dart' show
    InterfaceType;

import 'package:compiler/src/common/work.dart' show
    WorkItem;

import 'package:compiler/src/common/resolution.dart' show
    Resolution;

import 'package:compiler/src/diagnostics/diagnostic_listener.dart' show
    DiagnosticReporter;

// TODO(ahe): Get rid of this file. Perhaps by having [DartinoEnqueuer] extend
// [CodegenEnqueuer].

get notImplemented => throw "not implemented";

class EnqueuerMixin implements CodegenEnqueuer {
  String get name => notImplemented;

  Compiler get compiler => notImplemented;

  ItemCompilationContextCreator get itemCompilationContextCreator
      => notImplemented;

  Map<String, Set<Element>> get instanceMembersByName => notImplemented;

  Map<String, Set<Element>> get instanceFunctionsByName => notImplemented;

  Set<ClassElement> get recentClasses => notImplemented;

  set recentClasses(Set<ClassElement> value) => notImplemented;

  Universe get universe => notImplemented;

  bool get queueIsClosed => notImplemented;

  set queueIsClosed(bool value) => notImplemented;

  EnqueueTask get task => notImplemented;

  set task(EnqueueTask value) => notImplemented;

  get nativeEnqueuer => notImplemented;

  set nativeEnqueuer(value) => notImplemented;

  bool get hasEnqueuedReflectiveElements => notImplemented;

  set hasEnqueuedReflectiveElements(bool value) => notImplemented;

  bool get hasEnqueuedReflectiveStaticFields => notImplemented;

  set hasEnqueuedReflectiveStaticFields(bool value) => notImplemented;

  bool get queueIsEmpty => notImplemented;

  bool get isResolutionQueue => notImplemented;

  QueueFilter get filter => notImplemented;

  Queue get queue => notImplemented;

  get generatedCode => notImplemented;

  Set<Element> get newlyEnqueuedElements => notImplemented;

  Set<DynamicUse> get newlySeenSelectors => notImplemented;

  bool get enabledNoSuchMethod => notImplemented;

  set enabledNoSuchMethod(bool value) => notImplemented;

  bool isProcessed(Element member) => notImplemented;

  void addToWorkList(Element element) => notImplemented;

  bool internalAddToWorkList(Element element) => notImplemented;

  void applyImpact(Element element, WorldImpact worldImpact) => notImplemented;

  void registerInstantiatedType(
      InterfaceType type,
      {bool mirrorUsage: false}) => notImplemented;

  bool checkNoEnqueuedInvokedInstanceMethods() => notImplemented;

  void processInstantiatedClassMembers(ClassElement cls) => notImplemented;

  void processInstantiatedClassMember(
      ClassElement cls,
      Element member) => notImplemented;

  void registerNoSuchMethod(Element noSuchMethod) => notImplemented;

  void enableIsolateSupport() => notImplemented;

  void processInstantiatedClass(ClassElement cls) => notImplemented;

  bool shouldIncludeElementDueToMirrors(
      Element element,
      {bool includedEnclosing}) => notImplemented;

  void logEnqueueReflectiveAction(action, [msg = ""]) => notImplemented;

  void enqueueReflectiveConstructor(
      ConstructorElement ctor,
      bool enclosingWasIncluded) => notImplemented;

  void enqueueReflectiveMember(
      Element element,
      bool enclosingWasIncluded) => notImplemented;

  void enqueueReflectiveElementsInClass(
      ClassElement cls,
      Iterable<ClassElement> recents,
      bool enclosingWasIncluded) => notImplemented;

  void enqueueReflectiveSpecialClasses() => notImplemented;

  void enqueueReflectiveElementsInLibrary(
      LibraryElement lib,
      Iterable<ClassElement> recents) => notImplemented;

  void enqueueReflectiveElements(
      Iterable<ClassElement> recents) => notImplemented;

  void enqueueReflectiveStaticFields(
      Iterable<Element> elements) => notImplemented;

  void processSet(
      Map<String, Set<Element>> map,
      String memberName,
      bool f(Element e)) => notImplemented;

  processInstanceMembers(String n, bool f(Element e)) => notImplemented;

  processInstanceFunctions(String n, bool f(Element e)) => notImplemented;

  void handleUnseenSelector(
      DynamicUse use) => notImplemented;

  void registerStaticUse(StaticUse element) => notImplemented;

  void registerCallMethodWithFreeTypeVariables(
      Element element) => notImplemented;

  void registerClosurizedMember(
      TypedElement element) => notImplemented;

  void forEach(void f(WorkItem work)) => notImplemented;

  bool onQueueEmpty(Iterable<ClassElement> recentClasses) => notImplemented;

  void logSummary(log(message)) => notImplemented;

  void forgetElement(Element element) => notImplemented;

  void handleUnseenSelectorInternal(DynamicUse dynamicUse) => notImplemented;

  bool isClassProcessed(ClassElement cls) => notImplemented;

  Iterable<ClassElement> get processedClasses => notImplemented;

  void registerDynamicUse(DynamicUse dynamicUse) => notImplemented;

  void registerStaticUseInternal(StaticUse staticUse) => notImplemented;

  void registerTypeUse(TypeUse typeUse) => notImplemented;

  DiagnosticReporter get reporter => notImplemented;

  Resolution get resolution => notImplemented;

  EnqueuerStrategy get strategy => notImplemented;

  ImpactUseCase get impactUse => const ImpactUseCase("EnqueuerMixin");

  get impactVisitor => notImplemented;

  set impactVisitor(_) => notImplemented;
}
