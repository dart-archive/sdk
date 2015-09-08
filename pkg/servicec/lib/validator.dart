// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.validator;

import 'node.dart' show
    CompilationUnitNode,
    Node,
    ServiceNode;

import 'errors.dart' show
    CompilerError;

List<CompilerError> validate(CompilationUnitNode compilationUnit) {
  List<CompilerError> errors = <CompilerError>[];

  if (!hasAtLeastOneService(compilationUnit)) {
    errors.add(CompilerError.undefinedService);
  }

  return errors;
}

bool hasAtLeastOneService(CompilationUnitNode compilationUnit) {
  for (Node node in compilationUnit.topLevelDefinitions) {
    if (node is ServiceNode) return true;
  }
  return false;
}
