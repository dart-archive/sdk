// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver.help_verb;

import 'dart:async' show
    Future;

import 'verbs.dart' show
    Verb,
    commonVerbs,
    uncommonVerbs;

const Verb helpVerb = const Verb(help, documentation);

const String documentation = """
   help      Display this information.
             Use 'fletch help all' for a list of all actions.
""";

Future<int> help(
    _a,
    List<String> arguments,
    _b,
    _c,
    {packageRoot: "package/"}) async {
  int exitCode = 0;
  bool showAllVerbs = arguments.length == 1 && arguments.single == "all";
  if (!showAllVerbs && !arguments.isEmpty) {
    print("Unknown arguments to help: ${arguments.join(' ')}");
    exitCode = 1;
  }
  bool isFirst = true;
  printVerb(String name, Verb verb) {
    if (!isFirst) print("");
    isFirst = false;
    print(verb.documentation.trimRight());
  }
  commonVerbs.forEach(printVerb);
  if (showAllVerbs) {
    uncommonVerbs.forEach(printVerb);
  }
  return exitCode;
}
