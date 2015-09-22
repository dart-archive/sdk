// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.compile_and_run_verb;

import 'infrastructure.dart';

import 'dart:async' show
    Completer,
    StreamController,
    StreamSubscription,
    Zone;

import 'dart:convert' show
    Utf8Decoder,
    LineSplitter;

import 'dart:io' show
    InternetAddress,
    Platform,
    Process,
    ServerSocket,
    Socket;

import 'package:compiler/src/util/uri_extras.dart' show
    relativize;

import '../../fletch_compiler.dart' show
    FletchCompiler,
    StringOrUri;

import '../../fletch_vm.dart' show
    FletchVm;

import '../../session.dart';

import '../driver/driver_commands.dart' show
    DriverCommand,
    handleSocketErrors,
    makeErrorHandler;

import '../driver/session_manager.dart' show
    BufferingOutputSink;

import '../driver/options.dart' show
    Options;

import '../driver/exit_codes.dart' show
    DART_VM_EXITCODE_COMPILE_TIME_ERROR;

import 'documentation.dart' show
    compileAndRunDocumentation;

const Verb compileAndRunVerb =
    const Verb(
        compileAndRun, compileAndRunDocumentation,
        allowsTrailing: true,
        supportedTargets: const <TargetKind>[TargetKind.FILE]);

Future<int> compileAndRun(
    AnalyzedSentence sentence,
    VerbContext context) async {
  Options options = Options.parse(sentence.arguments);

  if (!options.defines.isEmpty) {
    print("Unsupported options: ${options.defines.join(' ')}");
    return DART_VM_EXITCODE_COMPILE_TIME_ERROR;
  }

  if (options.script == null) {
    throwFatalError(DiagnosticKind.noFileTarget);
  }

  CompileAndRunTask task = new CompileAndRunTask(
      '${sentence.programName}-vm', options, sentence.base);

  // Create a temporary worker/session.
  IsolateController worker =
      new IsolateController(await context.pool.getIsolate(exitOnError: false));
  await worker.beginSession();
  context.client.log.note("After beginSession.");

  // This is asynchronous, but we don't await the result so we can respond to
  // other requests.
  worker.performTask(task, context.client, endSession: true);

  return null;
}

class CompileAndRunTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final String fletchVm;

  final Options options;

  final Uri base;

  const CompileAndRunTask(this.fletchVm, this.options, this.base);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return compileAndRunTask(
        fletchVm, options, base, commandSender, commandIterator);
  }
}

Future<int> compileAndRunTask(
    String fletchVm,
    Options options,
    Uri base,
    CommandSender commandSender,
    StreamIterator<Command> commandIterator) async {
  List<String> compilerOptions = const bool.fromEnvironment("fletchc-verbose")
      ? <String>['--verbose'] : <String>[];
  FletchCompiler compilerHelper = new FletchCompiler(
      currentDirectory: base,
      options: compilerOptions,
      packageRoot: options.packageRootPath,
      script: options.script,
      fletchVm: fletchVm);
  IncrementalCompiler compiler =
      compilerHelper.newIncrementalCompiler(options: compilerOptions);
  await compiler.compile(compilerHelper.script);
  FletchDelta fletchDelta = compiler.computeInitialDelta();

  Process vmProcess;
  int exitCode = 0;
  Socket vmSocket;
  StreamController stdinController = new StreamController();
  List futures = [];
  trackSubscription(StreamSubscription subscription, String name) {
    futures.add(doneFuture(handleSubscriptionErrors(subscription, name)));
  }
  String host;
  int port;
  if (options.attachArgument != null) {
    var address = options.attachArgument.split(":");
    host = address[0];
    port = int.parse(address[1]);
    print("Connecting to $host:$port");
  } else {
    Uri vmUri = compilerHelper.fletchVm;
    String vmPath = vmUri.toFilePath();
    if (compilerHelper.verbose) {
      print("Running '$vmPath'");
    }
    FletchVm vm =
        await FletchVm.start(vmPath, environment: fletchVmEnvironment());
    futures.add(vm.exitCode.then((int value) {
      exitCode = value;
      if (exitCode != 0) {
        String relativeVmPath = relativize(base, vmUri, false);
        print("Non-zero exit code from '$relativeVmPath' ($exitCode).");
      }
    }));
    trackSubscription(
        vm.stdoutLines.listen(
            (line) => commandSender.sendStdout('$line\n')), "vm stdout");
    trackSubscription(
        vm.stderrLines.listen(
            (line) => commandSender.sendStderr('$line\n')), "vm stderr");
    host = vm.host;
    port = vm.port;
    vmProcess = vm.process;
  }
  vmSocket = handleSocketErrors(await Socket.connect(host, port), "vmSocket");

  readCommands(commandIterator, vmProcess, stdinController);

  // Notify controlling isolate (driver_main) that the event loop
  // [readCommands] has been started, and commands like DriverCommand.Signal
  // will be honored.
  commandSender.sendEventLoopStarted();

  BufferingOutputSink stdoutSink = new BufferingOutputSink();
  BufferingOutputSink stderrSink = new BufferingOutputSink();
  stdoutSink.attachCommandSender((d) => commandSender.sendStdoutBytes(d));
  stderrSink.attachCommandSender((d) => commandSender.sendStderrBytes(d));

  var inputStream = stdinController.stream
      .transform(new Utf8Decoder())
      .transform(new LineSplitter());

  // Apply all commands the compiler gave us & shut down.
  var session = new Session(vmSocket,
                            compiler,
                            stdoutSink,
                            stderrSink,
                            vmProcess != null ? vmProcess.exitCode : null);

  // If we started a vmProcess ourselves, we disable the normal
  // VM standard output as we already get it via the wire protocol.
  if (vmProcess != null) await session.disableVMStandardOutput();
  await session.applyDelta(fletchDelta);

  if (options.snapshotPath != null) {
    Uri snapshotUri = fileUri(options.snapshotPath, base);
    await session.writeSnapshot(snapshotUri.toFilePath());
  } else if (options.testDebugger) {
    await session.testDebugger(options.testDebuggerCommands);
  } else {
    await session.debug(inputStream);
  }
  await session.shutdown();

  if (vmProcess != null) {
    futures.add(vmProcess.stdin.close());
  }

  await Future.wait(futures);

  return exitCode;
}

Future<Null> readCommands(
    StreamIterator<Command> commandIterator,
    Process vmProcess,
    StreamController stdinController) async {
  while (await commandIterator.moveNext()) {
    Command command = commandIterator.current;
    switch (command.code) {
      case DriverCommand.Stdin:
        if (command.data.length == 0) {
          await stdinController.close();
        } else {
          stdinController.add(command.data);
        }
        break;

      case DriverCommand.Signal:
        int signalNumber = command.data;
        Process.runSync("kill", ["-$signalNumber", "${vmProcess.pid}"]);
        break;

      default:
        Zone.ROOT.print("Unexpected command from client: $command");
    }
  }
}

Map<String, String> fletchVmEnvironment() {
  var environment = new Map<String, String>.from(Platform.environment);

  var asanOptions = environment['ASAN_OPTIONS'];
  if (asanOptions != null && asanOptions.length > 0) {
    asanOptions = '$asanOptions,abort_on_error=1';
  } else {
    asanOptions = 'abort_on_error=1';
  }
  environment['ASAN_OPTIONS'] = asanOptions;

  return environment;
}

StreamSubscription handleSubscriptionErrors(
    StreamSubscription subscription,
    String name) {
  String info = "$name subscription";
  Zone.ROOT.print(info);
  return subscription
      ..onError(makeErrorHandler(info));
}

Future doneFuture(StreamSubscription subscription) {
  var completer = new Completer();
  subscription.onDone(completer.complete);
  return completer.future;
}
