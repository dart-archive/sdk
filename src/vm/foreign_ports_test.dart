// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:ffi';

final Foreign postPort = Foreign.lookup('PostPortToExternalCode');
final Foreign postBackForeign = Foreign.lookup('PostBackForeign');

main() {
  var channel = new Channel();
  var port = new Port(channel);
  postPort.icall$1(port);
  var value = channel.receive();
  if (value.getInt32(0) != 42) throw "Unexpected value in external.";
  postBackForeign.icall$1(value);
}
