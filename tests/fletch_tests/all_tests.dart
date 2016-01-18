// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Modify this file to include more tests.
library fletch_tests.all_tests;

import 'dart:async' show
    Completer,
    Future;

import 'self_tests.dart' as self;

import 'verb_tests.dart' as verbs;

import '../fletchc/incremental/feature_test.dart' as incremental;

import '../fletchc/driver/test_control_stream.dart' as controlStream;

import '../fletchc/serialize_settings_tests.dart' as serialize_settings_tests;

import 'zone_helper_tests.dart' as zone_helper;

import 'sentence_tests.dart' as sentence_tests;

import 'message_tests.dart' as message_tests;

import 'multiprogram_tests.dart' as multiprogram_tests;

import 'snapshot_stacktrace_tests.dart' as snapshot_stacktrace_tests;

import '../service_tests/service_tests.dart' as service_tests;

import '../servicec/servicec_tests.dart' as servicec_tests;

import '../fletchc/run.dart' as run;

import '../fletchc/driver/test_vm_connection.dart' as test_vm_connection;

import '../debugger/debugger_tests.dart' as debugger_tests;

import '../flash_sd_card_tests/flash_sd_card_tests.dart' as flash_sd_card_tests;

import '../mdns_tests/mdns_tests.dart' as mdns_tests;

import '../power_management_tests/power_management_tests.dart'
    as power_management_tests;

import '../agent_tests/agent_tests.dart' as agent_tests;

import '../golem/golem_tests.dart' as golem_tests;

import '../version_tests/version_tests.dart' as version_tests;

import '../cli_tests/cli_tests.dart' as cli_tests;

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
  'service_tests/*': service_tests.listTests,

  // Slow tests, should run early so we don't wait for them
  'servicec/*': servicec_tests.listTests,

  // Slow tests, should run early so we don't wait for them.
  'incremental/*': incremental.listTests,

  // Slow tests, should run early so we don't wait for them.
  'debugger/*': debugger_tests.listTests,

  // Slow tests, should run early so we don't wait for them.
  'agent_tests/*': agent_tests.listTests,

  // Slow tests, should run early so we don't wait for them.
  'cli_tests/*': cli_tests.listTests,

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
