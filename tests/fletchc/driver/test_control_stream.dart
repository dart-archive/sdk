// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';

import 'dart:typed_data';

import 'package:expect/expect.dart';

import 'package:fletchc/src/hub/client_commands.dart';

import 'package:fletchc/src/hub/hub_main.dart';

const List<int> stdinCommandData = const <int>[4, 0, 0, 0, 0, 0, 0, 0, 0];

Future<Null> testControlStream() async {
  StreamController<Uint8List> controller = new StreamController<Uint8List>();

  // Test that one byte at the time is handled.
  for (int byte in stdinCommandData) {
    controller.add(new Uint8List.fromList([byte]));
  }

  // Test that two bytes at the time are handled.
  for (int i = 0; i < stdinCommandData.length; i += 2) {
    if (i + 1 < stdinCommandData.length) {
      controller.add(
          new Uint8List.fromList(
              [stdinCommandData[i], stdinCommandData[i + 1]]));
    } else {
      controller.add(new Uint8List.fromList([stdinCommandData[i]]));
    }
  }

  // Test that data from the next command isn't discarded (when the next
  // command is chunked).
  var testData = <int>[]
      ..addAll(stdinCommandData)
      ..addAll(stdinCommandData.sublist(0, 5));
  controller
      ..add(new Uint8List.fromList(testData))
      ..add(new Uint8List.fromList(stdinCommandData.sublist(5)));

  // Test that data from the next command isn't discarded (when there are more
  // than one complete command in the buffer).
  testData = <int>[]
      ..addAll(stdinCommandData)
      ..addAll(stdinCommandData);
  controller.add(new Uint8List.fromList(testData));

  StreamTransformer<List<int>, ClientCommand> transformer =
      new ClientCommandTransformerBuilder().build();
  Future<List<ClientCommand>> commandsFuture =
      controller.stream.transform(transformer).toList();

  await controller.close();

  List<ClientCommand> commands = await commandsFuture;
  Expect.equals(6, commands.length);
  for (ClientCommand command in commands) {
    Expect.stringEquals(
        'ClientCommand(ClientCommandCode.Stdin, [])',
        '$command');
  }
}
