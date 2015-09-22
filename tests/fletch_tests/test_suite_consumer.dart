// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Command-line utility for helping testing fletch_test_suite.dart outside
/// test.py.
///
/// Example usage:
///
/// Create a file with messages, for example, messages.txt:
///
///     {"type":"ListTests"}
///     {"type":"RunTest","name":"test1"}
///     {"type":"RunTest","name":"test2"}
///
/// Then run this command:
///
///     cat messages.txt | \
///       ./third_party/bin/$OS/dart --packages=.packages/ \
///           tests/fletch_tests/fletch_test_suite.dart | \
///       ./third_party/bin/$OS/dart --packages=.packages \
///           tests/fletch_tests/test_suite_consumer.dart
library fletch_tests.test_suite_consumer;

import 'dart:io' show
    stdin;

import 'fletch_test_suite.dart' show
    utf8Lines;

import 'messages.dart' show
    Message,
    messageTransformer;

main() async {
  await for(Message message in utf8Lines(stdin).transform(messageTransformer)) {
    print(message);
  }
}
