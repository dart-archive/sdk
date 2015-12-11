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
  discoverDevices,
  showSessions,
  showSessionSettings;

const Action showAction = const Action(
    show, showDocumentation, requiresSession: true,
    requiresTarget: true,
    supportedTargets: const <TargetKind>[
        TargetKind.DEVICES,
        TargetKind.LOG,
        TargetKind.SESSIONS,
        TargetKind.SETTINGS,
    ]);

Future<int> show(AnalyzedSentence sentence, VerbContext context) {
  switch (sentence.target.kind) {
    case TargetKind.LOG:
      return context.performTaskInWorker(const ShowLogTask());
    case TargetKind.DEVICES:
      return context.performTaskInWorker(const ShowDevicesTask());
    case TargetKind.SESSIONS:
      showSessions();
      return new Future.value(0);
    case TargetKind.SETTINGS:
      return context.performTaskInWorker(const ShowSettingsTask());
    default:
      throwInternalError("Unexpected ${sentence.target}");
  }
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

class ShowSettingsTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  const ShowSettingsTask();

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) async {
    return await showSessionSettings();
  }
}
