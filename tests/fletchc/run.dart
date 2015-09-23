// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.test.run;

import 'dart:async';

import 'dart:io';

import 'package:fletchc/src/driver/session_manager.dart';

import 'package:fletchc/src/driver/developer.dart';

import 'package:fletchc/src/verbs/infrastructure.dart' show fileUri;

const String userVmAddress = const String.fromEnvironment("attachToVm");

Uri guessFletchProgramName() {
  Uri dartVmUri = fileUri(Platform.resolvedExecutable, Uri.base);
  return dartVmUri.resolve('fletch');
}

Future<Null> attach(SessionState state) async {
  if (userVmAddress == null) {
    Uri fletchProgramName = guessFletchProgramName();
    await attachToLocalVm(fletchProgramName, state);
  } else {
    Address address = parseAddress(userVmAddress);
    await attachToVm(address.host, address.port, state);
  }
}

main(List<String> arguments) async {
  Settings settings = new Settings(
      fileUri(".packages", Uri.base),
      ["-verbose"],
      <String, String>{
        "foo": "1",
        "bar": "baz",
      });
  SessionState state = createSessionState("test", settings);
  for (String script in arguments) {
    await compile(fileUri(script, Uri.base), state);
    await attach(state);
    state.stdoutSink.attachCommandSender(stdout.add);
    state.stderrSink.attachCommandSender(stderr.add);

    await run(state);
  }
}

Future<Null> test() => main(<String>['tests/language/application_test.dart']);
