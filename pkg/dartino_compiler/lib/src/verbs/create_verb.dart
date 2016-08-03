// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.create_verb;

import 'dart:io';

import '../worker/developer.dart' show
    allocateWorker,
    createProject,
    createSessionState,
    createSettings,
    findProjectTemplate,
    readDeviceIds,
    Settings;

import 'documentation.dart' show
    createDocumentation;

import 'infrastructure.dart';
import 'package:dartino_compiler/src/worker/developer.dart';

const Action createProjectAction = const Action(
    performCreateProject, createDocumentation,
    requiresForName: true, requiredTarget: TargetKind.PROJECT);

const Action createSessionAction = const Action(
    performCreateSession, createDocumentation,
    requiredTarget: TargetKind.SESSION, supportsWithUri: true);

const Map<String, Action> createActions = const {
  'project' : createProjectAction,
  'session' : createSessionAction
};

const ActionGroup createAction = const ActionGroup(
    createActions, createDocumentation);

Future<int> performCreateProject(
    AnalyzedSentence sentence, VerbContext context) async {
  // Determine the new project location
  String projectPath = sentence.targetName;
  if (projectPath == null) {
    throwFatalError(DiagnosticKind.missingProjectPath);
  }
  Uri projectUri = sentence.base.resolve(projectPath);
  var type = await FileSystemEntity.typeSync(projectUri.toFilePath());
  if (type != FileSystemEntityType.NOT_FOUND) {
    throwFatalError(DiagnosticKind.projectAlreadyExists, uri: projectUri);
  }

  Future<List<String>> findBoardNames() async {
    return (await readDeviceIds(includeRaspberryPi: true))..sort();
  }

  // Validate the specified board name
  String boardName = sentence.forName;
  if (boardName == null) {
    // If no board specified, then attempt to auto-detect
    List<Device> connectedDevices = await discoverUsbDevices();
    if (connectedDevices?.length == 1) {
      boardName = connectedDevices[0].id;
    } else {
      throwFatalError(DiagnosticKind.missingForName,
        boardNames: await findBoardNames());
    }
  }
  Uri templateUri = await findProjectTemplate(boardName);
  if (templateUri == null) {
      throwFatalError(DiagnosticKind.boardNotFound,
        userInput: boardName, boardNames: await findBoardNames());
  }

  return createProject(projectUri, boardName);
}

Future<int> performCreateSession(
    AnalyzedSentence sentence, VerbContext context) async {
  IsolatePool pool = context.pool;
  String name = sentence.targetName;

  UserSession session = await createSession(name, () => allocateWorker(pool));

  context = context.copyWithSession(session);

  return await context.performTaskInWorker(
      new CreateSessionTask(name, sentence.withUri, sentence.base));
}

class CreateSessionTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final String name;

  final Uri settingsUri;

  final Uri base;

  const CreateSessionTask(this.name, this.settingsUri, this.base);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) {
    return createSessionTask(
        commandSender, commandIterator, name, settingsUri, base);
  }
}

Future<int> createSessionTask(
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator,
    String name,
    Uri settingsUri,
    Uri base) async {
  assert(SessionState.internalCurrent == null);
  Settings settings = await createSettings(
      name, settingsUri, base, commandSender, commandIterator);
  SessionState state = createSessionState(name, base, settings);
  SessionState.internalCurrent = state;
  if (settingsUri != null) {
    state.log("Created session with $settingsUri $settings");
  } else {
    state.log("Created session with settings $settings");
  }
  return 0;
}
