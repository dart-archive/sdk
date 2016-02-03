// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.please_report_crash;

import 'guess_configuration.dart' show
    dartinoVersion;

bool crashReportRequested = false;

final String requestBugReportOnCompilerCrashMessage = """
The Dartino compiler is broken.

When compiling the above element, the compiler crashed. It is not
possible to tell if this is caused by a problem in your program or
not. Regardless, the compiler should not crash.

The Dartino team would greatly appreciate if you would take a moment to
report this problem at https://github.com/dartino/sdk/issues/new

Please include the following information:

* the name and version of your operating system

* the Dartino SDK version ($dartinoVersion)

* the entire message you see here (including the full stack trace
  below as well as the source location above)
""";

final String requestBugReportOnOtherCrashMessage = """
The Dartino program is broken and has crashed.

The Dartino team would greatly appreciate if you would take a moment to
report this problem at https://github.com/dartino/sdk/issues/new

Please include the following information:

* the name and version of your operating system

* the Dartino SDK version ($dartinoVersion)

* the entire message you see here (including the full stack trace below)
""";

void pleaseReportCrash(error, StackTrace trace) {
  String formattedError = stringifyError(error, trace);
  if (!crashReportRequested) {
    crashReportRequested = true;
    print("$requestBugReportOnOtherCrashMessage$formattedError");
  } else {
    print(formattedError);
  }
}

String stringifyError(error, StackTrace stackTrace) {
  String safeToString(object) {
    try {
      return '$object';
    } catch (e) {
      return Error.safeToString(object);
    }
  }
  StringBuffer buffer = new StringBuffer();
  buffer.writeln(safeToString(error));
  if (stackTrace != null) {
    buffer.writeln(safeToString(stackTrace));
  } else {
    buffer.writeln("No stack trace.");
  }
  return '$buffer';
}
