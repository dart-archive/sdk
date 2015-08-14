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
  'r'/'run'                             run main
  'b <method name> <bytecode index>'    set breakpoint
  'bf <file> <line> <column>'           set breakpoint
  'd <breakpoint id>'                   delete breakpoint
  'lb'                                  list breakpoints
  's'                                   step
  'so'                                  step over
  'fibers'                              list all process fibers
  'finish'                              finish current method (step out)
  'restart'                             restart the selected frame
  'sb'                                  step bytecode
  'sob'                                 step over bytecode
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

  Future handleLine(String line) async {
    if (line.isEmpty) line = previousLine;
    if (line.isEmpty) {
      printPrompt();
      return;
    }
    previousLine = line;
    if (echo) session.writeStdoutLine(line);
    List<String> commandComponents =
        line.split(' ').where((s) => !s.isEmpty).toList();
    String command = commandComponents[0];
    switch (command) {
      case 'help':
        session.writeStdoutLine(HELP);
        break;
      case 'b':
        var method =
            (commandComponents.length > 1) ? commandComponents[1] : 'main';
        var bci =
            (commandComponents.length > 2) ? commandComponents[2] : '0';
        bci = int.parse(bci, onError: (_) => null);
        if (bci == null) {
          session.writeStdoutLine('### invalid bytecode index: $bci');
          break;
        }
        List<Breakpoint> breakpoints =
            await session.setBreakpoint(methodName: method, bytecodeIndex: bci);
        for (Breakpoint breakpoint in breakpoints) {
          session.writeStdoutLine("breakpoint set: $breakpoint");
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
          session.writeStdoutLine('### invalid line number: $line');
          break;
        }
        int columnNumber = int.parse(column, onError: (_) => null);
        if (columnNumber == null) {
          await session.setFileBreakpointFromPattern(file, line, column);
        } else {
          await session.setFileBreakpoint(file, line, columnNumber);
        }
        break;
      case 'bt':
        await session.backtrace();
        break;
      case 'f':
        var frame =
            (commandComponents.length > 1) ? commandComponents[1] : "-1";
        frame = int.parse(frame, onError: (_) => null);
        if (frame == null || !session.selectFrame(frame)) {
          session.writeStdoutLine('### invalid frame number: $frame');
        }
        break;
      case 'l':
        String listing = session.list();
        if (listing == null) {
          session.writeStdoutLine("### failed listing source");
        } else {
          session.writeStdoutLine(listing);
        }
        break;
      case 'disasm':
        String disassembly = session.disasm();
        if (disassembly == null) {
          session.writeStdoutLine("### failed disassembling source");
        } else {
          session.writeStdoutLine(disassembly);
        }
        break;
      case 'c':
        if (checkRunning()) {
          Command response = await session.cont();
          if (response is! ProcessTerminated) {
            await session.backtrace();
          }
        }
        break;
      case 'd':
        var id = (commandComponents.length > 1) ? commandComponents[1] : null;
        id = int.parse(id, onError: (_) => null);
        if (id == null) {
          session.writeStdoutLine('### invalid breakpoint number: $id');
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
        if (commandComponents.length <= 1) {
          await session.printAllVariables();
          break;
        }
        String variableName = commandComponents[1];
        if (variableName.startsWith('*')) {
          await session.printVariableStructure(variableName.substring(1));
        } else {
          await session.printVariable(variableName);
        }
        break;
      case 'q':
      case 'quit':
        await session.terminateSession();
        break;
      case 'r':
      case 'run':
        if (checkNotRunning()) {
          Command response = await session.debugRun();
          if (response is! ProcessTerminated) {
            await session.backtrace();
          }
        }
        break;
      case 's':
        if (checkRunning()) {
          Command response = await session.step();
          if (response is! ProcessTerminated) {
            await session.backtrace();
          }
        }
        break;
      case 'sb':
        if (checkRunning()) await session.stepBytecode();
        break;
      case 'so':
        if (checkRunning()) {
          Command response = await session.stepOver();
          if (response is! ProcessTerminated) {
            await session.backtrace();
          }
        }
        break;
      case 'sob':
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
            session.writeStdoutLine('### invalid flag $toggle');
            break;
        }
        break;
      default:
        session.writeStdoutLine('### unknown command: $command');
        break;
    }
    if (!session.terminated) printPrompt();
  }

  bool checkNotRunning() {
    if (!session.running) return true;
    session.writeStdoutLine('### program already running');
    return false;
  }

  bool checkRunning() {
    if (session.running) return true;
    session.writeStdoutLine('### program not running');
    return false;
  }

  Future<int> run() async {
    session.writeStdoutLine(BANNER);
    printPrompt();
    await for(var line in stream) {
      await handleLine(line);
      // Breaking out of the await for closes the input
      // stream subscription.
      if (session.terminated) break;
    }
    return 0;
  }
}
