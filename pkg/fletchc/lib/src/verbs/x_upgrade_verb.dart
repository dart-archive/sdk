// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.x_upgrade_verb;

import 'infrastructure.dart';
import '../driver/developer.dart' show upgradeAgent;
import 'documentation.dart' show upgradeDocumentation;

const Action upgradeAction = const Action(
    upgradeFunction,
    upgradeDocumentation,
    requiresSession: true,
    supportsWithUri: true,
    requiredTarget: TargetKind.AGENT);

Future upgradeFunction(AnalyzedSentence sentence, VerbContext context) async {
  Uri packageUri = sentence.withUri;
  List<String> nameParts = packageUri.pathSegments.last.split('_');
  if (nameParts.length != 3 || nameParts[0] != 'fletch-agent') {
    throwFatalError(DiagnosticKind.upgradeInvalidPackageName);
  }
  String version = nameParts[1];
  // create_debian_packages.py adds a '-1' after the hash in the package name.
  if (version.endsWith('-1')) {
    version = version.substring(0, version.length - 2);
  }
  return context.performTaskInWorker(new UpgradeTask(packageUri, version));
}

class UpgradeTask extends SharedTask {
  final Uri package;
  final String version;

  UpgradeTask(this.package, this.version);

  Future call(CommandSender commandSender,
      StreamIterator<Command> commandIterator) async {
    return await upgradeAgent(SessionState.current, package, version);
  }
}
