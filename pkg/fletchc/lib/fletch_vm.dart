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

  FletchVm(this.process, this.socket);

  FletchVm.existing(this.socket);

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

    vmProcess.stdout.drain();
    vmProcess.stderr
        .transform(new Utf8Decoder())
        .transform(new LineSplitter())
        .listen((line) { print('stderr: $line'); });

    bool hasValue = await connectionIterator.moveNext();
    assert(hasValue);
    var vmSocket = connectionIterator.current;
    server.close();

    return new FletchVm(vmProcess, vmSocket);
  }
}
