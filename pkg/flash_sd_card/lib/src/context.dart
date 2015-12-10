// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

/// General context information for running the application.
class Context {
  StreamIterator _stdin;
  IOSink _stdout;
  IOSink _installLog;
  ArgResults _arguments;

  String _progressPrefix;
  int _previousProgressLength = 0;

  Future<Directory> _tmpDir;

  Context(List<String> args,
          {Stream stdinStream, IOSink stdoutSink, bool writeInstallLog: true}) {
    // Parse the command line arguments.
    var parser = new ArgParser();
    parser.addOption('sd-card');
    parser.addOption('log-file');
    parser.addFlag('skip-download');
    parser.addFlag('skip-decompress');
    parser.addFlag('skip-write');
    parser.addFlag('configure-network-only');
    parser.addOption('version');
    parser.addOption('image-url');
    parser.addOption('zip-file');
    parser.addOption('image-file');
    parser.addOption('tmp-dir');
    _arguments = parser.parse(args);

    if (writeInstallLog) {
      _installLog = new File(logFileName).openWrite();
    }
    stdinStream ??= stdin;
    _stdin = new StreamIterator(stdinStream.transform(UTF8.decoder));
    stdoutSink ??= stdout;
    _stdout = stdoutSink;
  }

  String get sdCardDevice => _arguments['sd-card'];

  bool get skipDownload => _arguments['skip-download'];

  bool get skipDecompress => _arguments['skip-decompress'];

  bool get skipWrite => _arguments['skip-write'];

  bool get configureNetworkOnly => _arguments['configure-network-only'];

  String get logFileName {
    var logFileName = _arguments['log-file'];
    if (logFileName == null) logFileName = 'flash_sd_card.log';
    return logFileName;
  }

  String get imageUrl => _arguments['image-url'];

  String get zipFileName => _arguments['zip-file'];

  String get imageFileName => _arguments['image-file'];

  Future done() async {
    // Remove tmp dir if created.
    if (_arguments['tmp-dir'] == null && _tmpDir != null) {
      await (await _tmpDir).delete(recursive: true);
    }
    await _installLog?.close();
    await _stdin.cancel();
  }

  /// Write a info message to the user.
  void infoln(Object message) {
    _stdout.writeln('$message');
    // Always log user messages.
    log(message);
  }

  /// Ask the user for input.
  Future<String> readLine(String prompt) async {
    if (prompt != null) {
      _stdout.write(prompt);
    }
    await _stdin.moveNext();
    return _stdin.current.trim();
  }

  /// Ask the user for a hostname.
  Future<String> readHostname(String prompt, String defaultHostname) async {
    bool check(String hostname) {
      var regexp = new RegExp(r'^[a-z][a-z0-9]*$');
      return regexp.hasMatch(hostname);
    }

    while (true) {
      var hostname = await readLine(prompt);
      if (hostname == '') return defaultHostname;
      if (check(hostname)) return hostname;
      infoln('Invalid hostname');
    }
  }

  /// Ask the user for an IP address.
  Future<String> readIPAddress(String prompt, String defaultIPAddress) async {
    bool check(String ipAddress) {
      var regexp = new RegExp(
        r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}'
        r'(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
      return regexp.hasMatch(ipAddress);
    }

    while (true) {
      var ipAddress = await readLine(prompt);
      if (ipAddress == '') return defaultIPAddress;
      if (check(ipAddress)) {
        return ipAddress;
      }
      infoln('Invalid IPv4 address');
    }
  }

  /// Start a progress indicator.
  void startProgress(String prefix) {
    if (_progressPrefix != null) {
      throw new StateError('Progress is already active');
    }
    _stdout.write(prefix);
    _progressPrefix = prefix;
  }

  void _clearProgress() {
    _stdout.write('\r$_progressPrefix${' ' * _previousProgressLength}');
  }

  /// Update a progress indicator.
  void updateProgress(Object message) {
    _clearProgress();
    var messageString = '$message';
    _stdout.write('\r$_progressPrefix$messageString');
    _previousProgressLength = messageString.length;
  }

  /// End a progress indicator.
  void endProgress(String message) {
    _clearProgress();
    _stdout.writeln('\r$_progressPrefix$message');
    _progressPrefix = null;
  }

  log(Object message) {
    _installLog?.writeln('${new DateTime.now()}: $message');
  }

  Future failure(Object message, [Object additionalMessage]) async {
    infoln('FAILURE: $message');
    if (additionalMessage != null) {
      infoln('$additionalMessage');
    }
    await done();
    throw new Failure(message);
  }

  Future<ProcessResult> runProcess(
      String executable, List<String> arguments) async {
    log('Running $executable $arguments');
    var result = await Process.run(
        executable, arguments, stdoutEncoding: UTF8, stderrEncoding: UTF8);
    if (result.exitCode != 0) {
      log('Failure running $executable ${arguments.join('')}');
      log('Exit code: ${result.exitCode}');
    } else {
      log('Success running $executable ${arguments.join('')}');
    }
    log('STDOUT: ${result.stdout}');
    log('STDERR: ${result.stderr}');
    return result;
  }

  Future<Directory> get tmpDir async {
    if (_tmpDir == null) {
      if (_arguments['tmp-dir'] != null) {
        _tmpDir = new Future.value(new Directory(_arguments['tmp-dir']));
      } else {
        _tmpDir = Directory.systemTemp.createTemp('flash_sd_card');
      }
    }
    return _tmpDir;
  }

  Future get version async {
    if (_arguments['version'] != null) {
      return _arguments['version'];
    }
    const String fletchVm = const String.fromEnvironment("fletch-vm");
    if (fletchVm == null || fletchVm.isEmpty) {
      await failure(
          'Failed to determine SDK version. Please use the --version flag.');
    }
    if (!await new File(fletchVm).exists()) {
      await failure(
          'Failed to determine SDK version. '
          "Cannot find the Fletch VM at the expected location '$fletchVm'."
          'Your SDK might be broken');
    }
    var result = await runProcess(fletchVm, ['--version']);
    if (result.exitCode != 0) {
      await failure('Failed to determine SDK version');
    }
    return result.stdout.trim();
  }
}

class Failure implements Exception {
  final String message;
  Failure(this.message);
}
