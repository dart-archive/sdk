// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io';
import 'fletch_help_text.dart';

main(args) {
  if (args.length == 0) {
    help(args);
    return;
  }
  String command = args[0];

  final commandHandlers = {
     "help" : help,
     "show" : show,
     "init" : init,
  };

  if (!commandHandlers.containsKey(command)) {
    failAndHelp(args, "Unrecognized command: ${args[0]}");
  } else {
    commandHandlers[command](args);
  }
}

void help(args) {
  if (args.length < 2) {
    print(HELP_TEXT);
    return;
  }

  switch(args[1]) {
    case "init":
      print(INIT_HELP_TEXT);
      break;

    case "show":
      print(SHOW_HELP_TEXT);
      break;

    default:
      failAndHelp(args, "Unrecognized command: ${args[1]}");
  }
}

void failAndHelp(args, message) {
  print(message);
  print(FAIL_HELP_TEXT);
  exit(1);
}

void init(args) {
  print("CREATE INIT IMPL");
}

void show(args) {
  print("SHOW COMMAND IMPL");
}
