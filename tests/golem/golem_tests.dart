// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// IF YOU BREAK THIS TEST YOU PROBABLY HAVE TO FIX GOLEM AS WELL!

import 'dart:async' show
    Future;

import 'dart:io' show
    Directory,
    Platform,
    Process,
    ProcessResult;

import 'package:expect/expect.dart' show
    Expect;

import 'package:fletchc/src/guess_configuration.dart' show
    executable;

Future<Null> main() async {
  print('*' * 80);
  print('If this test fails with a load error, you probably have to update');
  print(' tools/benchmarking_files');
  print('*' * 80);

  // Locate the files that are needed.
  Uri benchmarkingFiles = executable.resolve('../../tools/benchmarking_files');
  Directory tempDir = Directory.systemTemp.createTempSync('golem_tests');
  Uri tarFile = tempDir.uri.resolve('golem.tar.gz');
  String buildDir = const String.fromEnvironment('test.dart.build-dir');
  bool asanBuild = const bool.fromEnvironment('test.dart.build-asan');

  List<String> tarArguments = [
      'hczf',
      tarFile.toFilePath(),
      '-T',
      benchmarkingFiles.toFilePath(),
      '$buildDir/fletch-vm',
      '$buildDir/dart',
      '$buildDir/natives.json'];

  // Mac ASan builds need the clang asan runtime library in the bundle.
  if (Platform.isMacOS && asanBuild) {
    tarArguments.add('$buildDir/libclang_rt.asan_osx_dynamic.dylib');
  }

  try {
    // Package up the files similar to what Golem does.
    ProcessResult tarResult = Process.runSync(
        'tar',
        tarArguments,
        workingDirectory: executable.resolve('../..').toFilePath(),
        runInShell: true);
    Expect.equals(0,
                  tarResult.exitCode,
                  'tarball creation failed:\n\n'
                  'stdout:\n${tarResult.stdout}\n'
                  'stderr:\n${tarResult.stderr}');

    // Unpack the bundle in the temporary directory.
    ProcessResult untarResult = Process.runSync(
        'tar',
        ['xvzf', 'golem.tar.gz'],
        workingDirectory: tempDir.path,
        runInShell: true);
    Expect.equals(0,
                  untarResult.exitCode,
                  'tarball extraction failed:\n\n'
                  'stdout:\n${untarResult.stdout}\n'
                  'stderr:\n${untarResult.stderr}');

    // Build the snapshot in the temporary directory. Use the dart
    // binary in the archive to test that everything needed is in
    // there.
    ProcessResult snapshotResult = Process.runSync(
        '$buildDir/dart',
        ['-Dsnapshot=out.snapshot',
         'tests/fletchc/run.dart',
         'benchmarks/DeltaBlue.dart'],
        workingDirectory: tempDir.path,
        runInShell: true);
    Expect.equals(0,
                  snapshotResult.exitCode,
                  'snapshot creation failed:\n\n'
                  'stdout:\n${snapshotResult.stdout}\n'
                  'stderr:\n${snapshotResult.stderr}');

    // Run the snapshot in the temporary directory.Use the fletch-vm
    // binary in the archive to test that everything needed is in
    // there.
    ProcessResult runResult = Process.runSync(
        '$buildDir/fletch-vm',
        ['out.snapshot'],
        workingDirectory: tempDir.path,
        runInShell: true);
    Expect.equals(0,
                  runResult.exitCode,
                  'benchmark run failed:\n\n'
                  'stdout:\n${runResult.stdout}\n'
                  'stderr:\n${runResult.stderr}');
    Expect.isTrue(runResult.stdout.contains('DeltaBlue(RunTime):'));
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}