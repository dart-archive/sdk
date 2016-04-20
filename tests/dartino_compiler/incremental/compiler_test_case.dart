// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Helper class for writing compiler tests.
library dartino_compiler.test.compiler_test_case;

import 'dart:async' show
    Future;

export 'dart:async' show
    Future;

export 'package:expect/expect.dart' show
    Expect;

import 'package:compiler/src/elements/elements.dart' show
    LibraryElement;

export 'package:compiler/src/elements/elements.dart' show
    LibraryElement;

import 'package:dartino_compiler/src/guess_configuration.dart' show
    StringOrUri;

export 'package:dartino_compiler/src/guess_configuration.dart' show
    StringOrUri;

const String SCHEME = 'org.trydart.compiler-test-case';

Uri customUri(String path) => Uri.parse('$SCHEME:/$path');

abstract class CompilerTestCase {
  final Uri scriptUri;

  CompilerTestCase([@StringOrUri scriptUri])
      : this.scriptUri = makeScriptUri(scriptUri);

  static Uri makeScriptUri(@StringOrUri scriptUri) {
    if (scriptUri == null) return customUri('main.dart');
    if (scriptUri is Uri) return scriptUri;
    return customUri(scriptUri as String);
  }

  Future run();

  String toString() => 'CompilerTestCase($scriptUri)';
}
