// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver;

import 'dart:io';

import 'dart:async' show
    Future,
    StreamIterator;

import 'dart:typed_data' show
    ByteData,
    Uint8List;

import 'dart:convert' show
    UTF8;

Future main(List<String> arguments) async {
  File configFile = new File.fromUri(Uri.base.resolve(arguments.first));

  ServerSocket server =
      await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);
  int port = server.port;

  // Write the port number to a config file. This lets multiple command line
  // programs share this persistent driver process, which in turn eliminates
  // start up overhead.
  configFile.writeAsStringSync("$port");

  // Print the port number so the launching process knows where to connect, and
  // that the socket port is ready.
  print(port);

  var connectionIterator = new StreamIterator(server);

  try {
    while (await connectionIterator.moveNext()) {
      await handleClient(connectionIterator.current);
    }
  } finally {
    // TODO(ahe): Do this in a SIGTERM handler.
    await configFile.delete();
  }
}

Future handleClient(Socket controlSocket) async {
  // Start another server socket to set up sockets for stdin, stdout, and
  // stderr.
  ServerSocket server =
      await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);
  int port = server.port;

  writeNetworkUint32(controlSocket, port);

  var connectionIterator = new StreamIterator(server);
  await connectionIterator.moveNext();

  // Socket for stdin and stdout.
  Socket stdio = connectionIterator.current;
  await connectionIterator.moveNext();

  // Socket for stderr.
  Socket stderr = connectionIterator.current;

  // Now that we have the sockets, close the server.
  server.close();

  stdio.listen((List<int> stdin) {
    String s = UTF8.decode(stdin);
    if (s == "q") {
      // Send exit code to client.
      writeNetworkUint32(controlSocket, 0);
    } else if (s == "x") {
      // Send exit code to client.
      writeNetworkUint32(controlSocket, 1);
    } else if (s == "c") {
      // Send exit code to client.
      writeNetworkUint32(controlSocket, 254);
    } else {
      stderr.writeln("Received on stdin: $s");
    }
  });

  stderr.writeln("Message to stderr");
  stdio.writeln("Message to stdin");
}

void writeNetworkUint32(Socket socket, int i) {
  Uint8List list = new Uint8List(4);
  ByteData view = new ByteData.view(list.buffer);
  view.setUint32(0, i);
  socket.add(list);
}
