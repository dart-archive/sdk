// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.incremental_backend;

import 'package:compiler/src/elements/elements.dart' show
    Element,
    FieldElement,
    FunctionElement;

import 'fletch_system.dart' show
    FletchSystem;

import 'src/fletch_system_builder.dart' show
    FletchSystemBuilder;

import 'src/fletch_context.dart' show
    FletchContext;

// TODO(ahe): Move this to dart2js upstream when it's stabilized
abstract class IncrementalBackend {

  /// Remove [element] from the compilation result. Called after resolution and
  /// codegen phase.
  ///
  /// This is different from [Backend.forgetElement] which is about preparing
  /// for a new round of resolution and codegen. `forgetElement` is called
  /// before processing the work queue, this method is called after and the old
  /// version of [element] should be removed.
  void removeFunction(FunctionElement element);

  /// Remove [element] from the compilation result. Called after resolution and
  /// codegen phase.
  ///
  /// See [removeFunction] for how this compares to `forgetElement`.
  void removeField(FieldElement element);

  /// Register that [element] is now part of the compilation. This happens
  /// during the codegen phase.
  // TODO(ahe): We should probably remove this API, I believe it is an artifact
  // of the incremental compiler not enqueuing fields.
  void newElement(Element element);

  /// Update references to [element] in [users].
  // TODO(ahe): Computing [users] is expensive, and may not be necessary in
  // dart2js. Move to IncrementalFletchBackend or add a bool to say if the call
  // is needed.
  void replaceFunctionUsageElement(Element element, List<Element> users);
}

abstract class IncrementalFletchBackend implements IncrementalBackend {
  FletchSystemBuilder get systemBuilder;

  void newSystemBuilder(FletchSystem predecessorSystem);

  /// In Fletch, assembleProgram is incremental. In dart2js it isn't.
  int assembleProgram();
}
