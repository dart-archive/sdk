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

const String exportTo = const String.fromEnvironment("snapshot");

const String userPackages = const String.fromEnvironment("packages");

const String userAgentAddress = const String.fromEnvironment("agent");

Future<Null> attach(SessionState state) async {
  if (userVmAddress == null) {
    await startAndAttachDirectly(state);
  } else {
    Address address = parseAddress(userVmAddress);
    await attachToVm(address.host, address.port, state);
  }
}

main(List<String> arguments) async {
  Address agentAddress =
      userAgentAddress == null ? null : parseAddress(userAgentAddress);
  Settings settings = new Settings(
      fileUri(userPackages == null ? ".packages" : userPackages, Uri.base),
      ["--verbose"],
      <String, String>{
        "foo": "1",
        "bar": "baz",
      },
      agentAddress);
  SessionState state = createSessionState("test", settings);
  for (String script in arguments) {
    await compile(fileUri(script, Uri.base), state);
    await attach(state);
    state.stdoutSink.attachCommandSender(stdout.add);
    state.stderrSink.attachCommandSender(stderr.add);

    if (exportTo != null) {
      await export(state, fileUri(exportTo, Uri.base));
    } else {
      await run(state);
    }
  }
}

Future<Null> test() => main(<String>['tests/language/application_test.dart']);
