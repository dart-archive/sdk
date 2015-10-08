// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.test.run;

import 'dart:async';

import 'dart:io';

import 'package:fletchc/src/driver/session_manager.dart';

import 'package:fletchc/src/driver/developer.dart';

import 'package:fletchc/src/driver/developer.dart' as developer;

import 'package:fletchc/src/verbs/infrastructure.dart' show fileUri;

import 'package:fletchc/src/device_type.dart' show DeviceType, parseDeviceType;

const String userVmAddress = const String.fromEnvironment("attachToVm");

const String exportTo = const String.fromEnvironment("snapshot");

const String userPackages = const String.fromEnvironment("packages");

const String userAgentAddress = const String.fromEnvironment("agent");

const String fletchSettingsFile =
    const String.fromEnvironment("test.fletch_settings_file_name");

class FletchRunner {
  Future<Null> attach(SessionState state) async {
    if (userVmAddress == null) {
      await startAndAttachDirectly(state);
    } else {
      Address address = parseAddress(userVmAddress);
      await attachToVm(address.host, address.port, state);
    }
  }

  Future<Settings> computeSettings() async {
    if (fletchSettingsFile != null) {
      return await readSettings(fileUri(fletchSettingsFile, Uri.base));
    }
    Address agentAddress =
        userAgentAddress == null ? null : parseAddress(userAgentAddress);
    return new Settings(
        fileUri(userPackages == null ? ".packages" : userPackages, Uri.base),
        ["--verbose"],
        <String, String>{
          "foo": "1",
          "bar": "baz",
        },
        agentAddress,
        DeviceType.mobile);
  }

  Future<int> run(List<String> arguments) async {
    Settings settings = await computeSettings();
    SessionState state = createSessionState("test", settings);
    int exitCode = -1;
    for (String script in arguments) {
      await compile(fileUri(script, Uri.base), state);
      await attach(state);
      state.stdoutSink.attachCommandSender(stdout.add);
      state.stderrSink.attachCommandSender(stderr.add);

      if (exportTo != null) {
        exitCode = await developer.export(state, fileUri(exportTo, Uri.base));
      } else {
        exitCode = await developer.run(state);
      }
    }
    print(state.getLog());
    return exitCode;
  }
}

main(List<String> arguments) async {
  await new FletchRunner().run(arguments);
}

Future<Null> test() => main(<String>['tests/language/application_test.dart']);

// TODO(ahe): Move this method into FletchRunner and use computeSettings.
Future<Null> export(String script, String snapshot) async {
  Settings settings;
  if (fletchSettingsFile == null) {
    settings = new Settings(
        fileUri(".packages", Uri.base),
        <String>[],
        <String, String>{},
        null,
        null);
  } else {
    settings = await readSettings(fileUri(fletchSettingsFile, Uri.base));
  }
  SessionState state = createSessionState("test", settings);
  await compile(fileUri(script, Uri.base), state);
  await startAndAttachDirectly(state);
  state.stdoutSink.attachCommandSender(stdout.add);
  state.stderrSink.attachCommandSender(stderr.add);
  await developer.export(state, fileUri(snapshot, Uri.base));
}
