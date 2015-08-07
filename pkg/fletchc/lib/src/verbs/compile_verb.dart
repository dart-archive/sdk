// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.compile_verb;

import 'infrastructure.dart';

import '../../incremental/fletchc_incremental.dart' show
    IncrementalCompilationFailed;

import '../driver/exit_codes.dart' show
    COMPILER_EXITCODE_CRASH;

import 'documentation.dart' show
    compileDocumentation;

const Verb compileVerb = const Verb(
    compile, compileDocumentation, requiresSession: true,
    requiresTarget: true, supportsTarget: TargetKind.FILE);

Future<int> compile(AnalyzedSentence sentence, VerbContext context) {
  String script = sentence.targetName;

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

Uri resolveUserInputFile(String script) {
  // TODO(ahe): Get base from current directory of C++ client. Also, this
  // method should probably be moved to infrastructure.dart or something.
  return Uri.base.resolve(script);
}

Future<int> compileTask(String script) async {
  Uri firstScript = SessionState.current.script;
  List<FletchDelta> previousResults = SessionState.current.compilationResults;
  Uri newScript = resolveUserInputFile(script);

  IncrementalCompiler compiler = SessionState.current.compiler;

  FletchDelta newResult;
  try {
    if (previousResults.isEmpty) {
      SessionState.current.script = newScript;
      await compiler.compile(newScript);
      newResult = compiler.computeInitialDelta();
    } else {
      try {
        print("Compiling difference from $firstScript to $newScript");
        newResult = await compiler.compileUpdates(
            previousResults.last.system, <Uri, Uri>{firstScript: newScript},
            logTime: print, logVerbose: print);
      } on IncrementalCompilationFailed catch (error) {
        print(error);
        print("Attempting full compile...");
        SessionState.current.resetCompiler();
        SessionState.current.script = newScript;
        await compiler.compile(newScript);
        newResult = compiler.computeInitialDelta();
      }
    }
  } catch (error, stackTrace) {
    // Don't let a compiler crash bring down the session.
    print(error);
    if (stackTrace != null) {
      print(stackTrace);
    }
    return COMPILER_EXITCODE_CRASH;
  }
  SessionState.current.addCompilationResult(newResult);

  print("Compiled '$script' to ${newResult.commands.length} commands\n\n\n");

  return 0;
}
