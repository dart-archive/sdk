// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:compiler/compiler.dart' as compiler;

import 'package:semantic_visitor/semantic_visitor.dart' as semantic_visitor;

import 'package:sharedfrontend/elements.dart' as elements;

main() {
  print(compiler.compile);
  print(semantic_visitor.SemanticVisitor);
  print(elements.Element);
}
