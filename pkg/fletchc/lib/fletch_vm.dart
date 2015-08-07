// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_vm;

// Please keep this file independent of other libraries in this package as we
// import this directly into test.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class FletchVm {
  final Process process;

  final String host;

  final int port;

  final Future<int> exitCode;

  final Stream<String> stdoutLines;

  final Stream<String> stderrLines;

  const FletchVm(
      this.process,
      this.host,
      this.port,
      this.exitCode,
      this.stdoutLines,
      this.stderrLines);

  Future<Socket> connect() => Socket.connect(host, port);

  static Future<FletchVm> start(
      String vmPath,
      {List<String> arguments: const <String>[],
       Map<String, String> environment}) async {
    Process process =
        await Process.start(vmPath, arguments, environment: environment);

    Completer<String> addressCompleter = new Completer<String>();
    Completer stdoutCompleter = new Completer();
    Stream<String> stdoutLines = convertStream(
        process.stdout, stdoutCompleter,
        (String line) {
          if (!addressCompleter.isCompleted) {
            addressCompleter.complete(
                line.substring("Waiting for compiler on ".length));
            return false;
          }
          return true;
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

    return new FletchVm(
        process, address[0], int.parse(address[1]), exitCode,
        stdoutLines, stderrLines);
  }

  static Stream<String> convertStream(
      Stream<List<int>> stream,
      Completer doneCompleter,
      [bool onData(String line)]) {
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
              controller.close();
              doneCompleter.complete();
            });
    return controller.stream;
  }
}
