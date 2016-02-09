// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.debug_registry;

import 'package:compiler/src/universe/selector.dart' show
    Selector;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    FieldElement,
    FunctionElement,
    LocalElement;

import 'package:compiler/src/dart_types.dart' show
    DartType;

import 'package:compiler/src/diagnostics/spannable.dart' show
    Spannable;

import 'package:compiler/src/universe/use.dart' show
    DynamicUse,
    StaticUse;

import 'dartino_context.dart' show
    DartinoContext;

import 'dartino_function_builder.dart' show
    DartinoFunctionBuilder;

/// Turns off enqueuing when generating debug information.
///
/// We generate debug information for one element at the time, on
/// demand. Generating this information shouldn't interact with the
/// enqueuer/registry/tree-shaking algorithm.
abstract class DebugRegistry {
  DartinoContext get context;
  DartinoFunctionBuilder get functionBuilder;

  void registerDynamicUse(Selector selector) { }
  void registerDynamicGetter(Selector selector) { }
  void registerDynamicSetter(Selector selector) { }
  void registerStaticUse(StaticUse use) { }
  void registerInstantiatedClass(ClassElement klass) { }
  void registerIsCheck(DartType type) { }
  void registerLocalInvoke(LocalElement element, Selector selector) { }
  void registerClosurization(FunctionElement element, _) { }

  void generateUnimplementedError(Spannable spannable, String reason) {
    context.backend.generateUnimplementedError(
        spannable, reason, functionBuilder, suppressHint: true);
  }
}
