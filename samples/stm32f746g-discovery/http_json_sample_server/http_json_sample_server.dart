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
    print('GET request from ${request.connectionInfo.remoteAddress.address} '
          'on port ${request.connectionInfo.localPort}, '
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
  String localFile(path) => Platform.script.resolve(path).toFilePath();

  // Load certificates and private key for the self-signed server
  // certificate. These certificates and the key have been copied from
  // the secure sockets tests for the Dart SDK.
  SecurityContext serverContext = new SecurityContext()
    ..useCertificateChain(localFile('server_chain.pem'))
    ..usePrivateKey(localFile('server_key.pem'),
                    password: 'dartdart');

  HttpServer server =
      await HttpServer.bind(InternetAddress.ANY_IP_V4, 8080);
  print('Listening for http requests on port ${server.port}');
  HttpServer secureServer =
      await HttpServer.bindSecure(
          InternetAddress.ANY_IP_V4, 8443, serverContext);
  print('Listening for https requests on port ${secureServer.port}');

  server.listen(handleRequest);
  secureServer.listen(handleRequest);
}
