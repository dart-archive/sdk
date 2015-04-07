// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_constants;

import 'package:compiler/src/constants/expressions.dart' show
    ConstantExpression;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    FunctionElement;

import 'package:compiler/src/core_types.dart' show
    CoreTypes;

import 'package:compiler/src/dart_types.dart' show
    DartType,
    DynamicType;

class FletchFunctionConstant extends ConstantValue {
  final int methodId;

  FletchFunctionConstant(this.methodId);

  DartType getType(CoreTypes types) => const DynamicType();

  List<ConstantValue> getDependencies() => const <ConstantValue>[];

  accept(visitor, arg) {
    throw new UnsupportedError("FletchFunctionConstant.accept");
  }

  String unparse() => toStructuredString();

  String toStructuredString() {
    return 'FletchFunctionConstant($methodId)';
  }
}

class FletchClassConstant extends ConstantValue {
  final int classId;

  FletchClassConstant(this.classId);

  DartType getType(CoreTypes types) => const DynamicType();

  List<ConstantValue> getDependencies() => const <ConstantValue>[];

  accept(visitor, arg) {
    throw new UnsupportedError("FletchClassConstant.accept");
  }

  String unparse() => toStructuredString();

  String toStructuredString() {
    return 'FletchClassConstant($classId)';
  }
}

class FletchClassInstanceConstant extends ConstantValue {
  final int classId;

  FletchClassInstanceConstant(this.classId);

  DartType getType(CoreTypes types) => const DynamicType();

  List<ConstantValue> getDependencies() => const <ConstantValue>[];

  accept(visitor, arg) {
    throw new UnsupportedError("FletchClassInstanceConstant.accept");
  }

  String unparse() => toStructuredString();

  String toStructuredString() {
    return 'FletchClassInstanceConstant($classId)';
  }
}
