// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library driver.show;

import 'dart:io' as io;
import 'logcat.dart' as logcat;
import 'help_text.dart' as help;

void _log(String message) => logcat.Logger.log(message);

const Map _handlers = const {
  "entrypoints" : _showEntrypoints,
  "entrypoint" : _showEntrypoints,
  "classes" : _showClasses,
  "class" : _showClasses,
  "diffs" : _showDiffs,
  "diff" : _showDiffs,
};

void show(List<String> args) {
  _log(args.join(','));
  
  if (args.length < 2) {
    print(help.SHOW_HELP_TEXT);
    io.exit(1);
  }
  
  var handler = _handlers[args[1]];
  if (handler != null) {
    handler(args);
  } else {
    _handleUnknownThing(args);
  }
}

void _showEntrypoints(List<String> args) {
  _log("Showing entrypoints");
  if (args.length == 2) {
    print ('''
Entrypoints:
  1.   main     (main.dart)
  2.   testRun  (tests/all_tests.dart)
''');
  } else if (args.length == 3) {
    print ('''
Entrypoint (main, main.dart - line 34):

  library app;

  /*
  *   Main entry point for application.
  */ 
  void main() {
     ...

  File last edited: 02 Feb 2015 14:24
  To execute type "fletch start main".
''');
  } else {
    print(help.SHOW_HELP_TEXT);
    io.exit(1);
  }
}

void _showClasses(List<String> args) {
  print("TODO");
}

void _showDiffs(List<String> args) {
  print("TODO");
}

void _handleUnknownThing(List<String> args) {
  _log("Invalid entity type");
  
  // For now just print help text. 
  // TODO(lukechurch): Replace this with did you mean suggestor 
  // from service.
  print(help.SHOW_HELP_TEXT);
  io.exit(1);
}
