// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of fletch.session;

const String BANNER = """
Starting session.

Commands:
  'r'/'run'                             run main
  'b <method name> <bytecode index>'    set breakpoint
  'bf <file> <line> <column>'           set breakpoint
  'd <breakpoint id>'                   delete breakpoint
  'lb'                                  list breakpoints
  's'                                   step
  'so'                                  step over
  'sb'                                  step bytecode
  'sob'                                 step over bytecode
  'c'                                   continue execution
  'bt'                                  backtrace
  'f <n>'                               select frame
  'l'                                   list source for frame
  'p <name>'                            print the value of local variable
  'p'                                   print the values of all locals
  'disasm'                              disassemble code for frame
  'q'/'quit'                            quit the session
""";

class InputHandler {
  final Session session;
  String previousLine = '';

  InputHandler(this.session);

  printPrompt() => stdout.write('> ');

  Future handleLine(String line) async {
    if (line.isEmpty) line = previousLine;
    previousLine = line;
    List<String> commandComponents =
        line.split(' ').where((s) => !s.isEmpty).toList();
    String command = commandComponents[0];
    switch (command) {
      case 'b':
        var method =
            (commandComponents.length > 1) ? commandComponents[1] : 'main';
        var bci =
            (commandComponents.length > 2) ? commandComponents[2] : '0';
        try {
          bci = int.parse(bci);
        } catch(e) {
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
        try {
          line = int.parse(line);
        } catch(e) {
          print('### invalid line number: $line');
          break;
        }
        try {
          column = int.parse(column);
        } catch(e) {
          await session.setFileBreakpointFromPattern(file, line, column);
          break;
        }
        await session.setFileBreakpoint(file, line, column);
        break;
      case 'bt':
        await session.backtrace();
        break;
      case 'f':
        var frame =
            (commandComponents.length > 1) ? commandComponents[1] : "-1";
        try {
          frame = int.parse(frame);
        } catch(e) {
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
        try {
          id = int.parse(id);
        } catch(e) {
          print('### invalid breakpoint number: $id');
          break;
        }
        await session.deleteBreakpoint(id);
        break;
      case 'lb':
        session.listBreakpoints();
        break;
      case 'p':
        if (commandComponents.length <= 1) {
          await session.printAllVariables();
          break;
        }
        await session.printVariable(commandComponents[1]);
        break;
      case 'q':
      case 'quit':
        session.quit();
        exit(0);
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
      default:
        print('### unknown command: $command');
        break;
    }
    printPrompt();
  }

  Future run() async {
    print(BANNER);
    printPrompt();
    var inputLineStream = stdin.transform(new Utf8Decoder())
                               .transform(new LineSplitter());
    await for(var line in inputLineStream) {
      await handleLine(line);
    }
  }
}
