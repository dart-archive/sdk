// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// TODO(ahe): Get rid of this file. Perhaps by having [FletchEnqueuer] extend
// [CodegenEnqueuer].
part of fletchc.fletch_enqueuer;

get notImplemented => throw "not implemented";

class EnqueuerMixin implements CodegenEnqueuer {
  @override
  String get name => notImplemented;

  @override
  Compiler get compiler => notImplemented;

  @override
  ItemCompilationContextCreator get itemCompilationContextCreator
      => notImplemented;

  @override
  Map<String, Set<Element>> get instanceMembersByName => notImplemented;

  @override
  Map<String, Set<Element>> get instanceFunctionsByName => notImplemented;

  @override
  Set<ClassElement> get recentClasses => notImplemented;

  @override
  set recentClasses(Set<ClassElement> value) => notImplemented;

  @override
  Universe get universe => notImplemented;

  @override
  bool get queueIsClosed => notImplemented;

  @override
  set queueIsClosed(bool value) => notImplemented;

  @override
  EnqueueTask get task => notImplemented;

  @override
  set task(EnqueueTask value) => notImplemented;

  @override
  get nativeEnqueuer => notImplemented;

  @override
  set nativeEnqueuer(value) => notImplemented;

  @override
  bool get hasEnqueuedReflectiveElements => notImplemented;

  @override
  set hasEnqueuedReflectiveElements(bool value) => notImplemented;

  @override
  bool get hasEnqueuedReflectiveStaticFields => notImplemented;

  @override
  set hasEnqueuedReflectiveStaticFields(bool value) => notImplemented;

  @override
  bool get queueIsEmpty => notImplemented;

  @override
  bool get isResolutionQueue => notImplemented;

  @override
  QueueFilter get filter => notImplemented;

  @override
  Queue get queue => notImplemented;

  @override
  get generatedCode => notImplemented;

  @override
  Set<Element> get newlyEnqueuedElements => notImplemented;

  @override
  Set<DynamicUse> get newlySeenSelectors => notImplemented;

  @override
  bool get enabledNoSuchMethod => notImplemented;

  @override
  set enabledNoSuchMethod(bool value) => notImplemented;

  @override
  bool isProcessed(Element member) => notImplemented;

  @override
  void addToWorkList(Element element) => notImplemented;

  @override
  bool internalAddToWorkList(Element element) => notImplemented;

  @override
  void applyImpact(Element element, WorldImpact worldImpact) => notImplemented;

  @override
  void registerInstantiatedType(
      InterfaceType type,
      {bool mirrorUsage: false}) => notImplemented;

  @override
  bool checkNoEnqueuedInvokedInstanceMethods() => notImplemented;

  @override
  void processInstantiatedClassMembers(ClassElement cls) => notImplemented;

  @override
  void processInstantiatedClassMember(
      ClassElement cls,
      Element member) => notImplemented;

  @override
  void registerNoSuchMethod(Element noSuchMethod) => notImplemented;

  @override
  void enableIsolateSupport() => notImplemented;

  @override
  void processInstantiatedClass(ClassElement cls) => notImplemented;

  @override
  void registerInvocation(DynamicUse use) => notImplemented;

  @override
  void registerInvokedGetter(DynamicUse use) => notImplemented;

  @override
  void registerInvokedSetter(DynamicUse use) => notImplemented;

  @override
  bool shouldIncludeElementDueToMirrors(
      Element element,
      {bool includedEnclosing}) => notImplemented;

  @override
  void logEnqueueReflectiveAction(action, [msg = ""]) => notImplemented;

  @override
  void enqueueReflectiveConstructor(
      ConstructorElement ctor,
      bool enclosingWasIncluded) => notImplemented;

  @override
  void enqueueReflectiveMember(
      Element element,
      bool enclosingWasIncluded) => notImplemented;

  @override
  void enqueueReflectiveElementsInClass(
      ClassElement cls,
      Iterable<ClassElement> recents,
      bool enclosingWasIncluded) => notImplemented;

  @override
  void enqueueReflectiveSpecialClasses() => notImplemented;

  @override
  void enqueueReflectiveElementsInLibrary(
      LibraryElement lib,
      Iterable<ClassElement> recents) => notImplemented;

  @override
  void enqueueReflectiveElements(
      Iterable<ClassElement> recents) => notImplemented;

  @override
  void enqueueReflectiveStaticFields(
      Iterable<Element> elements) => notImplemented;

  @override
  void processSet(
      Map<String, Set<Element>> map,
      String memberName,
      bool f(Element e)) => notImplemented;

  @override
  processInstanceMembers(String n, bool f(Element e)) => notImplemented;

  @override
  processInstanceFunctions(String n, bool f(Element e)) => notImplemented;

  @override
  void handleUnseenSelector(
      DynamicUse use) => notImplemented;

  @override
  void registerStaticUse(StaticUse element) => notImplemented;

  @override
  void registerGetOfStaticFunction(FunctionElement element) => notImplemented;

  @override
  void registerDynamicInvocation(DynamicUse use) => notImplemented;

  @override
  void registerSelectorUse(DynamicUse use) => notImplemented;

  @override
  void registerDynamicGetter(DynamicUse use) => notImplemented;

  @override
  void registerDynamicSetter(DynamicUse use) => notImplemented;

  @override
  void registerGetterForSuperMethod(Element element) => notImplemented;

  @override
  void registerFieldGetter(Element element) => notImplemented;

  @override
  void registerFieldSetter(Element element) => notImplemented;

  @override
  void registerIsCheck(DartType type) => notImplemented;

  @override
  void registerCallMethodWithFreeTypeVariables(
      Element element) => notImplemented;

  @override
  void registerClosurizedMember(
      TypedElement element) => notImplemented;

  @override
  void registerClosureIfFreeTypeVariables(
      TypedElement element) => notImplemented;

  @override
  void registerClosure(
      LocalFunctionElement element) => notImplemented;

  @override
  void forEach(void f(WorkItem work)) => notImplemented;

  @override
  bool onQueueEmpty(Iterable<ClassElement> recentClasses) => notImplemented;

  @override
  void logSummary(log(message)) => notImplemented;

  @override
  void forgetElement(Element element) => notImplemented;

  @override
  void handleUnseenSelectorInternal(DynamicUse dynamicUse) => notImplemented;

  @override
  bool isClassProcessed(ClassElement cls) => notImplemented;

  @override
  Iterable<ClassElement> get processedClasses => notImplemented;

  @override
  void registerDynamicUse(DynamicUse dynamicUse) => notImplemented;

  @override
  void registerStaticUseInternal(StaticUse staticUse) => notImplemented;

  @override
  void registerTypeUse(TypeUse typeUse) => notImplemented;

  @override
  DiagnosticReporter get reporter => notImplemented;

  @override
  Resolution get resolution => notImplemented;

  @override
  EnqueuerStrategy get strategy => notImplemented;
}
