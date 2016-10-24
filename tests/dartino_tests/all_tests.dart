// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Modify this file to include more tests.
library dartino_tests.all_tests;

import 'dart:async' show
    Future;

import 'self_tests.dart' as self;

import 'verb_tests.dart' as verbs;

import 'dartino_complete_tests.dart' as complete;

import '../dartino_compiler/incremental/production_mode.dart' as
    incremental_production;

import '../dartino_compiler/incremental/experimental_mode.dart' as
    incremental_experimental;

import '../dartino_compiler/driver/test_control_stream.dart' as controlStream;

import '../dartino_compiler/serialize_settings_tests.dart' as
    serialize_settings_tests;

import 'zone_helper_tests.dart' as zone_helper;

import 'sentence_tests.dart' as sentence_tests;

import 'message_tests.dart' as message_tests;

import 'multiprogram_tests.dart' as multiprogram_tests;

import 'snapshot_stacktrace_tests.dart' as snapshot_stacktrace_tests;

import '../dartino_compiler/run.dart' as run;

import '../dartino_compiler/driver/test_vm_connection.dart' as
    test_vm_connection;

import '../debugger/debugger_tests.dart' as debugger_tests;

import '../flash_sd_card_tests/flash_sd_card_tests.dart' as flash_sd_card_tests;

import '../mbedtls_tests/ssl_tests.dart' as ssl_tests;

import '../../pkg/sdk_services/test/service_tests.dart' as sdk_service_tests;

import '../mdns_tests/mdns_tests.dart' as mdns_tests;

import '../power_management_tests/power_management_tests.dart'
    as power_management_tests;

import '../agent_tests/agent_tests.dart' as agent_tests;

import '../golem/golem_tests.dart' as golem_tests;

import '../version_tests/version_tests.dart' as version_tests;

import '../cli_tests/cli_tests.dart' as cli_tests;

import 'dartino_analyze_test.dart' as analyze_tests;

import 'dartino_analyze_samples.dart' as analyze_samples;

typedef Future NoArgFuture();

/// Map of names to tests or collections of tests.
///
/// Regarding the entries of this map:
///
/// If the key does NOT end with '/*', it is considered a normal test case, and
/// the value is a closure that returns a future that completes as the test
/// completes. If the test fails, it should complete with an error.
///
/// Otherwise, if the key DOES end with '/*', it is considered a collection of
/// tests, and the value must be a closure that returns a `Future<Map<String,
/// NoArgFuture>>` consting of only normal test cases.
const Map<String, NoArgFuture> TESTS = const <String, NoArgFuture>{
  'self/testSleepForThreeSeconds': self.testSleepForThreeSeconds,
  'self/testAlwaysFails': self.testAlwaysFails,
  'self/testNeverCompletes': self.testNeverCompletes,
  'self/testMessages': self.testMessages,
  'self/testPrint': self.testPrint,

  'verbs/helpTextFormat': verbs.testHelpTextFormatCompliance,

  // Slow tests, should run early so we don't wait for them.
  'incremental/production/*': incremental_production.list,
  'incremental/experimental/*': incremental_experimental.list,

  // Slow tests, should run early so we don't wait for them.
  'debugger/*': debugger_tests.listTests,

  // Slow tests, should run early so we don't wait for them.
  'agent_tests/*': agent_tests.listTests,

  // Slow tests, should run early so we don't wait for them.
  'cli_tests/*': cli_tests.listTests,

  // Slow tests, show run early so we don't wait for them.
  'analyze_samples/*': analyze_samples.listTests,

  'analyze_tests': analyze_tests.main,

  'complete_tests': complete.main,

  'snapshot_stacktrace_tests/*': snapshot_stacktrace_tests.listTests,

  'controlStream/testControlStream': controlStream.testControlStream,

  'zone_helper/testEarlySyncError': zone_helper.testEarlySyncError,
  'zone_helper/testEarlyAsyncError': zone_helper.testEarlyAsyncError,
  'zone_helper/testLateError': zone_helper.testLateError,
  'zone_helper/testUnhandledLateError': zone_helper.testUnhandledLateError,
  'zone_helper/testAlwaysFails': zone_helper.testAlwaysFails,
  'zone_helper/testCompileTimeError': zone_helper.testCompileTimeError,

  'sentence_tests': sentence_tests.main,

  'message_tests': message_tests.main,

  'multiprogram_tests/*': multiprogram_tests.listTests,

  'serialize_settings_tests': serialize_settings_tests.main,

  'run/application_test': run.test,
  'run/incremental_debug_info': run.testIncrementalDebugInfo,

  'test_vm_connection/test': test_vm_connection.test,
  'test_vm_connection/testCloseImmediately':
      test_vm_connection.testCloseImmediately,
  'test_vm_connection/testCloseAfterCommitChanges':
      test_vm_connection.testCloseAfterCommitChanges,
  'test_vm_connection/testCloseAfterProcessRun':
      test_vm_connection.testCloseAfterProcessRun,

  'flash_sd_card_tests/*': flash_sd_card_tests.listTests,

  'ssl_tests/ssl_tests': ssl_tests.main,

  'sdk_service_tests/sdk_service_tests': sdk_service_tests.main,

  // Test the mDNS package.
  // TODO(sgjesse): publish the mDNS package as an ordinary package and pull
  // it in through third_party.
  'mdns_tests/*': mdns_tests.listTests,

  // Test the power management package.
  // TODO(sgjesse): publish the power management package as an ordinary
  // package and pull it in through third_party.
  'power_management_tests/*': power_management_tests.listTests,

  // Test for the golem performance tracking infrastructure.
  // If this test breaks you probably need to update the golem performance
  // tracking infrastructure as well.
  'golem_tests': golem_tests.main,

  'version_tests': version_tests.main,

};
