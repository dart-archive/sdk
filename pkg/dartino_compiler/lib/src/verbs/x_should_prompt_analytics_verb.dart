// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.x_should_prompt_analytics_verb;

import '../hub/analytics.dart' show Analytics;
import 'documentation.dart' show shouldPromptAnalyticsDocumentation;
import 'infrastructure.dart';

/// The [shouldPromptAnalyticsAction] is used by IDEs to determine whether
/// the IDE should ask the user to opt into analytics.
const Action shouldPromptAnalyticsAction = const Action(
    shouldPromptAnalyticsFunction, shouldPromptAnalyticsDocumentation);

Future shouldPromptAnalyticsFunction(
    AnalyzedSentence sentence, VerbContext context) async {
  // Must be performed in main isolate... not worker.
  Analytics analytics = context.clientConnection.analytics;
  String response = analytics.shouldPromptForOptIn ? 'true' : 'false';
  context.clientConnection.printLineOnStdout(response);
  return 0;
}
