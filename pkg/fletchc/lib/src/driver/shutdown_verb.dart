// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver.shutdown_verb;

import 'dart:io' show
    exit;

import 'dart:async' show
    Future;

import 'verbs.dart' show
    Verb;

import 'driver_main.dart' show
    gracefulShutdown;

const Verb shutdownVerb = const Verb(shutdown, documentation);

const String documentation = """
   shutdown      Terminate the background fletch compiler process.
""";

Future<int> shutdown(
    _a,
    List<String> arguments,
    _b,
    _c,
    {packageRoot: "package/"}) {
  gracefulShutdown();
  return new Future.value(0);
}
