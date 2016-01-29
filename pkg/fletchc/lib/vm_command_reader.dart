// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of fletch.vm_session;

class SessionCommandTransformerBuilder
    extends CommandTransformerBuilder<VmCommand> {

  VmCommand makeCommand(int code, ByteData payload) {
    return new VmCommand.fromBuffer(
        VmCommandCode.values[code], toUint8ListView(payload));
  }
}

class VmCommandReader {
  final StreamIterator<VmCommand> iterator;

  VmCommandReader(
      Stream<List<int>> stream,
      Sink<List<int>> stdoutSink,
      Sink<List<int>> stderrSink)
      : iterator = new StreamIterator<VmCommand>(
          filterCommandStream(stream, stdoutSink, stderrSink));

  static Stream<VmCommand> filterCommandStream(
      Stream<List<int>> stream,
      Sink<List<int>> stdoutSink,
      Sink<List<int>> stderrSink) async* {
    // When done with the data on the socket, we do not close
    // stdoutSink and stderrSink. They are usually stdout and stderr
    // and the user will probably want to add more on those streams
    // independently of the messages added here.
    StreamTransformer<List<int>, VmCommand> transformer =
        new SessionCommandTransformerBuilder().build();
    await for (VmCommand command in stream.transform(transformer)) {
      if (command is StdoutData) {
        if (stdoutSink != null) stdoutSink.add(command.value);
      } else if (command is StderrData) {
        if (stderrSink != null) stderrSink.add(command.value);
      } else {
        yield command;
      }
    }
  }
}
