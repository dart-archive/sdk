// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library driver.start;

import 'logcat.dart' as log;

void start(List<String> args) {
  String target = (args.length < 2) ? "main" : args[1];
  
  log.Logger.log("Starting execution of entry point: $target.");

  /**
   * TODO(lukechurch): Determine if it makes sense for this
   * output to appear in the same terminal used to issue the
   * fletch start command. We should know better soon after
   * a few other commands have been implemented.
   */ 
  print("Darts are now being thrown by the fletch VM.");
  print("...");
}