// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.compiler_api_test;

import 'package:fletchc/compiler.dart' show
    FletchCompiler;

import 'package:expect/expect.dart' show
    Expect;

main(List<String> arguments) {
  var compiler = new FletchCompiler();
  Expect.throws(compiler.run, (e) => e is StateError);

  Expect.throws(
      () => new FletchCompiler(packageConfig: 0),
      (e) => e is ArgumentError && '$e'.contains("packageConfig"));

  Expect.throws(
      () => new FletchCompiler(libraryRoot: 0),
      (e) => e is ArgumentError && '$e'.contains("libraryRoot"));

  Expect.throws(
      () => new FletchCompiler(libraryRoot: '/dev/null'),
      (e) => e is ArgumentError && '$e'.contains("Dart SDK library not found"));

  Expect.throws(
      () => new FletchCompiler(script: 0),
      (e) => e is ArgumentError && '$e'.contains("script"));

  new FletchCompiler(script: "lib/system/system.dart").run();

  new FletchCompiler(script: Uri.parse("lib/system/system.dart")).run();

  new FletchCompiler(
      script: Uri.base.resolve("lib/system/system.dart")).run();

  new FletchCompiler().run("lib/system/system.dart");

  new FletchCompiler().run(Uri.parse("lib/system/system.dart"));

  new FletchCompiler().run(Uri.base.resolve("lib/system/system.dart"));
}
