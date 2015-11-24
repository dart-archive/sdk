// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_codegen_registry;

import 'package:compiler/src/compiler.dart' show
    GlobalDependencyRegistry;

import 'package:compiler/src/common/codegen.dart' show
    CodegenRegistry;

import 'package:compiler/src/common/registry.dart' show
    Registry;

import 'package:compiler/src/universe/selector.dart' show
    Selector;

import 'package:compiler/src/universe/use.dart' show
    DynamicUse,
    StaticUse;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    Element,
    FunctionElement,
    LocalElement;

import 'package:compiler/src/dart_types.dart' show
    DartType,
    InterfaceType;

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

class FletchRegistry {
  final FletchEnqueuer world;

  FletchRegistry(FletchCompilerImplementation compiler)
      : world = compiler.enqueuer.codegen;

  void registerStaticUse(StaticUse staticUse) {
    // TODO(ahe): Call a different method.
    world.registerStaticUse(staticUse);
  }

  void registerInstantiatedClass(ClassElement element) {
    world.registerInstantiatedType(element.rawType);
  }

  void registerDynamicUse(Selector selector) {
    world.registerDynamicUse(new DynamicUse(selector, null));
  }

  void registerInstantiatedType(InterfaceType type) {
    world.registerInstantiatedType(type);
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
