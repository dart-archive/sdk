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
// Dartino library, which can then be consumed by other Dartino programs
// such as netlibmain.dart.

library netlib;

import 'dart:dartino.ffi';
import 'package:ffi/ffi.dart';

final ForeignLibrary _netLib =
    Foreign.platform == Foreign.FREERTOS)
        ? ForeignLibrary.main
        : new ForeignLibrary.fromName(
              ForeignLibrary.bundleLibraryName('netlib'));

final netlibProtocolVersion = _netLib.lookup('NetlibProtocolVersion');
final netlibProtocolDesc = _netLib.lookup('NetlibProtocolDesc');
final netlibConfigure = _netLib.lookup('NetlibConfigure');
final netlibConnect = _netLib.lookup('NetlibConnect');
final netlibSend = _netLib.lookup('NetlibSend');
final netlibRegisterReceiver = _netLib.lookup('NetlibRegisterReceiver');
final netlibTick = _netLib.lookup('NetlibTick');
final netlibDisconnect = _netLib.lookup('NetlibDisconnect');

class netlibClient {
  int _clientId = -1;
  String _URI = null;
  List _handlerFunctions = new List<ForeignDartFunction>();

  // Returns the supported protocol [version].
  int get version {
    // NetlibProtocolVersion takes no arguments, and returns an int.
    return netlibProtocolVersion.icall$0();
  }

  // Returns a textual description of the protocol.
  String get description {
    // NetlibProtocolDesc takes no arguments, and returns a a pointer.
    return cStringToString(netlibProtocolDesc.pcall$0());
  }

  // Creates a new netlib client using protocol version [version] and
  // endpoint [URI].
  netlibClient(this._clientId, this._URI) {
    // Create a struct that contains the config options.
    var configOptions = new Struct.finalized(2);
    configOptions.setField(0, _clientId);
    ForeignMemory uri = new ForeignMemory.fromStringAsUTF8(_URI);
    configOptions.setField(1, uri.address);

    // NetlibConfigure takes a struct argument, and returns void.
    netlibConfigure.vcall$1(configOptions.address);
    uri.free();
    configOptions.free();
  }

  // Connects to the server. [configure] must be called first to specify the
  // server URI.
  int connect() {
    if (_clientId == -1 || _URI == null) {
      return -1;
    }

    // NetlibConnect takes an int argument, and returns an int.
    int _netlibPort = 80;
    return netlibConnect.icall$1(_netlibPort);
  }

  // Sends [message] to the current server;
  int send(String message) {
    var foreignMessage = new ForeignMemory.fromStringAsUTF8(message);
    int result = netlibSend.icall$2(7, foreignMessage);
    foreignMessage.free();

    return result;
  }


  Function _wrapOnReceive (void handler(String message)) {
    return (int cPointer) {
      try {
        String s = cStringToString(new ForeignPointer(cPointer));
        handler(s);
        return 0;
      } catch (e) {
        print("Error '$e' in callback handler!");
        return -1;
      }
    };
  }

  // Registers a new receiver for message type [messageType].
  void registerReceiver(int messageType, void handler(String message)) {
    // The native library expects a handler that takes a string pointer as it's
    // argument, but the consumer of this librarty will pass in a handler that
    // takes a Dart string. We adapt the types by wrapping the consumer handler
    // in a function that retrieves the Dart string from the c string pointer.
    var newHandlerFunction = new ForeignDartFunction(_wrapOnReceive(handler));
    // NetlibRegisterReceiver takes an int, and a function pointer.
    netlibRegisterReceiver.icall$2(messageType, newHandlerFunction);
    _handlerFunctions.add(newHandlerFunction);
  }

  // Allow netlib to process any new incoming messages. This must be called at
  // least once every 10 msec.
  void tick() {
    netlibTick.icall$0();
  }

  // Disconnects from the server, and frees all resources.
  void disconnect() {
    netlibDisconnect.icall$0();
    _handlerFunctions.forEach((f) => f.free());
  }
}
