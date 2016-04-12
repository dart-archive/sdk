// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// This library contains analytics utilities for reading, writing, and
// maintaining the analytics unique user identifier (uuid).
library dartino_compiler.worker.analytics;

import 'dart:io';
import 'dart:math';

import '../messages.dart' show
    analyticsRecordChoiceFailed;

import '../please_report_crash.dart' show
    crashReportRequested,
    requestBugReportOnOtherCrashMessage,
    stringifyError;

import '../verbs/infrastructure.dart' show
    fileUri;

const String _dartinoUuidEnvVar = const String.fromEnvironment('dartino.uuid');

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

  /// Load the UUID from the environment or read it from disk.
  /// Return [true] if it was successfully loaded or read
  /// or [false] if the user should be prompted to opt-in or opt-out.
  bool loadUuid() {
    String value = _dartinoUuidEnvVar?.trim();
    if (value?.isNotEmpty == true) {
      _uuid = value;
      shouldPromptForOptIn = false;
      return true;
    }
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

  /// Create and persist a new uuid.
  /// The newly created uuid can be accessed via [uuid].
  void writeNewUuid() {
    int millisecondsSinceEpoch = new DateTime.now().millisecondsSinceEpoch;
    int random = new Random().nextInt(0x3fffffff);
    _uuid = '$millisecondsSinceEpoch$random';
    shouldPromptForOptIn = false;
    _writeUuid();
  }

  /// Record that the user has opted out of analytics.
  void writeOptOut() {
    _uuid = optOutValue;
    shouldPromptForOptIn = false;
    _writeUuid();
  }

  /// Write the current uuid to disk.
  void _writeUuid() {
    if (uuidUri == null) {
      _analyticsWriteUuidError("Failed to determine uuid file path.");
    }
    File uuidFile = new File.fromUri(uuidUri);
    try {
      uuidFile.parent.createSync(recursive: true);
      uuidFile.writeAsStringSync(_uuid);
    } catch (error, stackTrace) {
      _analyticsWriteUuidError("Failed to write uuid.", error, stackTrace);
    }
  }

  /// If there is a problem recording the user's analytics choice
  /// then make it clear to the user that this has happened
  /// and exit with prejudice to ensure that we don't report analytics.
  void _analyticsWriteUuidError(String errorMsg, [error, StackTrace trace]) {
    try {
      if (!crashReportRequested) {
        print(requestBugReportOnOtherCrashMessage);
        crashReportRequested = true;
      }
      // Notify the user that there was a problem.
      print(analyticsRecordChoiceFailed);
      if (errorMsg != null) print(errorMsg);
      String errorAndTrace = stringifyError(error, trace);
      if (error != null) print(errorAndTrace);
      // And log the problem.
      _log("$errorMsg.\n$errorAndTrace");
    } catch (_) {
      // ignore all errors and fall through to exit
    }
    exit(1);
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
      if (!path.endsWith('/')) path += '/';
      return fileUri(path, Uri.base).resolve('DartinoUuid.txt');
    } else {
      String path = Platform.environment['HOME'];
      if (path == null || !new Directory(path).existsSync()) return null;
      if (!path.endsWith('/')) path += '/';
      return fileUri(path, Uri.base).resolve('.dartino_uuid');
    }
  }
}
