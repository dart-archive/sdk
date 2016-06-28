// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.emulate_verb;

import 'package:path/path.dart' show
    basenameWithoutExtension;

import 'infrastructure.dart';

import '../worker/developer.dart' show
    combineTasks,
    emulateImage;

import 'documentation.dart' show
    emulateDocumentation;

import 'build_verb.dart' show
    BuildTask;

const Action emulateAction = const Action(
    emulateFunction, emulateDocumentation, requiresSession: true,
    requiredTarget: TargetKind.FILE);

Future emulateFunction(
    AnalyzedSentence sentence, VerbContext context) async {

  return context.performTaskInWorker(combineTasks(
      new BuildTask(
          sentence.targetUri,
          sentence.base,
          sentence.options.debuggingMode,
          sentence.options.noWait),
      new EmulateTask(sentence.targetUri)));
}

class EmulateTask extends SharedTask {
  final Uri script;

  EmulateTask(this.script);

  Future call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) async {
    return emulateTask(
        commandSender, commandIterator, SessionState.current, script);
  }
}

Future<int> emulateTask(
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator,
    SessionState state,
    Uri script) async {
  String imageName = basenameWithoutExtension(script.path) + '.elf';
  Uri image = script.resolve(imageName);
  return emulateImage(commandSender, commandIterator, state, image);
}
