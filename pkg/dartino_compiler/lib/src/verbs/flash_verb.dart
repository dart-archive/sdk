// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.flash_verb;

import 'package:path/path.dart' show
    basenameWithoutExtension;

import 'infrastructure.dart';

import '../worker/developer.dart' show
    combineTasks,
    flashImage;

import 'documentation.dart' show
    flashDocumentation;

import 'build_verb.dart' show
    BuildTask;

const Action flashAction = const Action(
    flashFunction, flashDocumentation, requiresSession: true,
    requiredTarget: TargetKind.FILE);

Future flashFunction(
    AnalyzedSentence sentence, VerbContext context) async {

  return context.performTaskInWorker(
      combineTasks(new BuildTask(sentence.targetUri, sentence.base),
                   new FlashTask(sentence.targetUri)));
}

class FlashTask extends SharedTask {
  final Uri script;

  FlashTask(this.script);

  Future call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) async {
    return flashTask(
        commandSender, commandIterator, SessionState.current, script);
  }
}

Future<int> flashTask(
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator,
    SessionState state,
    Uri script) async {
  String imageName = basenameWithoutExtension(script.path) + '.bin';
  Uri image = script.resolve(imageName);
  return flashImage(commandSender, commandIterator, state, image);
}
