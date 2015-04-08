// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch.session;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'commands.dart';

part 'command_reader.dart';
part 'input_handler.dart';

class Session {
  final Socket vmSocket;

  StreamIterator<Command> vmCommands;

  Session(this.vmSocket);

  void writeSnapshot(String snapshotPath) {
    new WriteSnapshot(snapshotPath).addTo(vmSocket);
    vmSocket.drain();
    quit();
  }

  void run() {
    const ProcessSpawnForMain().addTo(vmSocket);
    const ProcessRun().addTo(vmSocket);
    vmSocket.drain();
    quit();
  }

  Future debug() async {
    vmCommands = new CommandReader(vmSocket).iterator;
    const ProcessSpawnForMain().addTo(vmSocket);
    await new InputHandler(this).run();
  }

  Future nextVmCommand() async {
    var hasNext = await vmCommands.moveNext();
    assert(hasNext);
    return vmCommands.current;
  }

  Future handleProcessStop() async {
    Command response = await nextVmCommand();
    switch(response.code) {
      case CommandCode.UncaughtException:
        await backtrace(-1);
        const ForceTermination().addTo(vmSocket);
        break;
      case CommandCode.ProcessTerminate:
        print('### process terminated');
        quit();
        exit(0);
        break;
      default:
        assert(response.code == CommandCode.ProcessBreakpoint);
        break;
    }
  }

  Future debugRun() async {
    const ProcessRun().addTo(vmSocket);
    await handleProcessStop();
  }

  // TODO(ager): Implement.
  Future backtrace() async {
  }

  void quit() {
    vmSocket.close();
  }
}
