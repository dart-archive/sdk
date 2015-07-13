// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.compile_verb;

import 'dart:async' show
    Future;

import 'verbs.dart' show
    PrepositionKind,
    Sentence,
    TargetKind,
    Verb;

import '../driver/sentence_parser.dart' show
    Preposition,
    NamedTarget;

import '../../fletch_system.dart' show
    FletchDelta;

import '../../compiler.dart' show
    FletchCompiler;

const Verb compileVerb =
    const Verb(compile, documentation, requiresSession: true);

const String documentation = """
   compile file FILE
               Compile file named FILE.
""";

Future<int> compile(Sentence sentence, _) async {
  if (sentence.target == null) {
    throw "No file name provided.";
  }
  if (sentence.target.kind != TargetKind.FILE) {
    // TODO(ahe): Be more explicit about what is wrong with the target.
    throw "Can only compile files, not ${sentence.target}.";
  }
  NamedTarget target = sentence.target;
  String script = target.name;

  // TODO(ahe): Allow user to specify dart2js options.
  List<String> compilerOptions = const bool.fromEnvironment("fletchc-verbose")
      ? <String>['--verbose'] : <String>[];
  FletchCompiler compiler =
      new FletchCompiler(
          options: compilerOptions, script: script,
          packageRoot: null /* TODO(ahe): Provide package root. */);

  FletchDelta fletchDelta = await compiler.run();

  print("Compiled '$script' to ${fletchDelta.commands.length} commands.");

  return 0;
}
