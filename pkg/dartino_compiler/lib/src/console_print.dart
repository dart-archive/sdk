// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// TODO(ahe): We should have a more general logging facility.
// We currently print directly to stdout (via Zone.ROOT.print) and assume that
// stdout of this process is piped to a log file.
library dartino_compiler.console_print;

import 'dart:async' show
    Zone;

typedef void OneArgVoid(line);

/// Prints a message to the console of the persistent process. This should be
/// used for logging.
///
/// For most debug-by-print situations, [print] is almost always a better
/// choice as it is intercepted and directed to the C++ client.
///
/// Only change this in tests.
OneArgVoid printToConsole = Zone.ROOT.print;
