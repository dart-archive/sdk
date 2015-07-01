// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';
import 'dart:fletch.io';
import 'dart:typed_data';

import 'package:expect/expect.dart';
import 'package:http/http.dart';

void main() {
  testGet();
}

void testGet() {
  ServerSocket server = new ServerSocket("127.0.0.1", 0);

  Fiber.fork(() {
    // Server is a simple raw Socket.
    final expected = "GET / HTTP/1.1\r\nHost: myhost\r\n\r\n";
    final response = "HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nheya";
    var socket = server.accept();
    var data = new Uint8List.view(socket.read(expected.length));
    var request = new String.fromCharCodes(data);
    Expect.equals(expected, request);
    socket.write(stringToByteBuffer(response));
    socket.close();
    server.close();
  });

  var socket = new Socket.connect("127.0.0.1", server.port);
  HttpConnection connection = new HttpConnection(socket);
  HttpRequest request = new HttpRequest("/");
  request.headers["Host"] = "myhost";

  HttpResponse response = connection.send(request);
  Expect.equals(200, response.statusCode);
  Expect.equals("OK", response.reasonPhrase);
  Expect.equals("heya", new String.fromCharCodes(response.body));

  socket.close();
}
