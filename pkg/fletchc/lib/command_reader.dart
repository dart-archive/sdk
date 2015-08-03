// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of fletch.session;

class SessionCommandTransformerBuilder
    extends CommandTransformerBuilder<Command> {

  Command makeCommand(int code, ByteData payload) {
    return new Command.fromBuffer(
        CommandCode.values[code], toUint8ListView(payload));
  }
}

class CommandReader {
  final StreamIterator<Command> iterator;

  CommandReader(
      Stream<List<int>> stream,
      Sink<List<int>> stdoutSink,
      Sink<List<int>> stderrSink)
      : iterator = new StreamIterator<Command>(
          filterCommandStream(stream, stdoutSink, stderrSink));

  static Stream<Command> filterCommandStream(
      Stream<List<int>> stream,
      Sink<List<int>> stdoutSink,
      Sink<List<int>> stderrSink) async* {
    // When done with the data on the socket, we do not close
    // stdoutSink and stderrSink. They are usually stdout and stderr
    // and the user will probably want to add more on those streams
    // independently of the messages added here.
    StreamTransformer<List<int>, Command> transformer =
        new SessionCommandTransformerBuilder().build();
    await for (Command command in stream.transform(transformer)) {
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
