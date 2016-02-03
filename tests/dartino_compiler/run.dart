// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.test.run;

import 'dart:async';

import 'dart:io';

import 'dart:io' as io;

import 'package:dartino_compiler/src/hub/session_manager.dart';

import 'package:dartino_compiler/src/worker/developer.dart';

import 'package:dartino_compiler/src/worker/developer.dart' as developer;

import 'package:dartino_compiler/src/verbs/infrastructure.dart' show fileUri;

import 'package:dartino_compiler/src/device_type.dart' show
    DeviceType,
    parseDeviceType;

const String userVmAddress = const String.fromEnvironment("attachToVm");

const String exportTo = const String.fromEnvironment("snapshot");

const String userPackages = const String.fromEnvironment("packages");

const String userAgentAddress = const String.fromEnvironment("agent");

const String dartinoSettingsFile =
    const String.fromEnvironment("test.dartino_settings_file_name");

/// Enables printing of Compiler/VM protocol commands after each compilation.
const bool printCommands = const bool.fromEnvironment("printCommands");

/// Enables pretty printing the Dartino system (the compilation result) after
/// each compilation.
const bool printSystem = const bool.fromEnvironment("printSystem");

class DartinoRunner {
  Future<Null> attach(SessionState state) async {
    if (userVmAddress == null) {
      await startAndAttachDirectly(state, Uri.base);
    } else {
      Address address = parseAddress(userVmAddress);
      await attachToVm(address.host, address.port, state);
    }
  }

  Future<Settings> computeSettings() async {
    if (dartinoSettingsFile != null) {
      return await readSettings(fileUri(dartinoSettingsFile, Uri.base));
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
        DeviceType.mobile,
        IncrementalMode.production);
  }

  Future<int> run(List<String> arguments, {int expectedExitCode: 0}) async {
    Settings settings = await computeSettings();
    SessionState state = createSessionState("test", settings);
    for (String script in arguments) {
      print("Compiling $script");
      await compile(fileUri(script, Uri.base), state, Uri.base);
      if (state.compilationResults.isNotEmpty) {
        // Always generate the debug string to ensure test coverage.
        String debugString =
            state.compilationResults.last.system.toDebugString(Uri.base);
        if (printSystem) {
          // But only print the debug string if requested.
          print(debugString);
        }
        if (printCommands) {
          print("Compiled $script");
          for (var delta in state.compilationResults) {
            print("\nDelta:");
            for (var cmd in delta.commands) {
              print(cmd);
            }
          }
        }
      }
      await attach(state);
      state.stdoutSink.attachCommandSender(stdout.add);
      state.stderrSink.attachCommandSender(stderr.add);

      if (exportTo != null) {
        await developer.export(state, fileUri(exportTo, Uri.base));
      } else {
        await developer.run(state);
      }
      if (state.dartinoVm != null) {
        int exitCode = await state.dartinoVm.exitCode;
        print("$script: Dartino VM exit code: $exitCode");
        if (exitCode != expectedExitCode) {
          return exitCode;
        }
      }
    }
    print(state.getLog());
    return 0;
  }
}

main(List<String> arguments) async {
  io.exitCode = await new DartinoRunner().run(arguments);
}

void checkExitCode(int expected, int actual) {
  if (expected != actual) {
    throw "Unexpected exit code: $expected != $actual";
  }
}

Future<Null> test() async {
  checkExitCode(
      0, await new DartinoRunner().run(
          <String>['tests/language/application_test.dart']));
}

Future<Null> testIncrementalDebugInfo() async {
  checkExitCode(
      0, await new DartinoRunner().run(
          <String>['tests/dartino_compiler/test_incremental_debug_info.dart',
                   'tests/dartino_compiler/test_incremental_debug_info.dart'],
          expectedExitCode: 255));
}

// TODO(ahe): Move this method into DartinoRunner and use computeSettings.
Future<Null> export(
    String script, String snapshot, {bool binaryProgramInfo: false,
        Map<String, String> constants: const <String, String> {}}) async {
  Settings settings;
  if (dartinoSettingsFile == null) {
    settings = new Settings(
        fileUri(".packages", Uri.base),
        <String>[],
        constants,
        null,
        null,
        IncrementalMode.none);
  } else {
    settings = await readSettings(fileUri(dartinoSettingsFile, Uri.base));
  }
  SessionState state = createSessionState("test", settings);
  await compile(fileUri(script, Uri.base), state, Uri.base);
  await startAndAttachDirectly(state, Uri.base);
  state.stdoutSink.attachCommandSender(stdout.add);
  state.stderrSink.attachCommandSender(stderr.add);
  await developer.export(
      state, fileUri(snapshot, Uri.base), binaryProgramInfo: binaryProgramInfo);
}
