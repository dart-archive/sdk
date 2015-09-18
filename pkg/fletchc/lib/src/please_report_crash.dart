// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.please_report_crash;

bool crashReportRequested = false;

// TODO(ahe): Include build ID.
const String requestBugReportOnCompilerCrashMessage = """
The Fletch compiler is broken.

When compiling the above element, the compiler crashed. It is not
possible to tell if this is caused by a problem in your program or
not. Regardless, the compiler should not crash.

The Fletch team would greatly appreciate if you would take a moment to
report this problem at https://github.com/dart-lang/fletch/issues/new

Please include the following information:

* the name and version of your operating system

* the entire message you see here (including the full stack trace
  below as well as the source location above)
""";

// TODO(ahe): Include build ID.
const String requestBugReportOnOtherCrashMessage = """
The Fletch program is broken and has crashed.

The Fletch team would greatly appreciate if you would take a moment to
report this problem at https://github.com/dart-lang/fletch/issues/new

Please include the following information:

* the name and version of your operating system

* the entire message you see here (including the full stack trace below)
""";
