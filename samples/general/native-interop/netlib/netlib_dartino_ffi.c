// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// This file adds a number of public symbols from the netlib library
// (libnetlib.a) into the Dartino static FFI lookup. This makes it
// possible to lookup these symbols from a static image build for
// running on a device. In a static image all symbols are looked up
// through the ForeignLibrary.main foreign library, as libraries are
// not dynamically loaded.
//
// The following code will print the integer returned from calling
// NetlibProtocolVersion in the netlib C library.
//
// import 'dart:dartino.ffi';
//
// final netlibProtocolVersion =
//     ForeignLibrary.main.lookup('NetlibProtocolVersion');
//
// main() {
//   print(netlibProtocolVersion.icall$0());
// }

#include "netlib.h"

#include "include/static_ffi.h"

DARTINO_EXPORT_STATIC(NetlibProtocolVersion)
DARTINO_EXPORT_STATIC(NetlibProtocolDesc)
DARTINO_EXPORT_STATIC(NetlibConfigure)
DARTINO_EXPORT_STATIC(NetlibConnect)
DARTINO_EXPORT_STATIC(NetlibSend)
DARTINO_EXPORT_STATIC(NetlibRegisterReceiver)
DARTINO_EXPORT_STATIC(NetlibTick)
DARTINO_EXPORT_STATIC(NetlibDisconnect)
