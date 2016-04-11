// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.enable_verb;

import '../messages.dart' show
    analyticsOptInNotification;

import 'documentation.dart' show
    enableDocumentation;

import 'infrastructure.dart';

const Action enableAction = const Action(
    performEnableAction, enableDocumentation,
    requiredTarget: TargetKind.ANALYTICS);

Future<int> performEnableAction(
    AnalyzedSentence sentence, VerbContext context) async {
  var analytics = context.clientConnection.analytics;
  if (analytics.uuid == null) analytics.writeNewUuid();
  print(analyticsOptInNotification);
  return 0;
}
