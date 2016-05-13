// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Library is not re-entrant
#ifndef SAMPLES_GENERAL_NATIVE_INTEROP_NETLIB_NETLIB_H_
#define SAMPLES_GENERAL_NATIVE_INTEROP_NETLIB_NETLIB_H_

// Returns the currently implemented version of the protocol.
int NetlibProtocolVersion();

// Returns a textual description of the protocol.
char* NetlibProtocolDesc();

// Defines a configuration of the protocol.
struct NetlibConfig {
  // The id of the client. This has to be unique.
  int id;
  // The URI of the server to connect to.
  char* serverURI;
};
typedef struct NetlibConfig NetlibConfig;

// Sets a new configuration.
void NetlibConfigure(NetlibConfig* config);

// Connects to the server specified in the current configuration.
int NetlibConnect(int port);

// Disconnects from the server.
int NetlibDisconnect();

// Sends a new message of the specified type.
int NetlibSend(int messageType, char* message);

// Registers a new event handler callback function.
// No more than MAX_RECEIVE_HANDLERS handlers may be set.
const int MAX_RECEIVE_HANDLERS = 10;
typedef void (*receiveHandler) (char* message);
int NetlibRegisterReceiver(int messageType, receiveHandler handler);

// Gives the framework a change to process any external events, and invoke
// callbacks for any new messages. This has to be called at least every
// 100 milliseconds to prevent communication issues.
void NetlibTick();

#endif  // SAMPLES_GENERAL_NATIVE_INTEROP_NETLIB_NETLIB_H_
