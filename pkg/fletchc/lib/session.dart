// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch.session;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'commands.dart';
import 'compiler.dart' show FletchCompiler;

part 'command_reader.dart';
part 'input_handler.dart';
part 'stack_trace.dart';

class Session {
  final Socket vmSocket;
  final FletchCompiler compiler;

  StreamIterator<Command> vmCommands;
  StackTrace currentStackTrace;

  Session(this.vmSocket, this.compiler);

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
    currentStackTrace = null;
    Command response = await nextVmCommand();
    switch (response.code) {
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

  Future backtrace(int frame) async {
    if (currentStackTrace == null) {
      new ProcessBacktrace(0).addTo(vmSocket);
      ProcessBacktrace backtraceResponse = await nextVmCommand();
      var frames = backtraceResponse.frames;
      currentStackTrace = new StackTrace(frames);
      for (int i = 0; i < currentStackTrace.frames; ++i) {
        new MapLookup(MapId.methods).addTo(vmSocket);
        new Drop(1).addTo(vmSocket);
        new PopInteger().addTo(vmSocket);
        var objectIdCommand = await nextVmCommand();
        var functionId = objectIdCommand.id;
        var integerCommand = await nextVmCommand();
        var bcp = integerCommand.value;
        currentStackTrace.addFrame(new StackFrame(functionId, bcp));
      }
    }
    if (frame >= currentStackTrace.frames) {
      currentStackTrace = null;
      print('### invalid frame number: $frame');
      return;
    }
    currentStackTrace.write(compiler, frame);
  }

  void quit() {
    vmSocket.close();
  }
}
