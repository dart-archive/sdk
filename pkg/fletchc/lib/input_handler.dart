// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of fletch.session;

const String BANNER = """
Starting session.

Commands:
  'r'/'run'                             run main
  'b <method name> <bytecode index>'    set breakpoint
  'd <breakpoint id>'                   delete breakpoint
  'lb'                                  list breakpoints
  's'                                   step bytecode
  'so'                                  step over
  'c'                                   continue execution
  'bt'                                  backtrace
  'bt <n>'                              backtrace only expanding frame n
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
      case "b":
        var method =
            (commandComponents.length > 1) ? commandComponents[1] : "main";
        var bci =
            (commandComponents.length > 2) ? commandComponents[2] : "0";
        try {
          bci = int.parse(bci);
        } catch(e) {
          print('### invalid bytecode index: $bci');
          break;
        }
        await session.setBreakpoint(methodName: method, bytecodeIndex: bci);
        break;
      case 'bt':
        var frame =
            (commandComponents.length > 1) ? commandComponents[1] : "-1";
        try {
          frame = int.parse(frame);
        } catch(e) {
          print('### invalid frame number: $frame');
          break;
        }
        await session.backtrace(frame);
        break;
      case "c":
        await session.cont();
        break;
      case "d":
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
      case 'q':
      case 'quit':
        session.quit();
        exit(0);
        break;
      case 'r':
      case 'run':
        await session.debugRun();
        break;
      case "s":
        await session.step();
        break;
      case "so":
        await session.stepOver();
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
