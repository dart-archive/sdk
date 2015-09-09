// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.test.end_to_end;

import 'dart:async';

import 'dart:io';

import 'package:fletchc/src/driver/session_manager.dart';

import 'package:fletchc/src/driver/developer.dart';

String guessFletchProgramName() {
  Uri dartVmUri =
      Uri.base.resolveUri(new Uri.file(Platform.resolvedExecutable));
  return dartVmUri.resolve('fletch').toFilePath();
}

main(List<String> arguments) async {
  SessionState state = createSessionState("test");
  String fletchProgramName = guessFletchProgramName();
  for (String script in arguments) {
    await compile(script, state);
    await attachToLocalVm(fletchProgramName, state);

    state.stdoutSink.attachCommandSender(stdout.add);
    state.stderrSink.attachCommandSender(stderr.add);

    await run(state);
  }
}

// TODO(ahe): Pass a few file names to main.
Future<Null> test() => main(<String>[]);
