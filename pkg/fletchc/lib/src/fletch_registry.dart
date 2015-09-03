// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_codegen_registry;

import 'package:compiler/src/dart2jslib.dart' show
    CodegenRegistry,
    Registry;

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

abstract class FletchRegistry {
  final FletchEnqueuer world;

  factory FletchRegistry(
      FletchCompilerImplementation compiler,
      TreeElements treeElements) = FletchRegistryImplementation;

  FletchRegistry.internal(this.world);

  Registry get asRegistry;

  void registerStaticInvocation(Element element) {
    // TODO(ahe): Call a different method.
    world.registerStaticUse(element);
  }

  void registerInstantiatedClass(ClassElement element) {
    world.registerInstantiatedType(element.rawType, this.asRegistry);
  }

  void registerDynamicSetter(UniverseSelector selector) {
    world.registerDynamicSetter(selector);
  }

  void registerDynamicGetter(UniverseSelector selector) {
    world.registerDynamicGetter(selector);
  }

  void registerDynamicInvocation(UniverseSelector selector) {
    world.registerDynamicInvocation(selector);
  }

  void registerInstantiatedType(InterfaceType type) {
    world.registerInstantiatedType(type, this.asRegistry);
  }

}

@proxy
class FletchRegistryImplementation extends FletchRegistry
implements CodegenRegistry {
  final TreeElements treeElements;

  FletchRegistryImplementation(
      FletchCompilerImplementation compiler,
      this.treeElements)
      : super.internal(compiler.enqueuer.codegen);

  Registry get asRegistry => this;

  noSuchMethod(invocation) => super.noSuchMethod(invocation);

  // TODO(ahe): Remove this method, called by [Enqueuer], not [FletchEnqueuer].
  void registerDependency(Element element) {
    treeElements.registerDependency(element);
  }
}
