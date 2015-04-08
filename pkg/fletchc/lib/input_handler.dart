// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of fletch.session;

const String BANNER = """
Starting session.

Commands:
  'r'/'run'                             run main
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
      case 'q':
      case 'quit':
        session.quit();
        exit(0);
        break;
      case 'r':
      case 'run':
        await session.debugRun();
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
