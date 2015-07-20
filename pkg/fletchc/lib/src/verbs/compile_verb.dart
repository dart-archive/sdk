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
    SharedTask,
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

import '../driver/session_manager.dart' show
    SessionState;

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

class CompileTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final String script;

  const CompileTask(this.script);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return compileTask(script);
  }
}

Future<int> compileTask(String script) async {
  // TODO(ahe): Allow user to specify dart2js options.
  List<String> compilerOptions = const bool.fromEnvironment("fletchc-verbose")
      ? <String>['--verbose'] : <String>[];
  FletchCompiler compiler =
      new FletchCompiler(
          options: compilerOptions, script: script,
          packageRoot: null /* TODO(ahe): Provide package root. */);

  FletchDelta result = await compiler.run();
  SessionState.current.compilationResult = result;

  print("Compiled '$script' to ${result.commands.length} commands.");

  return 0;
}
