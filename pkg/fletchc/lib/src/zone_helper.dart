// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Helper functions for running code in a Zone.
library fletchc.zone_helper;

import 'dart:async';

Future runGuarded(
    Future f(),
    {void printLineOnStdout(line),
     void handleLateError(error, StackTrace stackTrace)}) {

  var printWrapper;
  if (printLineOnStdout != null) {
    printWrapper = (_1, _2, _3, String line) {
      printLineOnStdout(line);
    };
  }

  Completer completer = new Completer();

  handleUncaughtError(error, StackTrace stackTrace) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    } else if (handleLateError != null) {
      handleLateError(error, stackTrace);
    } else {
      // Delegate to parent.
      throw error;
    }
  }

  ZoneSpecification specification = new ZoneSpecification(print: printWrapper);

  runZoned(
      () => f().then(completer.complete),
      zoneSpecification: specification,
      onError: handleUncaughtError);

  return completer.future;
}
