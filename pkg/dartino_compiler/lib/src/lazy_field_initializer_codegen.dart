// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.lazy_field_initializer_codegen;

import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/resolution/tree_elements.dart' show
    TreeElements;

import 'package:compiler/src/tree/tree.dart';

import 'dartino_context.dart';

import 'dartino_function_builder.dart' show
    DartinoFunctionBuilder;

import 'dartino_registry.dart' show
    DartinoRegistry;

import 'closure_environment.dart';

import 'codegen_visitor.dart';

class LazyFieldInitializerCodegen
    extends CodegenVisitor with DartinoRegistryMixin {
  final DartinoRegistry registry;

  LazyFieldInitializerCodegen(DartinoFunctionBuilder functionBuilder,
                              DartinoContext context,
                              TreeElements elements,
                              this.registry,
                              ClosureEnvironment closureEnvironment,
                              FieldElement field)
      : super(functionBuilder, context, elements,
              closureEnvironment, field);

  FieldElement get field => element;

  void compile() {
    Node initializer = field.initializer;
    visitForValue(initializer);
    // TODO(ajohnsen): Add cycle detection.
    assembler
        ..storeStatic(context.getStaticFieldIndex(field, null))
        ..ret()
        ..methodEnd();
  }
}
