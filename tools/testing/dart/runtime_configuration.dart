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

import 'fletch_warnings_suite.dart' show
    FletchWarningsRuntimeConfiguration;

import 'fletch_test_suite.dart' show
    FletchTestRuntimeConfiguration;

import 'fletch_session_command.dart' show
    FletchSessionCommand;

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

      case 'fletchc':
        return new FletchcRuntimeConfiguration(
            hostChecked: configuration['host_checked'],
            isIncrementalCompilationEnabled:
                configuration['enable_incremental_compilation'],
            useSdk:configuration['use_sdk']);

      case 'fletchvm':
        return new FletchVMRuntimeConfiguration(configuration);

      case 'fletch_warnings':
        return new FletchWarningsRuntimeConfiguration(configuration);

      case 'fletch_tests':
        return new FletchTestRuntimeConfiguration(configuration);

      case 'fletch_cc_tests':
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

class FletchcRuntimeConfiguration extends DartVmRuntimeConfiguration {
  final bool isIncrementalCompilationEnabled;
  final bool useSdk;

  FletchcRuntimeConfiguration(
    {bool hostChecked: true,
     this.isIncrementalCompilationEnabled: true,
     this.useSdk: false}) {
    if (!hostChecked) {
      throw "fletch only works with --host-checked option.";
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
    String executable = useSdk ? '${suite.buildDir}/fletch-sdk/bin/fletch'
                               : '${suite.buildDir}/fletch';
    Map<String, String> environment = {
      'DART_VM': suite.dartVmBinaryFileName,
    };

    return <Command>[
        new FletchSessionCommand(
            executable, script, basicArguments, environment,
            isIncrementalCompilationEnabled)];
  }
}

class FletchVMRuntimeConfiguration extends DartVmRuntimeConfiguration {
  Map configuration;

  FletchVMRuntimeConfiguration(this.configuration);

  List<Command> computeRuntimeCommands(
      TestSuite suite,
      CommandBuilder commandBuilder,
      CommandArtifact artifact,
      String script,
      List<String> arguments,
      Map<String, String> environmentOverrides) {
    String script = artifact.filename;
    String type = artifact.mimeType;
    if (script != null && type != 'application/fletch-snapshot') {
      throw "Fletch VM cannot run files of type '$type'.";
    }
    var argumentsUnfold = ["-Xunfold-program"]..addAll(arguments);

    if (configuration['system'] == 'lk') {
      return <Command>[
          commandBuilder.getVmCommand(
              "tools/lk/run_snapshot_lk_qemu.sh",
              arguments,
              environmentOverrides)];
    }

    var useSdk = configuration['use_sdk'];
    var fletchVM = useSdk ? "${suite.buildDir}/fletch-sdk/bin/fletch-vm"
                          : "${suite.buildDir}/fletch-vm";
    // NOTE: We assume that `fletch-vm` behaves the same as invoking
    // the DartVM in terms of exit codes.
    return <Command>[
        commandBuilder.getVmCommand(fletchVM, arguments, environmentOverrides),
        commandBuilder.getVmCommand(
           fletchVM, argumentsUnfold, environmentOverrides)];
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
    List<String> ccOptions = options["fletchCCOptions"];
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
