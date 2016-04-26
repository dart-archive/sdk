// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// This sample illustrates how Dartino programs can interface with existing
// native code. For illustrative purposes, it contains C source code
// for a small "fake" library called 'netlib'. This represents the sample
// native library which we which to call from a Dartino program.
//
// Start by reviewing netlib.dart which shows a basic integration where
// the wrapper and main app code is in a single file. The present code shows
// an alternate method where the native library is wrapped and exported as a
// Dartino library in netlibclient.dart, and then consumed here in a
// standalone Dartino program netlibmain.dart.

import 'dart:dartino';
import 'netlibclient.dart';

main() {
  // Configure the server.
  var netlib = new netlibClient(42, "http://myserver.com/netlib");

  // Get protocol information.
  print("Protocol is '${netlib.description}', version ${netlib.version}.");

  // Attempt to connect.
  int result = netlib.connect();
  if (result != 0) {
    print("Connection error: $result.");
  } else {
    // Send a message.
    netlib.send("Hello from Dartino!");

    // Register two receive handlers.
    netlib.registerReceiver(3, onReceiveType3);
    netlib.registerReceiver(7, onReceiveType7);

    // Main app loop. We limit the execution to 1000 loops to illustrate
    // how to properly clean-up resources.
    for (var i = 0; i < 1000; i++) {
      // Yield to the netlib framework giving it a chance to process new
      // messages.
      netlib.tick();

      // This is where the main app code would usually run.
      // In this sample we just sleep a bit.
      sleep(10);
    }

    // Clean-up: Deallocate foreign memory and functions.
    netlib.disconnect();
  }
}

// Dart callback functions invoked when new messages arrive.
// These must return an interger result code back to native.
onReceiveType3(String message) => onReceive(3, message);
onReceiveType7(String message) => onReceive(7, message);
void onReceive(int messageType, String message) {
  print("Received message type $messageType with contents $message");
}
