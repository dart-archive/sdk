// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:io';

import 'package:power_management/power_management.dart' as power_management;

/// Provide general system functionality used in different platform specific
/// sdk scripts for getting and using extra resources.
class SDKServices {
  OutputService service;

  SDKServices(OutputService this.service);

  /// Download the [url] to [file] and provide progress information.
  Future downloadWithProgress(
      Uri url,
      File destination,
      {int retryCount: 3,
       Duration retryInterval: const Duration(seconds: 3)}) async {

    await power_management.initPowerManagement();

    Future doDownload(HttpClient client) async {
      service.log('Downloading $url');
      var request = await client.getUrl(url);
      var response = await request.close();
      service.log('Response headers:\n${response.headers}');
      if (response.statusCode != 200) {
        service.failure('Failed request: ${response.reasonPhrase}');
      }
      int totalBytes = response.headers.contentLength;
      int bytes = 0;
      StreamTransformer progressTransformer =
          new StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (List<int> value, EventSink<List<int>> sink) {
              bytes += value.length;
              service.updateProgress(
                  'received ${bytes ~/ (1024 * 1024)} Mb '
                  'of ${totalBytes ~/ (1024 * 1024)} Mb');
              sink.add(value);
            },
            handleDone: (EventSink<List<int>> sink) {
              sink.close();
            });
      await response
          .transform(progressTransformer).pipe(destination.openWrite());
    }

    var client;
    int id = power_management.disableSleep('Downloading SD card image');
    try {
      client = new HttpClient();
      int count = 0;
      while (true) {
        count++;
        service.startProgress('Downloading: ');
        try {
          await doDownload(client);
          service.endProgress('DONE');
          break;
        } catch (e, s) {
          if (count < retryCount) {
            service.endProgress(
                'Failed. Retrying in ${retryInterval.inSeconds} seconds.');
            service.log('Download failure: $e\n$s');
            await sleep(retryInterval);
          } else {
            await service.failure('Download failed after $retryCount retries '
                                  ' with error $e');
          }
        }
      }
    } finally {
      power_management.enableSleep(id);
      await client.close();
    }
    service.log('Finished downloading $url');
  }
}

class DownloadException implements Exception {
  final String message;
  DownloadException(this.message);
  String toString() => 'DownloadException($message)';
}

/// Class to output information and progress for sdk services. Some platform
/// specific scripts use their own implementation of this.
class OutputService {
  File _logFile;
  int _previousProgressLength = 0;
  String _progressPrefix;
  Function _writeStdout;
  Function _writeLog;

  void log(String s) => _writeLog(s);

  /// Start a progress indicator.
  void startProgress(String prefix) {
    if (_progressPrefix != null) {
      throw new StateError('Progress is already active');
    }
    _writeStdout(prefix);
    _progressPrefix = prefix;
  }

  void _clearProgress() {
    _writeStdout('\r$_progressPrefix${' ' * _previousProgressLength}');
  }

  /// Update a progress indicator.
  void updateProgress(Object message) {
    _clearProgress();
    var messageString = '$message';
    _writeStdout('\r$_progressPrefix$messageString');
    _previousProgressLength = messageString.length;
  }

  /// End a progress indicator.
  void endProgress(String message) {
    _clearProgress();
    _writeStdout('\r$_progressPrefix$message');
    _progressPrefix = null;
  }

  void failure(String s) {
    throw new DownloadException(s);
  }

  void _defaultWriteStdout(String s) {
    stdout.write(s);
  }

  void _defaultWriteLog(String s) {
    if (_logFile != null) {
      _logFile.writeAsStringSync('$s\n', mode: FileMode.APPEND);
    } else {
      print('LOG: $s');
    }
  }

  OutputService([this._writeStdout, this._writeLog]) {
    if (_writeStdout == null) {
      _writeStdout = _defaultWriteStdout;
    }
    if (_writeLog == null) {
      _writeLog = _defaultWriteLog;
    }
  }

  OutputService.logToFile(this._logFile) {
    if(_logFile.existsSync()) {
      _logFile.deleteSync();
    }
  }
}
