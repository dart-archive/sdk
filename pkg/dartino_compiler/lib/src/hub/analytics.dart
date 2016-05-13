// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// This library contains analytics utilities for reading, writing, and
// maintaining the analytics unique user identifier (uuid).
library dartino_compiler.worker.analytics;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' show Hash, SHA256;
import 'package:instrumentation_client/instrumentation_client.dart';

import '../console_print.dart' show OneArgVoid;
import '../guess_configuration.dart' show dartinoVersion;
import '../messages.dart' show analyticsRecordChoiceFailed;
import '../please_report_crash.dart'
    show
        crashReportRequested,
        requestBugReportOnOtherCrashMessage,
        stringifyError;
import '../verbs/infrastructure.dart' show fileUri;
import 'sentence_parser.dart' show looksLikeAUri;

const String _dartinoUuidEnvVar = const String.fromEnvironment('dartino.uuid');

// Tags used when sending analytics
const String TAG_COMPLETE = 'complete';
const String TAG_ERROR = 'error';
const String TAG_ERRMSG = 'errmsg';
const String TAG_REQUEST = 'request';
const String TAG_SHUTDOWN = 'shutdown';
const String TAG_STARTUP = 'startup';

class Analytics {
  static const String optOutValue = 'opt-out';

  final OneArgVoid _log;

  InstrumentationClient _client;

  final List<int> _hashSalt = Platform.localHostname.codeUnits;

  /// The url used by [InstrumentationClient] to send analytics.
  final String serverUrl;

  /// The uri for the file that stores the analytics unique user id
  /// or `null` if it cannot be determined.
  final Uri uuidUri;

  String _uuid;

  /// `true` if the user should be prompted to opt-in.
  bool shouldPromptForOptIn = true;

  Analytics(this._log, {String serverUrl, Uri uuidUri})
      : this.serverUrl = serverUrl ?? defaultServerUrl,
        this.uuidUri = uuidUri ?? defaultUuidUri;

  bool get hasOptedIn => _uuid != null && !hasOptedOut;

  bool get hasOptedOut => _uuid == optOutValue;

  /// Return the uuid or `null` if no analytics should be sent.
  String get uuid => hasOptedOut ? null : _uuid;

  /// Erase the current uuid so that the user will be prompted the next time.
  void clearUuid() {
    _uuid = null;
    shouldPromptForOptIn = true;
    if (uuidUri == null) return;
    File uuidFile = new File.fromUri(uuidUri);
    if (uuidFile.existsSync()) uuidFile.deleteSync();
  }

  /// Return a string which is a hash of the original string.
  String hash(String original) {
    Hash hash = new SHA256()..add(_hashSalt)..add(original.codeUnits);
    return BASE64.encode(hash.close());
  }

  /// If the given string looks like a Uri,
  /// then return a salted hash of the string, otherwise return the string.
  String hashUri(String str) => looksLikeAUri(str) ? hash(str) : str;

  /// Return a list where each word that looks like a Uri has been hashed.
  Iterable<String> hashAllUris(List<String> words) =>
      words.map((String word) => hashUri(word));

  /// Return a string where each word that looks like a Uri has been hashed.
  String hashUriWords(String stringOfWords) {
    if (stringOfWords == null) return 'null';
    return hashAllUris(stringOfWords.split(' ')).join(' ');
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

  void logComplete(int exitCode) => _send([TAG_COMPLETE, '$exitCode']);

  void logError(error, [StackTrace stackTrace]) =>
      _send([TAG_ERROR, hashUriWords(error), stackTrace?.toString() ?? 'null']);

  void logErrorMessage(String userErrMsg) =>
      _send([TAG_ERRMSG, hashUriWords(userErrMsg)]);

  void logRequest(List<String> arguments) =>
      _send(<String>[TAG_REQUEST]..addAll(hashAllUris(arguments)));

  void logShutdown() => _send([TAG_SHUTDOWN]);

  void logStartup() => _send([
        TAG_STARTUP,
        uuid,
        dartinoVersion,
        Platform.version,
        Platform.operatingSystem
      ]);

  /// If the user has opt-in to analytics, then send the given [message]
  /// to the analytics server so that it will be logged with other messages.
  /// The format of the data blob sent to the server mirrors the format
  /// that the Dart analysis server uses for sending instrumentation data.
  void _send(List<String> fields) {
    if (_client == null) {
      if (!hasOptedIn) return;
      _client =
          new InstrumentationClient(userID: uuid, serverEndPoint: serverUrl);
    }

    // Write an escaped version of the given [field] to the given [buffer].
    void _escape(StringBuffer buffer, String field) {
      int index = field.indexOf(':');
      if (index < 0) {
        buffer.write(field);
        return;
      }
      int start = 0;
      while (index >= 0) {
        buffer.write(field.substring(start, index));
        buffer.write('::');
        start = index + 1;
        index = field.indexOf(':', start);
      }
      buffer.write(field.substring(start));
    }

    // Join the values of the given fields,
    // escaping the separator character by doubling it.
    StringBuffer buffer = new StringBuffer();
    buffer.write(new DateTime.now().millisecondsSinceEpoch.toString());
    for (String field in fields) {
      buffer.write(':');
      _escape(buffer, field);
    }

    _client.logWithPriority(buffer.toString());
  }

  /// Signal that the client is done communicating with the analytics server.
  /// This method should be invoked exactly one time and no other methods
  /// should be invoked on this instance after this method has been invoked.
  Future shutdown() async {
    if (_client != null) {
      logShutdown();
      await _client.shutdown();
      _client = null;
    }
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

  /// The default analytics server.
  static const String defaultServerUrl =
      'https://dartino-instr-fe.appspot.com/rpc';

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
