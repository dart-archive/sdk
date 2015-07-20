// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.compile_verb;

import 'dart:async' show
    Future,
    StreamIterator;

import 'verbs.dart' show
    PrepositionKind,
    Sentence,
    TargetKind,
    Verb,
    VerbContext;

import '../driver/sentence_parser.dart' show
    Preposition,
    NamedTarget;

import '../../fletch_system.dart' show
    FletchDelta;

import '../../compiler.dart' show
    FletchCompiler;

import '../diagnostic.dart' show
    DiagnosticKind,
    throwFatalError;

import '../driver/driver_commands.dart' show
    Command,
    CommandSender;

const Verb compileVerb =
    const Verb(compile, documentation, requiresSession: true);

const String documentation = """
   compile file FILE
               Compile file named FILE.
""";

Future<int> compile(Sentence sentence, VerbContext context) {
  if (sentence.target == null) {
    throwFatalError(DiagnosticKind.noFileTarget);
  }
  if (sentence.target.kind != TargetKind.FILE) {
    throwFatalError(
        DiagnosticKind.compileRequiresFileTarget, target: sentence.target);
  }
  NamedTarget target = sentence.target;
  String script = target.name;

  // This is asynchronous, but we don't await the result so we can respond to
  // other requests.
  context.performTaskInWorker(new CompileTask(script));

  return new Future<int>.value(null);
}

class CompileTask {
  // Keep this class simple, it is transported across an isolate port.

  final String script;

  const CompileTask(this.script);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return compileTask(script, commandSender, commandIterator);
  }
}

Future<int> compileTask(
    String script,
    CommandSender commandSender,
    StreamIterator<Command> commandIterator) async {
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
