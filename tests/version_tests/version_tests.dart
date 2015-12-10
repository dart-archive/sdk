// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:io';

import 'package:expect/expect.dart';

Future<Null> main() async {
  String buildDir = const String.fromEnvironment('test.dart.build-dir');
  bool asanBuild = const bool.fromEnvironment('test.dart.build-asan');

  ProcessResult result;

  // Get the current version.
  result = await Process.run(
      'python', ['$buildDir/../../tools/current_version.py'], runInShell: true);
  Expect.equals(0, result.exitCode);
  String version = result.stdout;

  // Check the version of the fletch CLI.
  result = await Process.run('$buildDir/fletch', ['--version']);
  Expect.equals(0, result.exitCode);
  Expect.equals(version, result.stdout);

  // Check the version of the fletch-vm
  result = await Process.run('$buildDir/fletch-vm', ['--version']);
  Expect.equals(0, result.exitCode);
  Expect.equals(version, result.stdout);
}
