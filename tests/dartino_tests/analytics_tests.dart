// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io';

import 'package:dartino_compiler/src/hub/analytics.dart';
import 'package:expect/expect.dart' show Expect;
import 'package:path/path.dart' show isAbsolute, join;

main() {
  bool receivedLogMessage = false;
  log(message) {
    receivedLogMessage = true;
    print(message);
  }
  var tmpDir = Directory.systemTemp.createTempSync('DartinoAnalytics');
  var tmpUuidFile = new File(join(tmpDir.path, '.dartino_uuid_test'));
  final analytics = new Analytics(log, tmpUuidFile.uri);

  Expect.isNotNull(Analytics.defaultUuidUri);
  String defaultUuidPath = Analytics.defaultUuidUri.toFilePath();
  print(defaultUuidPath);
  Expect.isNotNull(defaultUuidPath);
  Expect.isTrue(isAbsolute(defaultUuidPath));

  Expect.isNotNull(analytics.uuidUri);
  var uuidPath = analytics.uuidUri.toFilePath();
  print(uuidPath);
  Expect.isNotNull(uuidPath);
  Expect.isTrue(isAbsolute(uuidPath));

  try {
    analytics.clearUuid();
    Expect.isNull(analytics.uuid);
    Expect.isTrue(analytics.shouldPromptForOptIn);
    Expect.isFalse(analytics.loadUuid());
    Expect.isTrue(analytics.shouldPromptForOptIn);
    Expect.isFalse(tmpUuidFile.existsSync());
    Expect.isFalse(receivedLogMessage);

    analytics.clearUuid();
    Expect.isTrue(analytics.shouldPromptForOptIn);
    Expect.isTrue(analytics.writeOptOut());
    Expect.isFalse(analytics.shouldPromptForOptIn);
    Expect.isNull(analytics.uuid);
    Expect.isTrue(tmpUuidFile.existsSync());
    Expect.equals(Analytics.optOutValue, tmpUuidFile.readAsStringSync());
    Expect.isFalse(receivedLogMessage);

    analytics.clearUuid();
    Expect.isTrue(analytics.shouldPromptForOptIn);
    Expect.isTrue(analytics.writeNewUuid());
    Expect.isFalse(analytics.shouldPromptForOptIn);
    Expect.isNotNull(analytics.uuid);
    Expect.isTrue(analytics.uuid.length > 5);
    Expect.notEquals(analytics.uuid, Analytics.optOutValue);
    Expect.isTrue(tmpUuidFile.existsSync());
    Expect.equals(analytics.uuid, tmpUuidFile.readAsStringSync());
    Expect.isFalse(receivedLogMessage);

    String expectedUuid = analytics.uuid;
    File uuidFileSav = new File('${analytics.uuidUri.toFilePath()}.sav');
    tmpUuidFile.renameSync(uuidFileSav.path);
    analytics.clearUuid();
    uuidFileSav.renameSync(tmpUuidFile.path);
    Expect.isNull(analytics.uuid);
    Expect.isTrue(analytics.shouldPromptForOptIn);
    Expect.isTrue(analytics.loadUuid());
    Expect.isFalse(analytics.shouldPromptForOptIn);
    Expect.equals(expectedUuid, analytics.uuid);
    Expect.isFalse(receivedLogMessage);

    analytics.clearUuid();
    Expect.isFalse(receivedLogMessage);
  } finally {
    if (tmpUuidFile.existsSync()) tmpUuidFile.deleteSync();
    if (tmpDir.existsSync()) tmpDir.deleteSync();
  }
}
