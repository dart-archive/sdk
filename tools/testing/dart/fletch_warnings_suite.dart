// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library test.fletch_warnings_suite;

import 'dart:io' as io;

import 'dart:convert' show
    UTF8;

import 'test_suite.dart' show
    TestSuite,
    TestUtils;

import 'test_runner.dart' show
    Command,
    CommandBuilder,
    CompilationCommandOutputImpl,
    TestCase;

import 'runtime_configuration.dart' show
    RuntimeConfiguration;

import 'status_file_parser.dart' show
    Expectation,
    TestExpectations;

import 'compiler_configuration.dart' show
    CommandArtifact;

const Map<String, String> URIS_TO_ANALYZE = const <String, String>{
    "driver_main": "package:fletchc/src/driver/driver_main.dart",
    "fletch_test_suite": "tests/fletch_tests/fletch_test_suite.dart",
};

class FletchWarningsRuntimeConfiguration extends RuntimeConfiguration {
  final String system;
  final String dartBinary;

  FletchWarningsRuntimeConfiguration(Map configuration)
      : system = configuration['system'],
        dartBinary = '${TestUtils.buildDir(configuration)}'
                     '${io.Platform.pathSeparator}dart',
        super.subclass();

  List<Command> computeRuntimeCommands(
      TestSuite suite,
      CommandBuilder commandBuilder,
      CommandArtifact artifact,
      String script,
      List<String> arguments,
      Map<String, String> environmentOverrides) {
    return <Command>[
        commandBuilder.getAnalysisCommand(
            'dart2js-analyze-only',
            dartBinary,
            <String>[
                '-ppackage/',
                'package/compiler/src/dart2js.dart',
                '-ppackage/', // For dart2js.
                '--library-root=../dart/sdk/',
                '--analyze-only',
                '--show-package-warnings',
                '--categories=Server']..addAll(arguments),
            null,
            flavor: 'dart2js')];
  }
}

class FletchWarningsSuite extends TestSuite {
  FletchWarningsSuite(Map configuration, testSuiteDir)
      : super(configuration, "warnings");

  void forEachTest(
      void onTest(TestCase testCase),
      Map testCache,
      [void onDone()]) {
    this.doTest = onTest;
    if (configuration['runtime'] != 'fletch_warnings') {
      onDone();
      return;
    }

    RuntimeConfiguration runtimeConfiguration =
        new RuntimeConfiguration(configuration);

    // There are no status files for this. Please fix warnings.
    TestExpectations expectations = new TestExpectations();

    URIS_TO_ANALYZE.forEach((String testName, String uri) {
      List<Command> commands = runtimeConfiguration.computeRuntimeCommands(
          this,
          CommandBuilder.instance,
          null,
          uri,
          <String>[uri],
          null);
      var testCase = new TestCase(
          '$suiteName/$testName',
          commands,
          configuration, expectations.expectations(testName));
      enqueueNewTestCase(testCase);
    });

    onDone();
  }
}

/// Pattern that matches warnings (from dart2js) that contain a comment saying
/// "NO_LINT".
final RegExp noLintFilter =
    new RegExp(r"[^\n]*\n[^\n]*\n[^\n]* // NO_LINT\n *\^+\n");

class FletchWarningsOutputCommand extends CompilationCommandOutputImpl {
  FletchWarningsOutputCommand(
      Command command, int exitCode, bool timedOut,
      List<int> stdout, List<int> stderr,
      Duration time, bool compilationSkipped)
      : super(
          command, exitCode, timedOut, stdout, stderr, time,
          compilationSkipped);

  Expectation result(TestCase testCase) {
    Expectation result = super.result(testCase);
    if (result != Expectation.PASS) return result;

    var filteredStdout =
        UTF8.decode(stdout, allowMalformed: true).replaceAll(noLintFilter, "");
    if (!filteredStdout.isEmpty) {
      return Expectation.STATIC_WARNING;
    }

    return Expectation.PASS;
  }
}
