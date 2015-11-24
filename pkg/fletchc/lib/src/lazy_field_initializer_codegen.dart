// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.lazy_field_initializer_codegen;

import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/resolution/tree_elements.dart' show
    TreeElements;

import 'package:compiler/src/tree/tree.dart';

import 'fletch_context.dart';

import 'fletch_function_builder.dart' show
    FletchFunctionBuilder;

import 'fletch_registry.dart' show
    FletchRegistry;

import 'closure_environment.dart';

import 'codegen_visitor.dart';

class LazyFieldInitializerCodegen
    extends CodegenVisitor with FletchRegistryMixin {
  final FletchRegistry registry;

  LazyFieldInitializerCodegen(FletchFunctionBuilder functionBuilder,
                              FletchContext context,
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
