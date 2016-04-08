// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// This library contains analytics utilities for reading, writing, and
// maintaining the analytics unique user identifier (uuid).
library dartino_compiler.worker.analytics;

import 'dart:io';
import 'dart:math';

import '../please_report_crash.dart' show stringifyError;
import '../verbs/infrastructure.dart' show fileUri;

typedef LogMessage(message);

class Analytics {
  static const String optOutValue = 'opt-out';

  final LogMessage _log;

  /// The uri for the file that stores the analytics unique user id
  /// or `null` if it cannot be determined.
  final Uri uuidUri;

  String _uuid;

  /// `true` if the user should be prompted to opt-in.
  bool shouldPromptForOptIn = true;

  Analytics(LogMessage this._log, [Uri uuidUri]) :
      this.uuidUri = uuidUri ?? defaultUuidUri;

  /// Return the uuid or `null` if no analytics should be sent.
  String get uuid {
    return _uuid == optOutValue ? null : _uuid;
  }

  /// Erase the current uuid so that the user will be prompted the next time.
  void clearUuid() {
    _uuid = null;
    shouldPromptForOptIn = true;
    if (uuidUri == null) return;
    File uuidFile = new File.fromUri(uuidUri);
    if (uuidFile.existsSync()) uuidFile.deleteSync();
  }

  /// Read the UUID from disk.
  /// Return [true] if it was successfully read from disk
  /// or [false] if the user should be prompted to opt-in or opt-out.
  bool readUuid() {
    if (uuidUri == null) {
      _log("Failed to determine uuid file path.");
      return false;
    }
    File uuidFile = new File.fromUri(uuidUri);
    try {
      if (uuidFile.existsSync()) {
        String contents = uuidFile.readAsStringSync();
        if (contents != null && contents.length > 5) {
          _uuid = contents;
          shouldPromptForOptIn = false;
          return true;
        }
      }
    } catch (error, stackTrace) {
      _log("Failed to read uuid.\n"
          "${stringifyError(error, stackTrace)}");
      // fall through to return false.
    }
    try {
      if (uuidFile.existsSync()) uuidFile.deleteSync();
    } catch (error, stackTrace) {
      _log("Failed to delete invalid uuid file.\n"
          "${stringifyError(error, stackTrace)}");
      // fall through to return false.
    }
    return false;
  }

  /// Create a new uuid, and return [true] if it is successfully persisted.
  /// The newly created uuid can be accessed via [uuid].
  bool writeNewUuid() {
    int millisecondsSinceEpoch = new DateTime.now().millisecondsSinceEpoch;
    int random = new Random().nextInt(0x3fffffff);
    _uuid = '$millisecondsSinceEpoch$random';
    shouldPromptForOptIn = false;
    if (_writeUuid()) return true;
    // Slightly alter the uuid to indicate it was not persisted
    _uuid = 'temp-$uuid';
    return false;
  }

  /// Record that the user has opted out of analytics.
  /// Return [true] if successfully written to disk.
  bool writeOptOut() {
    _uuid = optOutValue;
    shouldPromptForOptIn = false;
    return _writeUuid();
  }

  /// Write the current uuid to disk and return [true] if successful.
  bool _writeUuid() {
    if (uuidUri == null) {
      _log("Failed to determine uuid file path.");
      return false;
    }
    File uuidFile = new File.fromUri(uuidUri);
    try {
      uuidFile.parent.createSync(recursive: true);
      uuidFile.writeAsStringSync(_uuid);
      return true;
    } catch (error, stackTrace) {
      _log("Failed to write uuid.\n"
          "${stringifyError(error, stackTrace)}");
      return false;
    }
  }

  /// Return the path to the file that stores the analytics unique user id
  /// or `null` if it cannot be determined.
  static Uri get defaultUuidUri {
    if (Platform.isWindows) {
      String path = Platform.environment['LOCALAPPDATA'];
      if (path == null || !new Directory(path).existsSync()) {
        path = Platform.environment['APPDATA'];
        if (path == null || !new Directory(path).existsSync()) return null;
      }
      return fileUri(path, Uri.base).resolve('DartinoUuid.txt');
    } else {
      String path = Platform.environment['HOME'];
      if (path == null || !new Directory(path).existsSync()) return null;
      return fileUri(path, Uri.base).resolve('.dartino_uuid');
    }
  }
}
