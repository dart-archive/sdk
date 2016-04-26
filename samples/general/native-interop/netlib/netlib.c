// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stddef.h>
#include <time.h>
#include "netlib.h"

NetlibConfig *currentConfig;

#define VERSION 7
int NetlibProtocolVersion() {
  return VERSION;
}

char* NetlibProtocolDesc() {
  char *desc = "IoT live synchronization protocol";
  return desc;
}

void NetlibConfigure(NetlibConfig* config) {
  currentConfig = config;
  printf("netlib: Configuring to client id %i, server '%s'.\n",
    currentConfig->id, currentConfig->serverURI);
  fflush(stdout);
}

int NetlibConnect(int port) {
  srand(time(NULL));

  if (port == 80 && currentConfig != NULL)
    return 0;
  else
    return -1;
}

int NetlibDisconnect() {
  // TODO: Not implemented.
  return 0;
}

int NetlibSend(int messageType, char* message) {
  printf("netlib: Sent message '%s' of type %d.\n", message, messageType);
  fflush(stdout);
  return 0;
}

struct receiver {
  int type;
  receiveHandler handler;
};
struct receiver currentReceivers[MAX_RECEIVE_HANDLERS];
int nextHandlerSlot = 0;
int NetlibRegisterReceiver(int messageType, receiveHandler handler) {
  if (nextHandlerSlot >= MAX_RECEIVE_HANDLERS)
    return -1;

  currentReceivers[nextHandlerSlot].type = messageType;
  currentReceivers[nextHandlerSlot].handler = handler;
  nextHandlerSlot++;
  return 0;
}

void DispatchMessage(int messageType, char* message) {
  for (int i = 0; i < nextHandlerSlot; i++) {
    if (currentReceivers[i].type == messageType) {
      currentReceivers[i].handler(message);
    }
  }
}

void NetlibTick() {
  // This is where a real library would actually check if there is any new
  // communication. In this sample we just generate a random message roughly
  // every tenth call.
  if ((rand() % 10) == 9) {
    // Generate a random type, and a radomly selected message.
    int type = rand() % 10;
    char* msg;
    switch (rand() % 3) {
      case 0:
        msg = "Temperature is rising fast!";
        break;
      case 1:
        msg = "Warning: critical temperature reached";
        break;
      case 2:
        msg = "It's getting cold";
        break;
    }
    DispatchMessage(type, msg);
  }
}
