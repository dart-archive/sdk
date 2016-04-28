// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.disable_verb;

import '../messages.dart' show
    analyticsOptOutNotification;

import 'documentation.dart' show
    disableDocumentation;

import 'infrastructure.dart';

const Action disableAction = const Action(
    performDisableAction, disableDocumentation,
    requiredTarget: TargetKind.ANALYTICS);

Future<int> performDisableAction(
    AnalyzedSentence sentence, VerbContext context) async {
  var analytics = context.clientConnection.analytics;
  if (analytics.uuid == null) analytics.writeOptOut();
  print(analyticsOptOutNotification);
  return 0;
}
