// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_constants;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue,
    ConstantValueKind;

import 'package:compiler/src/core_types.dart' show
    CoreTypes;

import 'package:compiler/src/dart_types.dart' show
    DartType,
    DynamicType;

class DartinoFunctionConstant extends ConstantValue {
  final int functionId;

  DartinoFunctionConstant(this.functionId);

  DartType getType(CoreTypes types) => const DynamicType();

  List<ConstantValue> getDependencies() => const <ConstantValue>[];

  accept(visitor, arg) {
    throw new UnsupportedError("DartinoFunctionConstant.accept");
  }

  ConstantValueKind get kind {
    throw new UnsupportedError("DartinoFunctionConstant.kind");
  }

  String toDartText() => toStructuredText();

  String toStructuredText() {
    return 'DartinoFunctionConstant($functionId)';
  }
}

class DartinoClassConstant extends ConstantValue {
  final int classId;

  DartinoClassConstant(this.classId);

  DartType getType(CoreTypes types) => const DynamicType();

  List<ConstantValue> getDependencies() => const <ConstantValue>[];

  accept(visitor, arg) {
    throw new UnsupportedError("DartinoClassConstant.accept");
  }

  ConstantValueKind get kind {
    throw new UnsupportedError("DartinoClassConstant.kind");
  }

  String toDartText() => toStructuredText();

  String toStructuredText() {
    return 'DartinoClassConstant($classId)';
  }
}

class DartinoClassInstanceConstant extends ConstantValue {
  final int classId;

  DartinoClassInstanceConstant(this.classId);

  DartType getType(CoreTypes types) => const DynamicType();

  List<ConstantValue> getDependencies() => const <ConstantValue>[];

  accept(visitor, arg) {
    throw new UnsupportedError("DartinoClassInstanceConstant.accept");
  }

  ConstantValueKind get kind {
    throw new UnsupportedError("DartinoClassInstanceConstant.kind");
  }

  String toDartText() => toStructuredText();

  String toStructuredText() {
    return 'DartinoClassInstanceConstant($classId)';
  }

  bool operator==(other) {
    return other is DartinoClassInstanceConstant && other.classId == classId;
  }

  int get hashCode => classId;
}
