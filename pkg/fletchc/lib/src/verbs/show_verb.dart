// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.show_verb;

import 'infrastructure.dart';

import 'documentation.dart' show
    showDocumentation;

import '../diagnostic.dart' show
    throwInternalError;

import '../driver/developer.dart' show
    discoverDevices;

const Action showAction = const Action(
    show, showDocumentation, requiresSession: true,
    requiresTarget: true,
    supportedTargets: const <TargetKind>[TargetKind.LOG, TargetKind.DEVICES]);

Future<int> show(AnalyzedSentence sentence, VerbContext context) {
  var task;
  switch (sentence.target.kind) {
    case TargetKind.LOG:
      task = new ShowLogTask();
      break;
    case TargetKind.DEVICES:
      task = new ShowDevicesTask();
      break;
    default:
      throwInternalError("Unexpected ${sentence.target}");
  }
  return context.performTaskInWorker(task);
}

class ShowLogTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  const ShowLogTask();

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) {
    return showLogTask();
  }
}

Future<int> showLogTask() async {
  print(SessionState.current.getLog());
  return 0;
}

class ShowDevicesTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  const ShowDevicesTask();

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) {
    return showDevicesTask();
  }
}

Future<int> showDevicesTask() async {
  await discoverDevices();
  return 0;
}
