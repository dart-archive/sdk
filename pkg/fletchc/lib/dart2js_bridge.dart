// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.dart2js_bridge;

import 'compiler.dart' show
    FletchCompiler;

main(List<String> arguments) {
  Uri script = Uri.base.resolve(arguments.single);
  Uri packageRoot = script.resolve('packages/');
  FletchCompiler compiler = new FletchCompiler(
      packageRoot: packageRoot,
      options: ['--verbose']);
  compiler.run(script);
}
