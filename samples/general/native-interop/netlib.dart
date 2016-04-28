// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// This sample illustrates how Dartino programs can interface with existing
// native code. For illustrative purposes, it contains C source code
// for a small "fake" library called 'netlib'. This represents the sample
// native library which we which to call from a Dartino program.
//
// The sample illustrates the following techniques:
//
// 1. Calling a native function that returns an int
// 2. Calling a native function that returns a pointer to a string
// 3. Calling a native function that takes a struct as an argument
// 4. Calling a native function that registers a callback function
// 5. Receiving a callback in Dartino from native code
//
// For a sample illustrating how to seperate the wrapping of the native library
// and the main app code using that wrapper, see netlibclient.dart and
// netlibmain.dart.

import 'dart:dartino';
import 'dart:dartino.ffi';
import 'package:ffi/ffi.dart';

final ForeignLibrary _netLib =
    new ForeignLibrary.fromName(ForeignLibrary.bundleLibraryName('netlib'));

final netlibProtocolVersion = _netLib.lookup('NetlibProtocolVersion');
final netlibProtocolDesc = _netLib.lookup('NetlibProtocolDesc');
final netlibConfigure = _netLib.lookup('NetlibConfigure');
final netlibConnect = _netLib.lookup('NetlibConnect');
final netlibSend = _netLib.lookup('NetlibSend');
final netlibRegisterReceiver = _netLib.lookup('NetlibRegisterReceiver');
final netlibTick = _netLib.lookup('NetlibTick');
final netlibDisconnect = _netLib.lookup('NetlibDisconnect');

main() {
  // Get protocol information.
  // NetlibProtocolVersion takes no arguments, and returns an int.
  int version = netlibProtocolVersion.icall$0();
  // NetlibProtocolDesc takes no arguments, and returns a a pointer.
  String description = cStringToString(netlibProtocolDesc.pcall$0());
  print("Protocol is '$description', version $version.");

  // Configure the server.
  // Create a struct that contains 1) an int, and 2) a string.
  var configOptions = new Struct.finalized(2);
  configOptions.setField(0, 42);
  ForeignMemory uri = new ForeignMemory.fromStringAsUTF8(
    "http://myserver.com/netlib");
  configOptions.setField(1, uri.address);
  // NetlibConfigure takes a struct argument, and returns void.
  netlibConfigure.vcall$1(configOptions.address);
  uri.free();
  configOptions.free();

  // Attempt to connect.
  // NetlibConnect takes an int argument, and returns an int.
  int result = netlibConnect.icall$1(80);
  if (result != 0) {
    print("Connection error: $result.");
  } else {
    // Send a message.
    // NetlibSend takes an int and a string pointer, and returns an int.
    var message = new ForeignMemory.fromStringAsUTF8("Hello from Dartino!");
    result = netlibSend.icall$2(7, message);
    message.free();

    // Register two receive handlers.
    // NetlibRegisterReceiver takes an int, and a function pointer.
    var handler3 = new ForeignDartFunction(onReceiveType3);
    netlibRegisterReceiver.icall$2(3, handler3);
    var handler7 = new ForeignDartFunction(onReceiveType7);
    netlibRegisterReceiver.icall$2(7, handler7);

    // Main app loop. We limit the execution to 1000 loops to illustrate
    // how to properly clean-up resources.
    for (var i = 0; i < 1000; i++) {
      // Yield to the netlib framework giving it a chance to process new
      // messages.
      netlibTick.icall$0();

      // This is where the main app code would usually run.
      // In this sample we just sleep a bit.
      sleep(10);
    }

    // Clean-up: Deallocate foreign memory and functions.
    netlibDisconnect.icall$0();
    handler3.free();
    handler7.free();
  }
}

// Dart callback functions invoked when new messages arrive.
// These must return an integer result code back to native.
int onReceiveType3(cStringPointer) => onReceive(3, cStringPointer);
int onReceiveType7(cStringPointer) => onReceive(7, cStringPointer);
int onReceive(int messageType, int cStringPointer) {
  String s = cStringToString(new ForeignPointer(cStringPointer));
  print("Received message type $messageType with contents $s");
  return 0;
}
