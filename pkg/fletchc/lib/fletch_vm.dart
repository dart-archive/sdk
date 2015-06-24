// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch.vm;

import 'compiler.dart' show
    FletchCompiler;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class FletchVm {
  final Process process;
  final Socket socket;
  final StreamIterator<bool> stdoutSyncMessages;
  final StreamIterator<bool> stderrSyncMessages;

  FletchVm(this.process,
           this.socket,
           this.stdoutSyncMessages,
           this.stderrSyncMessages);

  FletchVm.existing(this.socket);

  static String synchronizationToken = new String.fromCharCodes(
      [60, 61, 33, 123, 3, 2, 1, 2, 3, 125, 33, 61, 62]);

  static bool containsOutputSyncToken(String line) {
    return line.endsWith(synchronizationToken);
  }

  static Future<FletchVm> start(FletchCompiler compiler) async {
    var server = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);

    List<String> vmOptions = <String>[
        '--port=${server.port}',
    ];

    var connectionIterator = new StreamIterator(server);

    String vmPath = compiler.fletchVm.toFilePath();

    if (compiler.verbose) {
      print("Running '$vmPath ${vmOptions.join(" ")}'");
    }
    var vmProcess = await Process.start(vmPath, vmOptions);

    StreamController stdoutController = new StreamController();
    StreamController stderrController = new StreamController();

    void handleLine(String line, StreamController controller, IOSink out) {
      if (containsOutputSyncToken(line)) {
        controller.add(null);
        if (line.length > synchronizationToken.length) {
          int prefixLength = line.length - synchronizationToken.length;
          out.write(line.substring(0, prefixLength));
        }
      } else {
        out.writeln(line);
      }
    }

    vmProcess.stdout
        .transform(new Utf8Decoder())
        .transform(new LineSplitter())
        .listen((line) {
          handleLine(line, stdoutController, stdout);
        }).asFuture().whenComplete(stdoutController.close);

    vmProcess.stderr
        .transform(new Utf8Decoder())
        .transform(new LineSplitter())
        .listen((line) {
          handleLine(line, stderrController, stderr);
        }).asFuture().whenComplete(stderrController.close);

    bool hasValue = await connectionIterator.moveNext();
    assert(hasValue);
    var vmSocket = connectionIterator.current;
    server.close();

    return new FletchVm(vmProcess,
                        vmSocket,
                        new StreamIterator(stdoutController.stream),
                        new StreamIterator(stderrController.stream));
  }
}
