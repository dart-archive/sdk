// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Sample that connects to a https server using TLS.
//
// It connects to the httpbin.org https test server, and makes an `/ip`
// request. This returns the public IP of caller.
//
// Note: This sample requires an internet connection.
library sample.tls;

import 'package:mbedtls/mbedtls.dart';
import 'package:http/http.dart';
import 'dart:convert';

main() {
  var port = 443;
  var host = "httpbin.org";
  var socket;
  try {
    // Create and connect a socket connection to httpbin.org
    socket = new TLSSocket.connect(host, port);
    print("Connected to $host:$port");

    // Create a HTTPS connection on the socket, and send a `/ip` request.
    var https = new HttpConnection(socket);
    var request = new HttpRequest("/ip");
    request.headers["Host"] = "httpbin.org";
    var response = https.send(request);
    print("Sent an /ip request to httpbin.org");

    // Decode the response string, and get the origin property.
    Map data = JSON.decode(new String.fromCharCodes(response.body));
    String ip = data["origin"];
    print("Response: '$ip'");
  } catch (e) {
    print('$e');
  } finally {
    socket?.close();
  }
}
