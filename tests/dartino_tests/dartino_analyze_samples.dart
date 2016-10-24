// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartino_compiler/src/worker/developer.dart';
import 'package:expect/expect.dart';
import 'package:path/path.dart';

bool _debug = false;

// Test entry point.

typedef Future NoArgFuture();

Future<Map<String, NoArgFuture>> listTests() async {
  var tests = <String, NoArgFuture>{};
  Stream<FileSystemEntity> samples =
      new Directory('samples').list(recursive: true);
  await for (FileSystemEntity sample in samples) {
    if (!sample.path.endsWith('.dart')) continue;
    if (sample.path.endsWith('http_json_sample_server.dart')) {
      // TODO(danrubel): analyze server sample
      if (_debug) print('Not analyzing ${sample.path}');
      continue;
    }
    if (sample.path.startsWith('samples/lk/gfx/lines')) {
      // TODO(danrubel): cleanup or remove these samples
      if (_debug) print('Not analyzing ${sample.path}');
      continue;
    }
    tests["analyze_samples/${sample.path}"] = () => analyzeSample(sample.path);
  }
  return tests;
}

/// Ensure sample analyzes cleanly
Future<Null> analyzeSample(String samplePath) async {
  Directory dartSdkDir = await locateDartSdkDirectory();
  String analyzerPath = join(dartSdkDir.path, 'bin', 'dartanalyzer');
  String pkgsPath = 'pkg/dartino-sdk.packages';
  Uri pkgsUri = Directory.current.uri.resolve(pkgsPath);

  List<String> arguments = <String>['--strong'];
  arguments.add('--packages');
  arguments.add(new File.fromUri(pkgsUri).path);
  arguments.add(samplePath);

  if (_debug) print('Analyzing ${samplePath}');
  bool success = false;
  StringBuffer out = new StringBuffer();
  listener(String line) {
    if (line == 'No issues found') success = true;
    out.writeln(line);
  }

  Process process = await Process.start(analyzerPath, arguments);

  Completer outDone = new Completer();
  process.stdout
      .transform(UTF8.decoder)
      .transform(new LineSplitter())
      .listen(listener, onDone: () => outDone.complete());
  Completer errDone = new Completer();
  process.stderr
      .transform(UTF8.decoder)
      .transform(new LineSplitter())
      .listen(listener, onDone: () => errDone.complete());

  if (await process.exitCode != 0) success = false;
  await outDone.future;
  await errDone.future;

  if (!success || _debug) print(out.toString());
  Expect.equals(true, success);
}
