// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.test.run;

import 'dart:async';

import 'dart:io';

import 'package:fletchc/src/driver/session_manager.dart';

import 'package:fletchc/src/driver/developer.dart';

import 'package:fletchc/src/verbs/infrastructure.dart' show fileUri;

Uri guessFletchProgramName() {
  Uri dartVmUri = fileUri(Platform.resolvedExecutable, Uri.base);
  return dartVmUri.resolve('fletch');
}

main(List<String> arguments) async {
  Uri packageRoot = Uri.base.resolve("package/");
  SessionState state = createSessionState("test", packageRoot);
  Uri fletchProgramName = guessFletchProgramName();
  for (String script in arguments) {
    await compile(fileUri(script, Uri.base), state);
    await attachToLocalVm(fletchProgramName, state);

    state.stdoutSink.attachCommandSender(stdout.add);
    state.stderrSink.attachCommandSender(stderr.add);

    await run(state);
  }
}

Future<Null> test() => main(<String>['tests/language/application_test.dart']);
