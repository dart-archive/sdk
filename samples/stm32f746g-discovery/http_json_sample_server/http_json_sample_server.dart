// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Simple sample server to be used with http_json_sample.dart.

import 'dart:convert';
import 'dart:io';

int requestCount = 0;

void handleRequest(HttpRequest request) {
  requestCount++;
  HttpResponse response = request.response;
  if (request.method == 'GET') {
    print('GET request from ${request.connectionInfo.remoteAddress}, '
          'request no. $requestCount');
    if (request.uri.toFilePath() == '/message.json') {
      String message = JSON.encode({"message": "Hello Dartino!"});
      response..statusCode = HttpStatus.OK
        ..headers.contentType = new ContentType("application", "json")
        ..contentLength = message.length
        ..write(message)
        ..close();
    } else {
      response..statusCode = HttpStatus.NOT_FOUND
        ..close();
    }
  } else {
    response..statusCode = HttpStatus.METHOD_NOT_ALLOWED
      ..write('Unsupported request: ${request.method}.')
      ..close();
  }
}

main() async {
  HttpServer server =
      await HttpServer.bind(InternetAddress.ANY_IP_V4, 8080);
  await for (HttpRequest request in server) {
    handleRequest(request);
  }
}
