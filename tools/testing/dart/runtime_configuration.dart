// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library runtime_configuration;

import 'dart:io' show
    File,
    Platform;

import 'compiler_configuration.dart' show
    CommandArtifact;

// TODO(ahe): Remove this import, we can precompute all the values required
// from TestSuite once the refactoring is complete.
import 'test_suite.dart' show
    StandardTestSuite,
    TestSuite;

import 'test_runner.dart' show
    Command,
    CommandBuilder;

import "utils.dart";

import 'dartino_warnings_suite.dart' show
    DartinoWarningsRuntimeConfiguration;

import 'dartino_test_suite.dart' show
    DartinoTestRuntimeConfiguration;

import 'dartino_session_command.dart' show
    DartinoSessionCommand;

// TODO(ahe): I expect this class will become abstract very soon.
class RuntimeConfiguration {
  // TODO(ahe): Remove this constructor and move the switch to
  // test_options.dart.  We probably want to store an instance of
  // [RuntimeConfiguration] in [configuration] there.
  factory RuntimeConfiguration(Map configuration) {
    String runtime = configuration['runtime'];
    switch (runtime) {
      case 'none':
        return new NoneRuntimeConfiguration();

      case 'dartino_compiler':
        return new DartinocRuntimeConfiguration(
            hostChecked: configuration['host_checked'],
            useSdk:configuration['use_sdk'],
            settingsFileName: configuration['settings_file_name']);

      case 'dartinovm':
        return new DartinoVMRuntimeConfiguration(configuration);

      case 'dartino_warnings':
        return new DartinoWarningsRuntimeConfiguration(configuration);

      case 'dartino_tests':
        return new DartinoTestRuntimeConfiguration(configuration);

      case 'dartino_cc_tests':
        return new CCRuntimeConfiguration();

      default:
        throw "Unknown runtime '$runtime'";
    }
  }

  RuntimeConfiguration.subclass();

  int computeTimeoutMultiplier({
      bool isDebug: false,
      bool isChecked: false,
      String arch}) {
    return 1;
  }

  List<Command> computeRuntimeCommands(
      TestSuite suite,
      CommandBuilder commandBuilder,
      CommandArtifact artifact,
      String script,
      List<String> arguments,
      Map<String, String> environmentOverrides) {
    // TODO(ahe): Make this method abstract.
    throw "Unimplemented runtime '$runtimeType'";
  }

  List<String> dart2jsPreambles(Uri preambleDir) => [];
}

/// The 'none' runtime configuration.
class NoneRuntimeConfiguration extends RuntimeConfiguration {
  NoneRuntimeConfiguration()
      : super.subclass();

  List<Command> computeRuntimeCommands(
      TestSuite suite,
      CommandBuilder commandBuilder,
      CommandArtifact artifact,
      String script,
      List<String> arguments,
      Map<String, String> environmentOverrides) {
    return <Command>[];
  }
}

/// Common runtime configuration for runtimes based on the Dart VM.
class DartVmRuntimeConfiguration extends RuntimeConfiguration {
  DartVmRuntimeConfiguration()
      : super.subclass();

  int computeTimeoutMultiplier({
      bool isDebug: false,
      bool isChecked: false,
      String arch}) {
    int multiplier = 1;
    switch (arch) {
      case 'simarm':
      case 'arm':
      case 'simmips':
      case 'mips':
      case 'simarm64':
        multiplier *= 4;
        break;
    }
    if (isDebug) {
      multiplier *= 2;
    }
    return multiplier;
  }
}

class DartinocRuntimeConfiguration extends DartVmRuntimeConfiguration {
  final bool useSdk;
  final String settingsFileName;

  DartinocRuntimeConfiguration(
    {bool hostChecked: true,
     this.useSdk: false,
     this.settingsFileName}) {
    if (!hostChecked) {
      throw "dartino only works with --host-checked option.";
    }
  }

  List<Command> computeRuntimeCommands(
      TestSuite suite,
      CommandBuilder commandBuilder,
      CommandArtifact artifact,
      String script,
      List<String> basicArguments,
      Map<String, String> environmentOverrides) {
    if (artifact.filename != null && artifact.mimeType != 'application/dart') {
      throw "Dart VM cannot run files of type '${artifact.mimeType}'.";
    }
    String executable = useSdk ? '${suite.buildDir}/dartino-sdk/bin/dartino'
                               : '${suite.buildDir}/dartino';
    Map<String, String> environment = {
      'DART_VM': suite.dartVmBinaryFileName,
    };

    return <Command>[
        new DartinoSessionCommand(
            executable, script, basicArguments, environment,
            settingsFileName: settingsFileName)];
  }
}

class DartinoVMRuntimeConfiguration extends DartVmRuntimeConfiguration {
  Map configuration;

  DartinoVMRuntimeConfiguration(this.configuration);

  List<Command> computeRuntimeCommands(
      TestSuite suite,
      CommandBuilder commandBuilder,
      CommandArtifact artifact,
      String script,
      List<String> arguments,
      Map<String, String> environmentOverrides) {
    String script = artifact.filename;
    String type = artifact.mimeType;
    if (script != null && type != 'application/dartino-snapshot') {
      throw "Dartino VM cannot run files of type '$type'.";
    }
    var argumentsUnfold =
        ["-Xunfold-program", "-Xabort-on-sigterm"]..addAll(arguments);

    if (configuration['system'] == 'lk') {
      return <Command>[
          commandBuilder.getVmCommand(
              "tools/lk/run_snapshot_lk_qemu.sh",
              arguments,
              environmentOverrides)];
    }

    var useSdk = configuration['use_sdk'];
    var dartinoVM = useSdk ? "${suite.buildDir}/dartino-sdk/bin/dartino-vm"
                          : "${suite.buildDir}/dartino-vm";
    // NOTE: We assume that `dartino-vm` behaves the same as invoking
    // the DartVM in terms of exit codes.
    return <Command>[
        commandBuilder.getVmCommand(dartinoVM, arguments, environmentOverrides),
        commandBuilder.getVmCommand(
           dartinoVM, argumentsUnfold, environmentOverrides)];
  }
}

class CCRuntimeConfiguration extends DartVmRuntimeConfiguration {
  CCRuntimeConfiguration();

  List<Command> computeRuntimeCommands(
      StandardTestSuite suite,
      CommandBuilder commandBuilder,
      CommandArtifact artifact,
      String script,
      List<String> arguments,
      Map<String, String> environmentOverrides) {
    Map options = suite.readOptionsFromFile(new Path(arguments[0]));
    List<String> ccOptions = options["dartinoCCOptions"];
    var executable = "${suite.buildDir}/${ccOptions[0]}";
    return <Command>[commandBuilder.getVmCommand(
        executable, ccOptions.sublist(1), environmentOverrides)];
  }
}


/// Temporary runtime configuration for browser runtimes that haven't been
/// migrated yet.
// TODO(ahe): Remove this class.
class DummyRuntimeConfiguration extends DartVmRuntimeConfiguration {
  List<Command> computeRuntimeCommands(
      TestSuite suite,
      CommandBuilder commandBuilder,
      CommandArtifact artifact,
      String script,
      List<String> arguments,
      Map<String, String> environmentOverrides) {
    throw "Unimplemented runtime '$runtimeType'";
  }
}
