// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.servicec_verb;

import 'infrastructure.dart';

import '../driver/exit_codes.dart' show
    DART_VM_EXITCODE_COMPILE_TIME_ERROR;

import 'package:servicec/compiler.dart' as servicec;

import 'package:servicec/errors.dart' show
    CompilationError,
    ErrorReporter;

import 'documentation.dart' show
    servicecDocumentation;

import "package:compiler/src/util/uri_extras.dart" show
   relativize;

const Action servicecAction = const Action(
    // A session is required for a worker.
    servicecAct, servicecDocumentation, requiresSession: true,
    requiredTarget: TargetKind.FILE);

Future<int> servicecAct(AnalyzedSentence sentence, VerbContext context) async {
  // This is asynchronous, but we don't await the result so we can respond to
  // other requests.
  context.performTaskInWorker(
      new CompileTask(sentence.targetUri, sentence.base));

  return null;
}

class CompileTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final Uri base;
  final Uri targetUri;

  const CompileTask(this.targetUri, this.base);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return compileTask(this.targetUri, this.base);
  }
}

Future<int> compileTask(Uri targetUri, Uri base) async {
  String relativeName = relativize(base, targetUri, false);
  print("Compiling $relativeName...");

  // TODO(stanm): take directory as argument
  String outputDirectory = "/tmp/servicec-out";

  String fileName = targetUri.toFilePath();
  Iterable<CompilationError> compilerErrors =
    await servicec.compile(fileName, outputDirectory);

  print("Compiled $relativeName to $outputDirectory");

  int length = compilerErrors.length;
  if (length > 0) {
    new ErrorReporter(fileName, relativeName).report(compilerErrors);
    return DART_VM_EXITCODE_COMPILE_TIME_ERROR;
  }

  return 0;
}
