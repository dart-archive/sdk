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

  Stream stream;
  String previousLine = '';

  InputHandler(this.session, [this.stream]);

  printPrompt() => stdout.write('> ');

  Future handleLine(String line) async {
    if (line.isEmpty) line = previousLine;
    if (line.isEmpty) {
      printPrompt();
      return;
    }
    previousLine = line;
    if (stream != stdin) print(line);
    List<String> commandComponents =
        line.split(' ').where((s) => !s.isEmpty).toList();
    String command = commandComponents[0];
    switch (command) {
      case 'help':
        print(HELP);
        break;
      case 'b':
        var method =
            (commandComponents.length > 1) ? commandComponents[1] : 'main';
        var bci =
            (commandComponents.length > 2) ? commandComponents[2] : '0';
        bci = int.parse(bci, onError: (_) => null);
        if (bci == null) {
          print('### invalid bytecode index: $bci');
          break;
        }
        await session.setBreakpoint(methodName: method, bytecodeIndex: bci);
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
          print('### invalid line number: $line');
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
        if (frame == null) {
          print('### invalid frame number: $frame');
          break;
        }
        session.selectFrame(frame);
        break;
      case 'l':
        session.list();
        break;
      case 'disasm':
        session.disasm();
        break;
      case 'c':
        await session.cont();
        break;
      case 'd':
        var id = (commandComponents.length > 1) ? commandComponents[1] : null;
        id = int.parse(id, onError: (_) => null);
        if (id == null) {
          print('### invalid breakpoint number: $id');
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
        await session.debugRun();
        break;
      case 's':
        await session.step();
        break;
      case 'sb':
        await session.stepBytecode();
        break;
      case 'so':
        await session.stepOver();
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
            print('### invalid flag $toggle');
            break;
        }
        break;
      default:
        print('### unknown command: $command');
        break;
    }
    printPrompt();
  }

  Future run() async {
    print(BANNER);
    printPrompt();
    var inputLineStream = stream;
    if (inputLineStream == null) {
      stream = stdin;
      inputLineStream = stdin.transform(new Utf8Decoder())
                             .transform(new LineSplitter());
    }
    await for(var line in inputLineStream) {
      await handleLine(line);
    }
  }
}
