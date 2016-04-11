// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.incremental_backend;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    Element,
    FieldElement,
    FunctionElement;

import 'dartino_system.dart' show
    DartinoSystem;

import 'src/dartino_system_builder.dart' show
    DartinoSystemBuilder,
    SchemaChange;

import 'src/closure_environment.dart' show
    ClosureInfo;

// TODO(ahe): Move this to dart2js upstream when it's stabilized
abstract class IncrementalBackend {

  /// Remove [element] from the compilation result.
  ///
  /// This is different from [Backend.forgetElement]. The former is to inform
  /// the backend that [element] has changed, this method informs the backend
  /// that [element] was removed.
  void removeFunction(FunctionElement element);

  //TODO(zarah): Remove this and track nested closures via DartinoSystem
  Map<FunctionElement, ClosureInfo> lookupNestedClosures(Element element);
}

abstract class IncrementalDartinoBackend implements IncrementalBackend {
  DartinoSystemBuilder get systemBuilder;

  void newSystemBuilder(DartinoSystem predecessorSystem);

  /// In Dartino, assembleProgram is incremental. In dart2js it isn't.
  int assembleProgram();

  void forEachSubclassOf(ClassElement cls, void f(ClassElement cls));
}
