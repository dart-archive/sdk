// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library todomvc.cli;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'presenter_model.dart';
import 'presenter_mirror.dart';

class CLI {

  var _socket;
  var _iterator;
  var _carry = new BytesBuilder(copy: false);

  Mirror _mirror;
  Map<String, Function> cmds;

  CLI(this._socket, this._mirror) {
    _iterator = new StreamIterator(_socket);
    cmds = {
      "list" : list,
      "new" : create, "create" : create,
      "del" : delete, "delete" : delete,
      "done" : complete, "complete" : complete,
      "clear" : clear,
      "trace" : toggleTrace,
      "quit" : quit,
      "help" : help
    };
  }

  Future<ByteData> _read(int bytes) async {
    while (_carry.length < bytes) {
      await _iterator.moveNext();
      if (_iterator.current == null) {
        print("Lost connection");
        quit();
      }
      _carry.add(_iterator.current);
    }
    var data = _carry.takeBytes();
    assert(data.length >= bytes);
    if (data.length > bytes) {
      // We copy and add to work around an offsets issue with BytesBuilder.
      _carry.add(new Uint8List.view(
          data.buffer, bytes, data.length - bytes).toList());
    }
    return new ByteData.view(data.buffer, 0, bytes);
  }

  // Scheduling for the CLI implementation. We let the individual commands
  // insert synchronization points at which we do a full send & receive.
  sync() async {
    // Send command descriptions.
    ByteData data = serializeList(_mirror.cmds);
    trace("Sending commands: bytes(${data.buffer.lengthInBytes})");
    _socket.add(new Uint8List.view(data.buffer));
    await _socket.flush();
    _mirror.cmds.clear();

    // Read patches size.
    int bytes = getUint32(await _read(4));

    // Read patches.
    trace("Reading patches: bytes(${bytes})");
    data = await _read(bytes);

    // Deserialize patches.
    PatchSet patches = PatchSet.deserialize(data, bytes);
    _mirror.apply(patches);
  }

  // CLI commands. These should do no more than parsing and then either display
  // data from the presentation mirror or forward commands via the presentation
  // mirror.

  Future<bool> list([args]) async {
    await sync();
    var id = 0;
    var current = _mirror.root;
    while (current is! Nil) {
      Cons entry = current.fst;
      current = current.snd;
      Str title = entry.fst;
      Bool done = entry.snd;
      print(" ${id}. [${done.value ? 'done' : 'todo'}] ${title.value}");
      ++id;
    }
    return true;
  }

  Future<bool> create(args) async {
    var title = args.sublist(1).join(' ');
    _mirror.create(title);
    await list();
    return true;
  }

  Future<bool> delete(args) async {
    var id = int.parse(args[1]);
    _mirror.delete(id);
    await list();
    return true;
  }

  Future<bool> complete(args) async {
    var id = int.parse(args[1]);
    _mirror.complete(id);
    await list();
    return true;
  }

  Future<bool> clear(args) async {
    _mirror.clear();
    await list();
    return true;
  }

  bool toggleTrace(args) {
    TRACE = !TRACE;
    stdout.writeln("Set tracing ${TRACE ? 'on' : 'off'}");
    return true;
  }

  bool help([args]) {
    stdout.writeln("commands: list, new, del, done, clear, trace, quit, help");
    return true;
  }

  bool quit([args]) {
    exit(0);
    return false;
  }

}

// Read eval print loop.
repl(CLI cli) async {
  while (true) {
    stdout.write("todos> ");
    var line = stdin.readLineSync();
    if (line == null) {
      cli.quit();
    }
    var tokens = line.split(" ").map((s) => s.trim()).toList();
    if (tokens.length > 0 && cli.cmds.containsKey(tokens.first)) {
      var cmd = tokens.first;
      var res = await cli.cmds[cmd](tokens);
      if (!res) {
        stdout.writeln("command '$cmd' failed to execute");
        cli.help();
      }
    } else {
      stdout.writeln("invalid command: $line");
      cli.help();
    }
  }
}

main() async {
  TRACE = false;
  var socket = await Socket.connect("127.0.0.1", 8182);
  Mirror mirror = new Mirror();
  CLI cli = new CLI(socket, mirror);
  await cli.list();
  repl(cli);
}