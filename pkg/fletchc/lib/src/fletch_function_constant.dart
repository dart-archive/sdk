// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_function_constant;

import 'package:compiler/src/constants/expressions.dart' show
    ConstantExpression;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue;

import 'package:compiler/src/elements/elements.dart' show
    FunctionElement;

import 'package:compiler/src/core_types.dart' show
    CoreTypes;

import 'package:compiler/src/dart_types.dart' show
    DartType,
    DynamicType;

class FletchFunctionConstant extends ConstantValue {
  final FunctionElement element;

  FletchFunctionConstant(this.element);

  DartType getType(CoreTypes types) => const DynamicType();

  List<ConstantValue> getDependencies() => const <ConstantValue>[];

  accept(visitor, arg) {
    throw new UnsupportedError("FletchFunctionConstant.accept");
  }

  String unparse() => toStructuredString();

  String toStructuredString() {
    // TODO(ahe): Compute nicer names for enclosing, and handle other kinds of
    // methods than top-levels.
    String enclosing = element.library.getLibraryOrScriptName();
    return 'FletchFunctionConstant($enclosing:${element.name})';
  }
}
