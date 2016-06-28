// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Sample application demonstrating how to connect to an HTTP server,
// request and decode a JSON object. The sample will make both HTTP
// and HTTPS connections.
//
// This sample is targeted at the STM32 Discovery board ethernet embedding, but
// it will also run locally to make debugging and testing easier.
//
// To use this sample, modify the 'host' constants and the fallback IP
// configuration at the end of the file to fit the network
// setup.
//
// Also modify the 'port' and 'securePort' constants to match the HTTP
// and HTTPS port of the server.
//
// There is a sample Dart server in
// http_json_sample_server/http_json_sample_server.dart that can be
// used as a starting point. To run this Dart server use the Dart VM
// which is in internal/dart-sdk/bin/dart of the Dartino SDK.

import 'dart:convert';
import 'dart:dartino';
import 'dart:dartino.ffi';

import 'package:http/http.dart';
import 'package:socket/socket.dart';
import 'package:mbedtls/mbedtls.dart';
import 'package:stm32/ethernet.dart';

// IP address of the server to connect to.
const String host = "192.168.0.2";

// Ports for HTTP and HTTPS connections.
const int httpPort = 8080;
const int httpsPort = 8443;

// The request path on the server.
const String path = "/message.json";

main() {
  // If this sample runs locally or on a Linux device like the Raspberry Pi, the
  // operating system will have initialized the network. On the Discovery board
  // we have to initialize the hardware and network stack before we can use
  // sockets.
  print('Initializing network...');
  if (Foreign.platform == Foreign.FREERTOS) {
    initializeNetwork();
  }

  Map data;

  // Make an HTTP request and print message.
  print('Making HTTP request...');
  data = sendRequest(host, path, secure: false);
  printMessage(data['message']);

  // Make an HTTPS request and print message.
  print('Making HTTPS request...');
  data = sendRequest(host, path, secure: true);
  printMessage(data['message']);
}

void printMessage(String message) {
  print(message != null
      ? "Message from server:\n\n${message}\n"
      : "Server did not send a message");
}

/// Download a JSON object from the server [host]:[port] at [uri] and return the
/// parsed result as a Dart map.
Map sendRequest(String host, String uri, {bool secure: false}) {
  Socket socket;
  try {
    if (secure) {
      socket = new TLSSocket.connect(host, httpsPort);
    } else {
      socket = new Socket.connect(host, httpPort);
    }
    HttpConnection connection = new HttpConnection(socket);
    HttpRequest request = new HttpRequest(uri);
    request.headers["Host"] = host;
    HttpResponse response = connection.send(request);
    if (response.statusCode != HttpStatus.OK) {
      throw new Exception("Failed to receive document: ${response.statusCode}");
    }
    HttpHeaders headers = response.headers;
    String contentType = headers.contentType;
    if (contentType == "application/json") {
      Object result = JSON.decode(new String.fromCharCodes(response.body));
      if (result is! Map) {
        throw new Exception("Expected a map.");
      }
      return result;
    } else {
      throw new Exception("Expected content of type 'application/json'"
          " but got '$contentType'.");
    }
  } finally {
    socket?.close();
  }
}

// Fallback configuration to be used when no DHCP configuration can be obtained.
const fallbackAddress = const InternetAddress(const <int>[192, 168, 0, 10]);
const fallbackNetmask = const InternetAddress(const <int>[255, 255, 255, 0]);
const fallbackGateway = const InternetAddress(const <int>[192, 168, 0, 1]);
const fallbackDnsServer = const InternetAddress(const <int>[8, 8, 8, 8]);

/// Initialize the network stack and wait until the network interface has either
/// received an IP address abd configuration using DHCP or given up and used the
/// provided fallback configuration.
///
/// When this method returns, `NetworkInterface.list().first` can be used to
/// query the IP address and the link status.
void initializeNetwork({
  InternetAddress address: fallbackAddress,
  InternetAddress netmask: fallbackNetmask,
  InternetAddress gateway: fallbackGateway,
  InternetAddress dnsServer: fallbackDnsServer}) {

  if (!ethernet.initializeNetworkStack(address, netmask, gateway, dnsServer)) {
    throw "Failed to initialize network stack";
  }

  while (NetworkInterface.list().first.addresses.isEmpty) {
    sleep(10);
  }
}
