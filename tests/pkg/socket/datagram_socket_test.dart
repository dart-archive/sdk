// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:typed_data';

import 'package:expect/expect.dart';
import 'package:os/os.dart' as os;
import 'package:socket/socket.dart';

ByteBuffer toByteBuffer(List<int> ints) {
  var list = new Uint8List(ints.length);
  for (int i = 0; i < ints.length; i++) {
    list[i] = ints[i];
  }
  return list.buffer;
}

bool dataEquals(ByteBuffer a, ByteBuffer b) {
  Uint8List lista = a.asUint8List();
  Uint8List listb = b.asUint8List();
  if (lista.length != listb.length) return false;
  for (int i = 0; i < lista.length; i++) {
    if (lista[i] != listb[i]) return false;
  }
  return true;
}

void main() {
  DatagramSocket receiver = new DatagramSocket.bind("127.0.0.1", 0);
  DatagramSocket sender = new DatagramSocket.bind("127.0.0.1", 0);

  os.InternetAddress target = os.getSystem().lookup("127.0.0.1");
  var payload = toByteBuffer([1, 2, 3, 4]);
  sender.send(target, receiver.port, payload);

  Datagram d = receiver.receive();

  Expect.isTrue(d != null);
  Expect.equals('${target}', '${d.sender}');
  Expect.equals(sender.port, d.port);
  Expect.isTrue(dataEquals(d.data, payload));
}
