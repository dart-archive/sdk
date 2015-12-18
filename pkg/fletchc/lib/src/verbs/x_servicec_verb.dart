// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.servicec_verb;

import 'dart:io' show
    File,
    Directory,
    Platform;

import 'package:path/path.dart' show join, dirname;

import 'infrastructure.dart';

import '../hub/exit_codes.dart' show
    DART_VM_EXITCODE_COMPILE_TIME_ERROR;

import 'package:servicec/compiler.dart' as servicec;

import 'package:servicec/errors.dart' show
    CompilationError,
    ErrorReporter;

import 'documentation.dart' show
    servicecDocumentation;

import "package:compiler/src/util/uri_extras.dart" show
    relativize;

import "package:fletchc/src/guess_configuration.dart" show
    executable;

const Action servicecAction = const Action(
    // A session is required for a worker.
    servicecAct,
    servicecDocumentation,
    requiresSession: true,
    requiredTarget: TargetKind.FILE,
    allowsTrailing: true);

Future<int> servicecAct(AnalyzedSentence sentence, VerbContext context) {
  return context.performTaskInWorker(
      new CompileTask(sentence.targetUri, sentence.base, sentence.trailing));
}

class CompileTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final Uri base;
  final Uri targetUri;
  final List<String> trailing;

  const CompileTask(this.targetUri, this.base, this.trailing);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) {
    return compileTask(targetUri, base, trailing);
  }
}

// TODO(stanm): test after issue #244 is resolved
const String _SERVICEC_DIR = const String.fromEnvironment("servicec-dir");

bool _looksLikeServicecDir(Uri uri) {
  if (!new Directory.fromUri(uri).existsSync()) return false;
  String expectedDirectory = join(uri.path, 'lib', 'src', 'resources');
  return new Directory(expectedDirectory).existsSync();
}

Uri guessServicecDir(Uri base) {
  Uri servicecDirectory;
  if (_SERVICEC_DIR != null) {
    // Use Uri.base here because _SERVICEC_DIR is a constant relative to the
    // location of where fletch was called from, not relative to the C++
    // client.
    servicecDirectory = base.resolve(_SERVICEC_DIR);
  } else {
    Uri uri = executable.resolve(join('..', '..', 'tools', 'servicec'));
    if (new Directory.fromUri(uri).existsSync()) {
      servicecDirectory = uri;
    }
  }
  if (servicecDirectory == null) {
    throw new StateError("""
Unable to guess the location of the service compiler (servicec).
Try adding command-line option '-Dservicec-dir=<path to service compiler>.""");
  } else if (!_looksLikeServicecDir(servicecDirectory)) {
    throw new StateError("""
No resources directory in '$servicecDirectory'.
Try adding command-line option '-Dservicec-dir=<path to service compiler>.""");
  }
  return servicecDirectory;
}

Future<int> compileTask(Uri targetUri, Uri base, List<String> arguments) async {
  Uri servicecUri = guessServicecDir(base);
  String resourcesDirectory = join(servicecUri.path, 'lib', 'src', 'resources');
  String outputDirectory;
  if (null != arguments && arguments.length == 2 && arguments[0] == "out") {
    outputDirectory = base.resolve(arguments[1]).toFilePath();
  } else {
    print("Bad arguments: $arguments; expected 'out <out-dir>'.");
    return DART_VM_EXITCODE_COMPILE_TIME_ERROR;
  }

  String relativeName = relativize(base, targetUri, false);
  print("Compiling $relativeName...");

  String fileName = targetUri.toFilePath();
  bool success = await servicec.compileAndReportErrors(
      fileName, relativeName, resourcesDirectory, outputDirectory);

  print("Compiled $relativeName to $outputDirectory");

  return success ? 0 : DART_VM_EXITCODE_COMPILE_TIME_ERROR;
}
