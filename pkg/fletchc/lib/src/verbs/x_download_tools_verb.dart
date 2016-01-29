// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.x_download_tools_verb;

import 'infrastructure.dart';
import '../worker/developer.dart' show downloadTools;
import 'documentation.dart' show downloadToolsDocumentation;

const Action downloadToolsAction = const Action(
    downloadToolsFunction, downloadToolsDocumentation,
    requiresSession: true);

Future downloadToolsFunction(
    AnalyzedSentence sentence, VerbContext context) async {
  return context.performTaskInWorker(new DownloadTooksTask());
}

class DownloadTooksTask extends SharedTask {

  DownloadTooksTask();

  Future call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) async {
    return await downloadTools(
        commandSender, commandIterator, SessionState.current);
  }
}
