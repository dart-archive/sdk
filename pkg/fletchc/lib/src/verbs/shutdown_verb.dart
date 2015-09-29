// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.shutdown_verb;

import 'dart:io' show
    Platform,
    pid;

import 'infrastructure.dart';

import '../driver/driver_main.dart' show
    gracefulShutdown,
    mainArguments;

import 'documentation.dart' show
    shutdownDocumentation;

const Action shutdownAction = const Action(shutdown, shutdownDocumentation);

Future<int> shutdown(AnalyzedSentence sentence, _) {
  List<String> commandLine = <String>[];
  String dartVmPath =
      Uri.base.resolveUri(new Uri.file(Platform.resolvedExecutable))
      .toFilePath();
  commandLine
      ..add(dartVmPath)
      ..addAll(Platform.executableArguments)
      ..add('${Platform.script}')
      ..addAll(mainArguments);
  print("Shutting down Fletch background process $pid: "
        "${commandLine.join(" ")}");
  gracefulShutdown();
  return new Future.value(0);
}
