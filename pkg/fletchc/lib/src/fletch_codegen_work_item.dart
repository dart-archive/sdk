// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_codegen_work_item;

import 'package:compiler/src/dart2jslib.dart' show
    CodegenEnqueuer,
    CodegenWorkItem,
    Compiler,
    ItemCompilationContext,
    WorldImpact,
    invariant;

import 'package:compiler/src/elements/elements.dart' show
    AstElement;

import 'fletch_compiler_implementation.dart' show
    FletchCompilerImplementation;

import 'fletch_registry.dart' show
    FletchRegistry;

// TODO(ahe): Implement CodegenWorkItem?
class FletchCodegenWorkItem extends CodegenWorkItem {
  factory FletchCodegenWorkItem(
      FletchCompilerImplementation compiler,
      AstElement element,
      ItemCompilationContext compilationContext) {
    // If this assertion fails, the resolution callbacks of the backend may be
    // missing call of form registry.registerXXX. Alternatively, the code
    // generation could spuriously be adding dependencies on things we know we
    // don't need.
    assert(invariant(element,
        compiler.enqueuer.resolution.hasBeenResolved(element),
        message: "$element has not been resolved."));
    assert(invariant(element, element.resolvedAst.elements != null,
        message: 'Resolution tree is null for $element in codegen work item'));
    return new FletchCodegenWorkItem.internal(element, compilationContext);
  }

  FletchCodegenWorkItem.internal(
      AstElement element,
      ItemCompilationContext compilationContext)
      : super.internal(element, compilationContext);

  WorldImpact run(Compiler compiler, CodegenEnqueuer world) {
    if (world.isProcessed(element)) return null;

    registry = new FletchRegistry(compiler, resolutionTree).asRegistry;
    return compiler.codegen(this, world);
  }

  FletchRegistry get fletchRegistry => registry as FletchRegistry;
}
