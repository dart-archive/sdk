// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.servicec_verb;

import 'infrastructure.dart';

import 'package:servicec/compiler.dart' as servicec;

import 'documentation.dart' show
    servicecDocumentation;

const Verb servicecVerb = const Verb(
    // A session is required for a worker.
    servicecAct, servicecDocumentation, requiresSession: true,
    requiredTarget: TargetKind.FILE);

Future<int> servicecAct(AnalyzedSentence sentence, VerbContext context) async {
  String fileName = sentence.targetName;

  // This is asynchronous, but we don't await the result so we can respond to
  // other requests.
  context.performTaskInWorker(new CompileTask(fileName));

  return null;
}

class CompileTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final String fileName;

  const CompileTask(this.fileName);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return compileTask(fileName);
  }
}

Future<int> compileTask(String fileName) async {
  print("Compiling $fileName...");

  // TODO(stanm): take directory as argument
  String outputDirectory = "/tmp/servicec-out";

  await servicec.compile(fileName, outputDirectory);

  print("Compiled $fileName to $outputDirectory");

  return 0;
}
