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
    TestSuite;

import 'test_runner.dart' show
    Command,
    CommandBuilder;

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
            persist: configuration['persist'],
            hostChecked: configuration['host_checked']);

      case 'fletchd':
        return new FletchdRuntimeConfiguration();

      case 'fletchvm':
        return new FletchVMRuntimeConfiguration();

      default:
        throw "Unknown runtime '$runtime'";
    }
  }

  RuntimeConfiguration._subclass();

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
      : super._subclass();

  List<Command> computeRuntimeCommands(
      TestSuite suite,
      CommandBuilder commandBuilder,
      CommandArtifact artifact,
      List<String> arguments,
      Map<String, String> environmentOverrides) {
    return <Command>[];
  }
}

/// Common runtime configuration for runtimes based on the Dart VM.
class DartVmRuntimeConfiguration extends RuntimeConfiguration {
  DartVmRuntimeConfiguration()
      : super._subclass();

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
  final bool persist;
  final bool hostChecked;

  FletchcRuntimeConfiguration({this.persist: true, this.hostChecked: true}) {
    if (persist && !hostChecked) {
      throw "fletch_driver only works with --host-checked option.";
    }
  }

  List<Command> computeRuntimeCommands(
      TestSuite suite,
      CommandBuilder commandBuilder,
      CommandArtifact artifact,
      List<String> basicArguments,
      Map<String, String> environmentOverrides) {
    String script = artifact.filename;
    String type = artifact.mimeType;
    if (script != null && type != 'application/dart') {
      throw "Dart VM cannot run files of type '$type'.";
    }
    String executable;
    List<String> arguments;
    Map<String, String> environment;
    if (!persist) {
      List<String> vmArguments =
          <String>["-p", "package", "package:fletchc/fletchc.dart"];
      if (hostChecked) {
        vmArguments.insert(0, "-c");
      }
      vmArguments.addAll(basicArguments);

      executable = suite.dartVmBinaryFileName;
      arguments = vmArguments;
      environment = environmentOverrides;
    } else {
      executable = '${suite.buildDir}/fletch_driver';
      arguments = basicArguments;
      environment = {
        'DART_VM': suite.dartVmBinaryFileName,
      };
    }
    // NOTE: We assume that `fletch_driver` behaves the same as invoking
    // the DartVM in terms of exit codes.
    return <Command>[
        commandBuilder.getVmCommand(executable, arguments, environment)];
  }
}

class FletchdRuntimeConfiguration extends DartVmRuntimeConfiguration {
  List<Command> computeRuntimeCommands(
      TestSuite suite,
      CommandBuilder commandBuilder,
      CommandArtifact artifact,
      List<String> basicArguments,
      Map<String, String> environmentOverrides) {
    String script = artifact.filename;
    String type = artifact.mimeType;
    if (script != null && type != 'application/dart') {
      throw "Dart VM cannot run files of type '$type'.";
    }
    String executable;
    List<String> arguments;
    Map<String, String> environment;
    // TODO(ager): We should be able to run debugger tests through the
    // persistent fletch_driver as well.
    List<String> vmArguments =
        <String>["-p", "package", "package:fletchc/fletchc.dart",
                 "-d", "--test-debugger"];
    vmArguments.addAll(basicArguments);

    String testFile = basicArguments[0];
    String expectationFile =
        testFile.replaceAll("_test.dart", "_expected.txt");
    List<int> expectedOutput = new File(expectationFile).readAsBytesSync();

    executable = suite.dartVmBinaryFileName;
    arguments = vmArguments;
    environment = environmentOverrides;
    return <Command>[
        commandBuilder.getOutputDiffingVmCommand(
            executable, arguments, environment, expectedOutput)];
  }
}

class FletchVMRuntimeConfiguration extends DartVmRuntimeConfiguration {
  FletchVMRuntimeConfiguration();

  List<Command> computeRuntimeCommands(
      TestSuite suite,
      CommandBuilder commandBuilder,
      CommandArtifact artifact,
      List<String> arguments,
      Map<String, String> environmentOverrides) {
    String script = artifact.filename;
    String type = artifact.mimeType;
    if (script != null && type != 'application/fletch-snapshot') {
      throw "Fletch VM cannot run files of type '$type'.";
    }
    var argumentsUnfold = ["-Xunfold-program"]..addAll(arguments);

    // NOTE: We assume that `fletch` behaves the same as invoking
    // the DartVM in terms of exit codes.
    return <Command>[
        commandBuilder.getVmCommand(
            "${suite.buildDir}/fletch", arguments, environmentOverrides),
        commandBuilder.getVmCommand(
            "${suite.buildDir}/fletch", argumentsUnfold, environmentOverrides)];
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
      List<String> arguments,
      Map<String, String> environmentOverrides) {
    throw "Unimplemented runtime '$runtimeType'";
  }
}
