// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Tests that [Settings] instances can be serialized and deserialized.
library dartino_tests.settings_persist;

import 'dart:async' show Future;

import 'dart:convert';

import 'package:dartino_compiler/src/worker/developer.dart' show
    Address,
    DeviceType,
    IncrementalMode,
    Settings,
    parseSettings;

import 'package:dartino_compiler/src/verbs/infrastructure.dart' show
    fileUri;

import 'package:expect/expect.dart';

void testSettingsRoundTrip(Settings settings) {
  Settings before = settings;
  Map<String, dynamic> json = before.toJson();
  Settings after = parseSettings(const JsonCodec().encode(json),
      Uri.parse("file:///dummy.dartino-settings"));
  Expect.equals(before.packages, after.packages);
  Expect.listEquals(before.options, after.options);
  Expect.mapEquals(before.constants, after.constants);
  Expect.equals(before.deviceAddress, after.deviceAddress);
  Expect.equals(before.deviceType, after.deviceType);
  Expect.equals(before.incrementalMode, after.incrementalMode);
}

Future<Null> main() async {
  testSettingsRoundTrip(new Settings.empty());
  testSettingsRoundTrip(new Settings(
      fileUri(".packages", Uri.base),
      ["a", "b", "c"],
      {"a": "A", "b": "b"},
      new Address("localhost", 8080),
      DeviceType.embedded,
      IncrementalMode.experimental));
}
