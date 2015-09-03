// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_codegen_registry;

import 'package:compiler/src/dart2jslib.dart' show
    CodegenRegistry;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue;

import 'package:compiler/src/universe/universe.dart' show
    Selector,
    UniverseSelector;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    Element,
    FunctionElement,
    LocalFunctionElement;

import 'package:compiler/src/resolution/resolution.dart' show
    TreeElements;

import 'package:compiler/src/dart_types.dart' show
    DartType,
    InterfaceType;

import 'package:compiler/src/util/util.dart' show
    Setlet;

import 'fletch_backend.dart' show
    FletchBackend;

import 'fletch_compiler_implementation.dart' show
    FletchCompilerImplementation;

import 'fletch_enqueuer.dart' show
    FletchEnqueuer;

get _notImplemented => throw "not implemented";

// TODO(ahe): This class is a copy of CodegenRegistry, consider subclassing.
class FletchCodegenRegistry implements CodegenRegistry {
  final FletchCompilerImplementation compiler;
  final TreeElements treeElements;

  FletchCodegenRegistry(this.compiler, this.treeElements);

  bool get isForResolution => false;

  Element get currentElement => treeElements.analyzedElement;

  Setlet<Element> get otherDependencies => _notImplemented;

  // TODO(ahe): Restore return type when TransitionalFletchEnqueuer is gone.
  /* FletchEnqueuer */ get world => compiler.enqueuer.codegen;

  // TODO(ahe): Restore return type when super.backend doesn't use JS backend.
  /* FletchBackend */ get backend => compiler.backend;

  void registerDependency(Element element) {
    treeElements.registerDependency(element);
  }

  void registerInlining(Element inlinedElement, Element context) {
    if (compiler.dumpInfo) {
      compiler.dumpInfoTask.registerInlined(inlinedElement, context);
    }
  }

  void registerInstantiatedClass(ClassElement element) {
    world.registerInstantiatedType(element.rawType, this);
  }

  void registerInstantiatedType(InterfaceType type) {
    world.registerInstantiatedType(type, this);
  }

  void registerStaticUse(Element element) {
    // TODO(ahe): Throw here.
    world.registerStaticUse(element);
  }

  void registerDynamicInvocation(UniverseSelector selector) {
    world.registerDynamicInvocation(selector);
    compiler.dumpInfoTask.elementUsesSelector(currentElement, selector);
  }

  void registerDynamicSetter(UniverseSelector selector) {
    world.registerDynamicSetter(selector);
    compiler.dumpInfoTask.elementUsesSelector(currentElement, selector);
  }

  void registerDynamicGetter(UniverseSelector selector) {
    world.registerDynamicGetter(selector);
    compiler.dumpInfoTask.elementUsesSelector(currentElement, selector);
  }

  void registerGetterForSuperMethod(Element element) {
    world.registerGetterForSuperMethod(element);
  }

  void registerFieldGetter(Element element) {
    world.registerFieldGetter(element);
  }

  void registerFieldSetter(Element element) {
    world.registerFieldSetter(element);
  }

  void registerIsCheck(DartType type) {
    world.registerIsCheck(type);
    backend.registerIsCheckForCodegen(type, world, this);
  }

  void registerCompileTimeConstant(ConstantValue constant) {
    backend.registerCompileTimeConstant(constant, this);
    backend.constants.addCompileTimeConstantForEmission(constant);
  }

  void registerTypeVariableBoundsSubtypeCheck(DartType subtype,
                                              DartType supertype) {
    backend.registerTypeVariableBoundsSubtypeCheck(subtype, supertype);
  }

  void registerInstantiatedClosure(LocalFunctionElement element) {
    backend.registerInstantiatedClosure(element, this);
  }

  void registerGetOfStaticFunction(FunctionElement element) {
    world.registerGetOfStaticFunction(element);
  }

  void registerSelectorUse(Selector selector) {
    world.registerSelectorUse(new UniverseSelector(selector, null));
  }

  void registerConstSymbol(String name) {
    backend.registerConstSymbol(name, this);
  }

  void registerSpecializedGetInterceptor(Set<ClassElement> classes) {
    backend.registerSpecializedGetInterceptor(classes);
  }

  void registerUseInterceptor() {
    backend.registerUseInterceptor(world);
  }

  void registerTypeConstant(ClassElement element) {
    backend.customElementsAnalysis.registerTypeConstant(element, world);
  }

  void registerStaticInvocation(Element element) {
    // TODO(ahe): Call a different method.
    world.registerStaticUse(element);
  }

  void registerSuperInvocation(Element element) {
    // TODO(ahe): Call a different method.
    world.registerStaticUse(element);
  }

  void registerDirectInvocation(Element element) {
    // TODO(ahe): Call a different method.
    world.registerStaticUse(element);
  }

  void registerInstantiation(InterfaceType type) {
    world.registerInstantiatedType(type, this);
  }

  void registerAsyncMarker(FunctionElement element) {
    backend.registerAsyncMarker(element, world, this);
  }
}
