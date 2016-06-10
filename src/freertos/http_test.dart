// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Demonstrates how to use the http package.

import 'dart:convert';
import 'dart:dartino';

import 'package:http/http.dart';
import 'package:socket/socket.dart';
import 'package:stm32/ethernet.dart';

const String host = "192.168.0.2";
const int port = 8080;
const String path = "/message.json";

main() {
  print('Hello from Dartino');
  if (!ethernet.initializeNetworkStack(
      const InternetAddress(const <int>[192, 168, 0, 10]),
      const InternetAddress(const <int>[255, 255, 255, 0]),
      const InternetAddress(const <int>[192, 168, 0, 1]),
      const InternetAddress(const <int>[8, 8, 8, 8]))) {
    throw 'Failed to initialize network stack';
  }

  print('Network up, requesting DHCP configuration...');

  int i = 0;
  int sleepInterval = 5000;
  while (NetworkInterface.list().isEmpty) {
    printNetworkInfo();
    sleep(sleepInterval);
    i++;
    print("waited ${i*sleepInterval} ms");
  }

  int requestCount = 0;
  while (true) {
    requestCount++;
    print('Performing request $requestCount');
    Map json = downloadData(host, port, path);
    if (json == null) {
      print('Failed to make HTTP request');
      sleep(1000);
    }
  }
}

void printNetworkInfo() {
  bool eth0Connected = false;
  for (NetworkInterface interface in
      NetworkInterface.list(includeLoopback: true)) {
    print("${interface.name}:");
    for (InternetAddress address in interface.addresses) {
      print("  $address");
    }
    print("  ${interface.isConnected ? 'connected' : 'not connected'}");
    if (interface.name == 'eth0' && interface.isConnected) eth0Connected = true;
  }
}

/// Download a JSON object from the server [host]:[port] at [uri] and return the
/// parsed result as a Dart map.
Map downloadData(String host, int port, String uri) {
  Socket socket;
  try {
    socket = new Socket.connect(host, port);
    HttpConnection https = new HttpConnection(socket);
    HttpRequest request = new HttpRequest(uri);
    request.headers["Host"] = host;
    HttpResponse response = https.send(request);
    if (response.statusCode != HttpStatus.OK) {
      print("Failed to receive document: ${response.statusCode}");
      return null;
    }
    HttpHeaders headers = response.headers;
    String contentType = headers.contentType;
    if (contentType == "application/json") {
      Object result = JSON.decode(new String.fromCharCodes(response.body));
      if (result is! Map) {
        print("Expected a map.");
        return null;
      }
      return result;
    } else {
      print("Expected content of type 'application/json'"
            " but got '$contentType'.");
      return null;
    }
  } on SocketException catch (e) {
    print(e);
    return null;
  } finally {
    socket?.close();
  }
}
