// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_constant_task;

import 'package:compiler/src/compiler.dart' show Compiler;
import 'package:compiler/src/compile_time_constants.dart';
import 'package:compiler/src/constants/constant_system.dart';
import 'package:compiler/src/constants/expressions.dart';
import 'package:compiler/src/constants/values.dart';
import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/resolution/tree_elements.dart' show
    TreeElements,
    TreeElementMapping;
import 'package:compiler/src/tree/tree.dart';

/// [ConstantCompilerTask] for compilation of constants for the Dart backend.
///
/// Since this task needs no distinction between frontend and backend constants
/// it also serves as the [BackendConstantEnvironment].
class DartinoConstantTask extends ConstantCompilerTask
    implements BackendConstantEnvironment {
  final DartConstantCompiler constantCompiler;

  DartinoConstantTask(Compiler compiler)
      : this.constantCompiler = new DartConstantCompiler(compiler),
        super(compiler.measurer);

  String get name => 'ConstantHandler';

  @override
  ConstantSystem get constantSystem => constantCompiler.constantSystem;

  @override
  bool hasConstantValue(ConstantExpression expression) {
    return constantCompiler.hasConstantValue(expression);
  }

  @override
  ConstantValue getConstantValue(ConstantExpression expression) {
    return constantCompiler.getConstantValue(expression);
  }

  @override
  ConstantValue getConstantValueForVariable(VariableElement element) {
    return constantCompiler.getConstantValueForVariable(element);
  }

  @override
  ConstantExpression getConstantForNode(Node node, TreeElements elements) {
    return constantCompiler.getConstantForNode(node, elements);
  }

  @override
  ConstantValue getConstantValueForNode(Node node, TreeElements elements) {
    return getConstantValue(
        constantCompiler.getConstantForNode(node, elements));
  }

  @override
  ConstantValue getConstantValueForMetadata(MetadataAnnotation metadata) {
    return getConstantValue(metadata.constant);
  }

  @override
  ConstantExpression compileConstant(VariableElement element) {
    return measure(() {
      return constantCompiler.compileConstant(element);
    });
  }

  @override
  void evaluate(ConstantExpression constant) {
    return measure(() {
      return constantCompiler.evaluate(constant);
    });
  }

  @override
  ConstantExpression compileVariable(VariableElement element) {
    return measure(() {
      return constantCompiler.compileVariable(element);
    });
  }

  @override
  ConstantExpression compileNode(Node node, TreeElements elements,
      {bool enforceConst: true}) {
    return measure(() {
      return constantCompiler.compileNodeWithDefinitions(node, elements,
          isConst: enforceConst);
    });
  }

  @override
  ConstantExpression compileMetadata(
      MetadataAnnotation metadata, Node node, TreeElements elements) {
    return measure(() {
      return constantCompiler.compileMetadata(metadata, node, elements);
    });
  }

  // TODO(johnniwinther): Remove this when values are computed from the
  // expressions.
  @override
  void copyConstantValues(DartinoConstantTask task) {
    constantCompiler.constantValueMap
        .addAll(task.constantCompiler.constantValueMap);
  }

  @override
  void registerLazyStatic(FieldElement element) {
    // Do nothing.
  }
}
