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
    LocalElement,
    Name;

import 'package:compiler/src/dart_types.dart' show
    DartType;

import 'package:compiler/src/diagnostics/spannable.dart' show
    Spannable;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue;

import 'package:compiler/src/universe/call_structure.dart' show
    CallStructure;

import 'dartino_context.dart' show
    DartinoContext;

import 'dartino_function_builder.dart' show
    DartinoFunctionBuilder;

import 'closure_environment.dart' show
    ClosureInfo;

import '../dartino_class_base.dart' show
    DartinoClassBase;

import '../dartino_system.dart' show
    DartinoFunctionBase,
    ParameterStubSignature;

import 'dartino_system_base.dart' show
    DartinoSystemBase;

/// Turns off enqueuing when generating debug information.
///
/// We generate debug information for one element at the time, on
/// demand. Generating this information shouldn't interact with the
/// enqueuer/registry/tree-shaking algorithm.
abstract class DebugRegistry {
  DartinoContext get context;
  DartinoFunctionBuilder get functionBuilder;

  void registerDynamicSelector(Selector selector) { }
  void registerStaticInvocation(FunctionElement element) { }
  void registerInstantiatedClass(ClassElement klass) { }
  void registerIsCheck(DartType type) { }
  void registerLocalInvoke(LocalElement element, Selector selector) { }
  void registerClosurization(FunctionElement element, _) { }

  int compileLazyFieldInitializer(FieldElement field) {
    return systemBase.getStaticFieldIndex(field, null);
  }

  DartinoClassBase getLocalFunctionClosureClass(
      FunctionElement function,
      ClosureInfo info) {
    DartinoFunctionBase closureFunctionBase =
        systemBase.lookupFunctionByElement(function);
    return systemBase.lookupClassById(closureFunctionBase.memberOf);
  }

  DartinoSystemBase get systemBase {
    // TODO(ahe): Would prefer to use predecessorSystem directly instead of
    // going through context.
    return context.backend.systemBuilder.predecessorSystem;
  }

  void reportUnimplementedError(Spannable spannable, String reason) {}

  void markConstantUsed(ConstantValue constant) {}

  DartinoFunctionBase getParameterStub(
      DartinoFunctionBase function,
      Selector selector) {
    CallStructure callStructure = selector.callStructure;
    ParameterStubSignature signature = new ParameterStubSignature(
        function.functionId, callStructure);
    return systemBase.lookupParameterStub(signature);
  }
}
