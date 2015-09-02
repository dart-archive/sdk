// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// TODO(ahe): Get rid of this file. Perhaps by having [FletchEnqueuer] extend
// [CodegenEnqueuer].
part of fletchc.fletch_enqueuer;

get notImplemented => throw "not implemented";

class EnqueuerMixin {
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

  Queue<CodegenWorkItem> get queue => notImplemented;

  get generatedCode => notImplemented;

  Set<Element> get newlyEnqueuedElements => notImplemented;

  Set<UniverseSelector> get newlySeenSelectors => notImplemented;

  bool get enabledNoSuchMethod => notImplemented;
  set enabledNoSuchMethod(bool value) => notImplemented;

  bool isProcessed(Element member) => notImplemented;

  void addToWorkList(Element element) => notImplemented;

  bool internalAddToWorkList(Element element) => notImplemented;

  void applyImpact(Element element, WorldImpact worldImpact) => notImplemented;

  void registerInstantiatedType(
      InterfaceType type,
      Registry registry,
      {bool mirrorUsage: false}) => notImplemented;

  bool checkNoEnqueuedInvokedInstanceMethods() => notImplemented;

  void processInstantiatedClassMembers(ClassElement cls) => notImplemented;

  void processInstantiatedClassMember(
      ClassElement cls,
      Element member) => notImplemented;

  void registerNoSuchMethod(Element noSuchMethod) => notImplemented;

  void enableIsolateSupport() => notImplemented;

  void processInstantiatedClass(ClassElement cls) => notImplemented;

  void registerInvocation(UniverseSelector selector) => notImplemented;

  void registerInvokedGetter(UniverseSelector selector) => notImplemented;

  void registerInvokedSetter(UniverseSelector selector) => notImplemented;

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
      UniverseSelector universeSelector) => notImplemented;

  void registerStaticUse(Element element) => notImplemented;

  void registerGetOfStaticFunction(FunctionElement element) => notImplemented;

  void registerDynamicInvocation(UniverseSelector selector) => notImplemented;

  void registerSelectorUse(UniverseSelector universeSelector) => notImplemented;

  void registerDynamicGetter(UniverseSelector selector) => notImplemented;

  void registerDynamicSetter(UniverseSelector selector) => notImplemented;

  void registerGetterForSuperMethod(Element element) => notImplemented;

  void registerFieldGetter(Element element) => notImplemented;

  void registerFieldSetter(Element element) => notImplemented;

  void registerIsCheck(DartType type) => notImplemented;

  void registerCallMethodWithFreeTypeVariables(
      Element element,
      Registry registry) => notImplemented;

  void registerClosurizedMember(
      TypedElement element,
      Registry registry) => notImplemented;

  void registerClosureIfFreeTypeVariables(
      TypedElement element,
      Registry registry) => notImplemented;

  void registerClosure(
      LocalFunctionElement element,
      Registry registry) => notImplemented;

  void forEach(void f(WorkItem work)) => notImplemented;

  bool onQueueEmpty(Iterable<ClassElement> recentClasses) => notImplemented;

  void logSummary(log(message)) => notImplemented;

  void forgetElement(Element element) => notImplemented;
}
