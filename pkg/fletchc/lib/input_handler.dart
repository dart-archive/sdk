// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of fletch.session;

const String BANNER = """
Starting session. Type 'help' for a list of commands.
""";

const String HELP = """
Commands:
  'help'                                show list of commands
  'r'/'run'                             start program
  'b [method name] [bytecode index]'    set breakpoint
  'bf <file> [line] [column]'           set breakpoint
  'bf <file> [line] [pattern]'          set breakpoint on first occurrence of
                                        the string pattern on the indicated line
  'd <breakpoint id>'                   delete breakpoint
  'lb'                                  list breakpoints
  's'                                   step until next expression,
                                        enters method invocations
  'n'                                   step until next expression,
                                        does not enter method invocations
  'fibers'                              list all process fibers
  'finish'                              finish current method (step out)
  'restart'                             restart the selected frame
  'sb'                                  step bytecode, enters method invocations
  'nb'                                  step over bytecode, does not enter method invocations
  'c'                                   continue execution
  'bt'                                  backtrace
  'f <n>'                               select frame
  'l'                                   list source for frame
  'p <name>'                            print the value of local variable
  'p *<name>'                           print the structure of local variable
  'p'                                   print the values of all locals
  'disasm'                              disassemble code for frame
  't <flag>'                            toggle one of the flags:
                                          - 'internal' : show internal frames
  'q'/'quit'                            quit the session
""";

class InputHandler {
  final Session session;
  final Stream<String> stream;
  final bool echo;

  String previousLine = '';

  InputHandler(this.session, this.stream, this.echo);

  void printPrompt() => session.writeStdout('> ');

  writeStdout(String s) => session.writeStdout(s);

  writeStdoutLine(String s) => session.writeStdout("$s\n");

  Future handleLine(String line) async {
    if (line.isEmpty) line = previousLine;
    if (line.isEmpty) {
      printPrompt();
      return;
    }
    previousLine = line;
    if (echo) writeStdoutLine(line);
    List<String> commandComponents =
        line.split(' ').where((s) => s.isNotEmpty).toList();
    String command = commandComponents[0];
    switch (command) {
      case 'help':
        writeStdoutLine(HELP);
        break;
      case 'b':
        var method =
            (commandComponents.length > 1) ? commandComponents[1] : 'main';
        var bci =
            (commandComponents.length > 2) ? commandComponents[2] : '0';
        bci = int.parse(bci, onError: (_) => null);
        if (bci == null) {
          writeStdoutLine('### invalid bytecode index: $bci');
          break;
        }
        List<Breakpoint> breakpoints =
            await session.setBreakpoint(methodName: method, bytecodeIndex: bci);
        if (breakpoints != null) {
          for (Breakpoint breakpoint in breakpoints) {
            writeStdoutLine("breakpoint set: $breakpoint");
          }
        } else {
          writeStdoutLine(
              "### failed to set breakpoint at method: $method index: $bci");
        }
        break;
      case 'bf':
        var file =
            (commandComponents.length > 1) ? commandComponents[1] : '';
        var line =
            (commandComponents.length > 2) ? commandComponents[2] : '1';
        var column =
            (commandComponents.length > 3) ? commandComponents[3] : '1';
        line = int.parse(line, onError: (_) => null);
        if (line == null) {
          writeStdoutLine('### invalid line number: $line');
          break;
        }
        Breakpoint breakpoint;
        int columnNumber = int.parse(column, onError: (_) => null);
        if (columnNumber == null) {
          breakpoint =
              await session.setFileBreakpointFromPattern(file, line, column);
        } else {
          breakpoint =
              await session.setFileBreakpoint(file, line, columnNumber);
        }
        if (breakpoint != null) {
          writeStdoutLine("breakpoints set: $breakpoint");
        } else {
          writeStdoutLine("### failed to set breakpoint: $file:$line:$column");
        }
        break;
      case 'bt':
        if (!checkLoaded('cannot print backtrace')) {
          break;
        }
        StackTrace stacktrace = await session.stackTrace();
        if (stacktrace == null) {
          writeStdoutLine('### failed to get backtrace for current program');
        } else {
          writeStdout(stacktrace.format());
        }
        break;
      case 'f':
        var frame =
            (commandComponents.length > 1) ? commandComponents[1] : "-1";
        frame = int.parse(frame, onError: (_) => null);
        if (frame == null || !session.selectFrame(frame)) {
          writeStdoutLine('### invalid frame number: $frame');
        }
        break;
      case 'l':
        String listing = await session.list();
        if (listing == null) {
          writeStdoutLine("### failed listing source");
        } else {
          writeStdoutLine(listing);
        }
        break;
      case 'disasm':
        if (!checkLoaded('cannot show bytecodes')) {
          break;
        }
        StackTrace stacktrace = await session.stackTrace();
        String disassembly = stacktrace != null ? stacktrace.disasm() : null;
        if (disassembly == null) {
          writeStdoutLine("### could not disassemble source for current frame");
          break;
        }
        writeStdoutLine(disassembly);
        break;
      case 'c':
        await handleCommonProcessResponse(await session.cont());
        break;
      case 'd':
        var id = (commandComponents.length > 1) ? commandComponents[1] : null;
        id = int.parse(id, onError: (_) => null);
        if (id == null) {
          writeStdoutLine('### invalid breakpoint number: $id');
          break;
        }
        await session.deleteBreakpoint(id);
        break;
      case 'fibers':
        await session.fibers();
        break;
      case 'finish':
        await session.stepOut();
        break;
      case 'restart':
        await session.restart();
        break;
      case 'lb':
        session.listBreakpoints();
        break;
      case 'p':
        if (!session.loaded) {
          // TODO(lukechurch): Please review this for better phrasing.
          writeStdoutLine('### No code loaded, nothing to print');
          break;
        }
        if (commandComponents.length <= 1) {
          List<RemoteObject> variables = await session.processAllVariables();
          if (variables.isEmpty) {
            writeStdoutLine('### No variables in scope');
          } else {
            for (RemoteObject variable in variables) {
              writeStdoutLine(session.remoteObjectToString(variable));
            }
          }
          break;
        }
        String variableName = commandComponents[1];
        RemoteObject variable;
        if (variableName.startsWith('*')) {
          variableName = variableName.substring(1);
          variable = await session.processVariableStructure(variableName);
        } else {
          variable = await session.processVariable(variableName);
        }
        if (variable == null) {
          writeStdoutLine('### No such variable: $variableName');
        } else {
          writeStdoutLine(session.remoteObjectToString(variable));
        }
        break;
      case 'q':
      case 'quit':
        await session.terminateSession();
        break;
      case 'r':
      case 'run':
        await handleCommonProcessResponse(await session.debugRun());
        break;
      case 's':
        await handleCommonProcessResponse(await session.step());
        break;
      case 'n':
        await handleCommonProcessResponse(await session.stepOver());
        break;
      case 'sb':
        await session.stepBytecode();
        break;
      case 'nb':
        await session.stepOverBytecode();
        break;
      case 't':
        String toggle;
        if (commandComponents.length > 1) {
          toggle = commandComponents[1];
        }
        switch (toggle) {
          case 'internal':
            await session.toggleInternal();
            break;
          default:
            writeStdoutLine('### invalid flag $toggle');
            break;
        }
        break;
      default:
        writeStdoutLine('### unknown command: $command');
        break;
    }
    if (!session.terminated) printPrompt();
  }

  // This method is used to deal with some of the common command responses
  // that can be returned when sending the Fletch VM a command request.
  Future handleCommonProcessResponse(Command response) async {
    if (response is UncaughtException) {
      await session.uncaughtException();
    } else if (response is! ProcessTerminated) {
      StackTrace trace = await session.stackTrace();
      writeStdout(trace.format());
    }
  }

  bool checkLoaded([String postfix]) {
    String message = '### program not loaded';
    message = postfix != null ? '$message, $postfix' : message;
    if (!session.loaded) writeStdoutLine(message);
    return session.loaded;
  }

  Future<int> run() async {
    writeStdoutLine(BANNER);
    printPrompt();
    await for(var line in stream) {
      await handleLine(line);
      // Breaking out of the await for closes the input
      // stream subscription.
      if (session.terminated) break;
    }
    if (!session.terminated) await session.terminateSession();
    return 0;
  }
}
