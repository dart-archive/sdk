// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Sample the connects to a https server
//
// The sample will connect to the httpbin.org https server get back the
// public ip.
// This requires an internet connection.
library sample.tls;

import 'package:mbedtls/mbedtls.dart';
import 'dart:dartino.ffi';
import 'package:ffi/ffi.dart';
import 'package:http/http.dart';

main() {
  var port = 443;
  var host = "httpbin.org";
  var socket = new TLSSocket.connect(host, port);
  print("Connected to $host:$port");
  var https = new HttpConnection(socket);
  var request = new HttpRequest("/ip");
  request.headers["Host"] = "httpbin.org";
  var response = https.send(request);
  var responseString = new String.fromCharCodes(response.body);
  // Reponse looks like this
  // {
  //   "origin": "2.109.66.196"
  // }
  var ip = responseString.split('"')[3];
  print("Hello $ip");
  socket.close();
}
