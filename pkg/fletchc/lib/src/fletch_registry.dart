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
    LocalElement;

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

/// Represents ways a function can used as a closure.  See also [Closurization]
/// in [./dynamic_call_enqueuer.dart].
enum ClosureKind {
  // Notes:
  //
  // * We don't need to distinguish between instance/static/top-level
  // tear-offs. This information is implicit in the function whose usage is
  // described..
  //
  // * [localFunction] is sufficiently different from [tearOff], that it
  // probably leads to less confusion having separate kinds; we don't normally
  // refer to a local function closure as a "tear-off". But the information is
  // implicit in the associated element.
  //
  // * [functionLike] is different from [tearOff] as the former will not imply
  // a synthetic class (stubs are added to the enclosing/holder class)
  //
  // * [superTearOff] is probably redundant with [tearOff].

  /// The result of getting a member function (this can be an instance, a
  /// static, or top-level function). See also [functionLikeTearOff].
  tearOff,

  /// The "call" method of a class that has a call method (and thus implements
  /// [Function])
  functionLike,

  /// The result of getting an instance method named "call"
  functionLikeTearOff,

  /// A local function (aka closure) that has escaped
  localFunction,

  /// The result of getting a super instance function
  superTearOff,
}

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

  void registerIsCheck(DartType type) {
    world.registerIsCheck(type);
  }

  void registerLocalInvoke(LocalElement element, Selector selector) {
    world.recordElementUsage(element, selector);
  }

  void registerClosurization(FunctionElement function, ClosureKind kind) {
    switch (kind) {
      case ClosureKind.superTearOff:
      case ClosureKind.tearOff:
        assert(function.memberContext == function);
        break;

      case ClosureKind.functionLike:
      case ClosureKind.functionLikeTearOff:
        assert(function.memberContext == function);
        assert(function.isInstanceMember);
        assert(function.name == "call");
        break;

      case ClosureKind.localFunction:
        assert(function.memberContext != function);
    }
    world.dynamicCallEnqueuer.enqueueClosure(function, kind);
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
