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
Entrypoint  (main, main.dart - line 34):

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
  _log("Showing classes");
  if (args.length == 2) {
    print('''
Classes (showing 4/4):
  1.   ProgramImpl          (main.dart)
  2.   ColorProp            (lib/view/display.dart)
  3.   Display              (lib/view/display.dart)
  4.   OldStuff             (lib/view/display.dart)
''');
  } else if (args.length == 3) {
    print('''
Classes containing 'color':
  ColorProp                 (lib/view/display.dart, line 53)

Constructors:
  ColorProp(double red, double green, double blue)
  ColorProp.black()
  ColorProp.white()
  ColorProp.fromHSV(double h, double s, double v)

Methods:
  HSVColor toHSV()

Properties:
  double red
  double green
  double blue
''');
  } else {
    print(help.SHOW_HELP_TEXT);
    io.exit(1);
  }
}

void _showDiffs(List<String> args) {
  _log("Showing diffs");
  if (args.length == 2) {
    print ('''
Diffs:
  1.   main.dart/main                         (Changed 3 lines)
  2.   lib/view/display.dart/colorProp._red   (Changed 1 line)
  3.   lib/view/display.dart/oldStuff         (Deleted 32 lines)
''');
  } else if (args.length == 3) {
    print ('''
Diff        (colorProp._red, lib/view/display.dart - line 23):

1c1
< double _red = 0.233;
---
> double _red = 0.8;

  Changes made: 12 Feb 2015 14:24
  To apply type "fletch apply colorProp._red" or
                "fletch apply *"
''');
  } else {
    print(help.SHOW_HELP_TEXT);
    io.exit(1);
  }
}

void _handleUnknownThing(List<String> args) {
  _log("Invalid entity type");
  
  // For now just print help text. 
  // TODO(lukechurch): Replace this with did you mean suggestor 
  // from service.
  print(help.SHOW_HELP_TEXT);
  io.exit(1);
}
