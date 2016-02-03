// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.compiler_api_test;

import 'package:dartino_compiler/compiler.dart' show
    DartinoCompiler;

import 'package:expect/expect.dart' show
    Expect;

main(List<String> arguments) {
  var compiler = new DartinoCompiler();
  Expect.throws(compiler.run, (e) => e is StateError);

  Expect.throws(
      () => new DartinoCompiler(packageConfig: 0),
      (e) => e is ArgumentError && '$e'.contains("packageConfig"));

  Expect.throws(
      () => new DartinoCompiler(libraryRoot: 0),
      (e) => e is ArgumentError && '$e'.contains("libraryRoot"));

  Expect.throws(
      () => new DartinoCompiler(libraryRoot: '/dev/null'),
      (e) => e is ArgumentError && '$e'.contains("Dart SDK library not found"));

  Expect.throws(
      () => new DartinoCompiler(script: 0),
      (e) => e is ArgumentError && '$e'.contains("script"));

  new DartinoCompiler(script: "lib/system/system.dart").run();

  new DartinoCompiler(script: Uri.parse("lib/system/system.dart")).run();

  new DartinoCompiler(
      script: Uri.base.resolve("lib/system/system.dart")).run();

  new DartinoCompiler().run("lib/system/system.dart");

  new DartinoCompiler().run(Uri.parse("lib/system/system.dart"));

  new DartinoCompiler().run(Uri.base.resolve("lib/system/system.dart"));
}
