// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_context;

import 'package:compiler/src/tree/tree.dart' show
    Node;

import 'package:compiler/src/universe/universe.dart' show
    Selector;

import 'package:compiler/src/elements/elements.dart' show
    Element,
    FieldElement,
    FunctionElement,
    FunctionSignature,
    ParameterElement;

import 'package:compiler/src/resolution/resolution.dart' show
    TreeElements;

import 'package:compiler/src/constants/expressions.dart' show
    ConstantExpression;

import 'package:compiler/src/dart2jslib.dart' show
    DartConstantCompiler;

import 'fletch_compiler.dart' show
    FletchCompiler;

export 'fletch_compiler.dart' show
    FletchCompiler;

import 'fletch_backend.dart' show
    FletchBackend;

export 'fletch_backend.dart' show
    FletchBackend;

import 'fletch_resolution_callbacks.dart' show
    FletchResolutionCallbacks;

export 'fletch_resolution_callbacks.dart' show
    FletchResolutionCallbacks;

export 'bytecode_builder.dart' show
    BytecodeBuilder,
    BytecodeLabel;

import 'fletch_native_descriptor.dart' show
    FletchNativeDescriptor;

export 'fletch_native_descriptor.dart' show
    FletchNativeDescriptor;

class FletchContext {
  final FletchCompiler compiler;

  FletchResolutionCallbacks resolutionCallbacks;

  Map<String, FletchNativeDescriptor> nativeDescriptors;

  Map<String, String> names;

  Map<FieldElement, int> staticIndices = new Map<FieldElement, int>();

  Map<String, id> symbolIds = new Map<String, id>();
  Map<Selector, String> selectorToSymbol = new Map<Selector, String>();

  FletchContext(this.compiler);

  FletchBackend get backend => compiler.backend;

  void setNames(Map<String, String> names) {
    // Generate symbols of the values.
    for (String name in names.values) {
      getSymbolId(name);
    }
    this.names = names;
  }

  int getStaticFieldIndex(FieldElement element, Element referrer) {
    return staticIndices.putIfAbsent(element, () => staticIndices.length);
  }

  String getSymbolFromSelector(Selector selector) {
    return selectorToSymbol.putIfAbsent(selector, () {
        StringBuffer buffer = new StringBuffer();
        buffer.write(selector.name);
        for (String namedArgument in selector.namedArguments) {
          buffer.write(":");
          buffer.write(namedArgument);
        }
        return buffer.toString();
      });
  }

  String getSymbolFromFunction(FunctionElement function) {
    StringBuffer buffer = new StringBuffer();
    buffer.write(function.name);
    FunctionSignature functionSignature = function.functionSignature;
    functionSignature.orderedForEachParameter((ParameterElement parameter) {
      if (parameter.isNamed) {
        buffer.write(":");
        buffer.write(parameter.name);
      }
    });
    return buffer.toString();
  }

  int getSymbolId(String symbol) {
    return symbolIds.putIfAbsent(symbol, () => symbolIds.length);
  }

  void forEachStatic(f(FieldElement element, int index)) {
    staticIndices.forEach(f);
  }

  /// If [isConst] is true, a compile-time error is reported.
  ConstantExpression compileConstant(
      Node node,
      TreeElements elements,
      {bool isConst}) {
    assert(isConst != null);
    DartConstantCompiler constantCompiler =
        backend.constantCompilerTask.constantCompiler;
    return constantCompiler.compileNodeWithDefinitions(
        node, elements, isConst: isConst);
  }
}
