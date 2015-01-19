// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io';

main(args) {
  if (args.length == 0) {
    help(args);
    return;
  }
  String command = args[0];

  final commandHandlers = {
     "help" : help,
     "show" : show,
     "init" : init
  };

  if (!commandHandlers.containsKey(command))
    failAndHelp(args, "Unrecognized command: ${args[0]}");
  else
    commandHandlers[command](args);
}

void help(args) {
  if (args.length < 2) {
    print(r'''
Usage: fletch command

Manages, edits, runs and closes Fletch projects and programs.

Common commands:
  fletch help <command> - show detailed help for a command.
  fletch init <path>    - create/connect to a Fletch project.
  fletch show <thing>   - show details about the things in the project.
''');
    return;
  }

  switch(args[1]) {
    case "init":
      print(r'''
Usage: fletch init <path>

Creates a Fletch project in the specified path if one doesn't already exist.
Then connects to that projects, ready to receive further commands.
''');
      break;

    case "show":
      print(r'''
Usage fletch show <thing> [name]

Shows information about things in the project. If no name is given all the
things are listed, otherwise detail about the specific thing is listed.

Supported things:
  entrypoint[s]
  class[es]
  method[s]
  poi
''');
      break;

    default:
      failAndHelp(args, "Unrecognized command: ${args[1]}");
  }
}

void failAndHelp(args, message) {
  print(message);
  print(r'''

Usage: fletch command

Try 'fletch help' for a list of the commands available.

''');
  exit(1);
}

void init(args) {
  print("CREATE INIT IMPL");
}

void show(args) {
  print("SHOW COMMAND IMPL");
}
