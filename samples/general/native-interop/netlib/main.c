// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
#include <stdio.h>
#include <unistd.h>
#include "netlib.h"

void OnReceive(int messageType, char* message) {
  printf("Received message type %i with contents '%s'.\n",
         messageType, message);
}

void OnReceiveType3(char* message) {
  OnReceive(3, message);
}

void OnReceiveType7(char* message) {
  OnReceive(7, message);
}

int main() {
  // Get protocol information.
  int version = NetlibProtocolVersion();
  char *description = NetlibProtocolDesc();
  printf("Protocol is '%s', version %d.\n", description, version);

  // Configure the server.
  NetlibConfig configOptions;
  configOptions.id = 42;
  configOptions.serverURI = "http://myserver.com/netlib";
  NetlibConfigure(&configOptions);

  // Attempt to connect.
  int result = NetlibConnect(80);
  if (result) {
    printf("Connection error: %d.\n", result);
  } else {
    // Send a message.
    result = NetlibSend(7, "Hi from C!");

    // Register two receive handlers.
    NetlibRegisterReceiver(3, OnReceiveType3);
    NetlibRegisterReceiver(7, OnReceiveType7);

    // Main app loop.
    for (int i = 0; i < 1000; i++) {
      NetlibTick();
      usleep(10000);
    }
  }

  return 0;
}
