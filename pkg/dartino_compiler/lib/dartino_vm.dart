// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_vm;

// Please keep this file independent of other libraries in this package as we
// import this directly into test.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DartinoVm {
  final Process process;

  final String host;

  final int port;

  final Future<int> exitCode;

  final Stream<String> stdoutLines;

  final Stream<String> stderrLines;

  const DartinoVm(
      this.process,
      this.host,
      this.port,
      this.exitCode,
      this.stdoutLines,
      this.stderrLines);

  Future<Socket> connect() => Socket.connect(host, port);

  static Future<DartinoVm> start(
      String vmPath,
      {Uri workingDirectory,
       List<String> arguments: const <String>[],
       Map<String, String> environment}) async {
    Process process =
        await Process.start(
            vmPath, arguments, environment: environment,
            workingDirectory: workingDirectory?.toFilePath());

    Completer<String> addressCompleter = new Completer<String>();
    List<String> outputBeforeAddress = new List<String>();
    Completer stdoutCompleter = new Completer();
    Stream<String> stdoutLines = convertStream(
        process.stdout, stdoutCompleter,
        (String line) {
          const String prefix = "Waiting for compiler on ";
          if (!addressCompleter.isCompleted)
            outputBeforeAddress.add(line);
            if (line.startsWith(prefix)) {
            addressCompleter.complete(line.substring(prefix.length));
            return false;
          }
          return true;
        }, () {
          if (!addressCompleter.isCompleted) {
            addressCompleter.completeError(
                new StateError('The dartino-vm did not print an address on '
                               'which it is listening on. '
                               'Output from the dartino-vm until now: \n'
                               '${outputBeforeAddress.join('\n')}'));
          }
        });

    Completer stderrCompleter = new Completer();
    Stream<String> stderrLines = convertStream(process.stderr, stderrCompleter);

    await process.stdin.close();

    Future exitCode = process.exitCode.then((int exitCode) async {
      await stdoutCompleter.future;
      await stderrCompleter.future;
      if (!addressCompleter.isCompleted) {
        addressCompleter.completeError(
            "VM exited before print an address on stdout");
      }
      return exitCode;
    });

    List<String> address = (await addressCompleter.future).split(":");

    return new DartinoVm(
        process, address[0], int.parse(address[1]), exitCode,
        stdoutLines, stderrLines);
  }

  static Stream<String> convertStream(
      Stream<List<int>> stream,
      Completer doneCompleter,
      [bool onData(String line), void onDone()]) {
    StreamController<String> controller = new StreamController<String>();
    Function handleData;
    if (onData == null) {
      handleData = controller.add;
    } else {
      handleData = (String line) {
        if (onData(line)) {
          controller.add(line);
        }
      };
    }
    stream
        .transform(new Utf8Decoder())
        .transform(new LineSplitter())
        .listen(
            handleData,
            onError: controller.addError,
            onDone: () {
              if (onDone != null) onDone();
              controller.close();
              doneCompleter.complete();
            });
    return controller.stream;
  }
}
