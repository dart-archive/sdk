// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver.developer;

import 'dart:async' show
    Future,
    Timer;

import 'dart:convert' show
    JSON;

import 'dart:io' show
    InternetAddress,
    Socket,
    SocketException;

import '../../commands.dart' show
    CommandCode,
    ProcessBacktrace,
    ProcessBacktraceRequest,
    ProcessRun,
    ProcessSpawnForMain,
    SessionEnd;

import 'session_manager.dart' show
    FletchVm,
    SessionState;

import 'driver_commands.dart' show
    handleSocketErrors;

import '../../commands.dart' show
    Debugging;

import '../verbs/infrastructure.dart' show
    Command,
    CommandSender,
    DiagnosticKind,
    FletchCompiler,
    FletchDelta,
    IncrementalCompiler,
    IsolateController,
    IsolatePool,
    Session,
    SharedTask,
    StreamIterator,
    fileUri,
    throwFatalError;

import '../../incremental/fletchc_incremental.dart' show
    IncrementalCompilationFailed;

import 'exit_codes.dart' as exit_codes;

import '../../fletch_system.dart' show
    FletchFunction,
    FletchSystem;

import '../../bytecodes.dart' show
    Bytecode,
    MethodEnd;

import '../diagnostic.dart' show
    throwInternalError;

import '../guess_configuration.dart' show
    executable,
    guessFletchVm;

import 'package:fletch_agent/agent_connection.dart' show
    AgentConnection,
    AgentException,
    VmData;
import 'package:fletch_agent/messages.dart' show
    AGENT_DEFAULT_PORT,
    MessageDecodeException;

Future<Socket> connect(
    String host,
    int port,
    DiagnosticKind kind,
    String socketDescription,
    SessionState state) async {
  // We are using .catchError rather than try/catch because we have seen
  // incorrect stack traces using the latter.
  Socket socket = await Socket.connect(host, port).catchError(
      (SocketException error) {
        String message = error.message;
        if (error.osError != null) {
          message = error.osError.message;
        }
        throwFatalError(kind, address: '$host:$port', message: message);
      }, test: (e) => e is SocketException);
  handleSocketErrors(socket, socketDescription, log: (String info) {
    state.log("Connected to TCP $socketDescription  $info");
  });
  return socket;
}

Future<Null> startAndAttachViaAgent(SessionState state) async {
  // TODO(wibling): need to make sure the agent is running.
  // TODO(wibling): integrate with the FletchVm class, e.g. have a
  // AgentFletchVm and LocalFletchVm that both share the same interface
  // where the former is interacting with the agent.
  assert(state.settings.deviceAddress != null);
  String host = state.settings.deviceAddress.host;
  int agentPort = state.settings.deviceAddress.port;
  Socket socket = await connect(
      host, agentPort, DiagnosticKind.socketAgentConnectError,
      "agentSocket", state);
  var agentConnection = new AgentConnection(socket);
  VmData vmData;
  try {
    vmData = await agentConnection.startVm();
  } on AgentException catch (error) {
    throwFatalError(
        DiagnosticKind.socketAgentReplyError,
        address: '${socket.remoteAddress.host}:${socket.remotePort}',
        message: error.message);
  } on MessageDecodeException catch (error) {
    throwFatalError(
        DiagnosticKind.socketAgentReplyError,
        address: '${socket.remoteAddress.host}:${socket.remotePort}',
        message: error.message);
  } finally {
    socket.close();
  }
  state.fletchAgentVmId = vmData.id;
  // The new fletch vm is running at the same host as the agent.
  await attachToVm(host, vmData.port, state);
  await state.session.disableVMStandardOutput();
}

Future<Null> startAndAttachDirectly(SessionState state) async {
  String fletchVmPath = guessFletchVm(null).toFilePath();
  state.fletchVm = await FletchVm.start(fletchVmPath);
  await attachToVm(state.fletchVm.host, state.fletchVm.port, state);
  await state.session.disableVMStandardOutput();
}

Future<Null> attachToVm(String host, int port, SessionState state) async {
  Socket socket = await connect(
      host, port, DiagnosticKind.socketVmConnectError, "vmSocket", state);

  Session session = new Session(socket, state.compiler, state.stdoutSink,
      state.stderrSink, null);

  // Enable debugging as a form of handshake.
  await session.runCommand(const Debugging());

  state.session = session;
}

Future<int> compile(Uri script, SessionState state) async {
  Uri firstScript = state.script;
  if (!const bool.fromEnvironment("fletchc.enable-incremental-compilation")) {
    state.resetCompiler();
  }
  List<FletchDelta> previousResults = state.compilationResults;
  IncrementalCompiler compiler = state.compiler;

  FletchDelta newResult;
  try {
    if (previousResults.isEmpty) {
      state.script = script;
      await compiler.compile(script);
      newResult = compiler.computeInitialDelta();
    } else {
      try {
        print("Compiling difference from $firstScript to $script");
        newResult = await compiler.compileUpdates(
            previousResults.last.system, <Uri, Uri>{firstScript: script},
            logTime: print, logVerbose: print);
      } on IncrementalCompilationFailed catch (error) {
        print(error);
        print("Attempting full compile...");
        state.resetCompiler();
        state.script = script;
        await compiler.compile(script);
        newResult = compiler.computeInitialDelta();
      }
    }
  } catch (error, stackTrace) {
    // Don't let a compiler crash bring down the session.
    print(error);
    if (stackTrace != null) {
      print(stackTrace);
    }
    return exit_codes.COMPILER_EXITCODE_CRASH;
  }
  state.addCompilationResult(newResult);

  state.log("Compiled '$script' to ${newResult.commands.length} commands");

  return 0;
}

SessionState createSessionState(String name, Settings settings) {
  if (settings == null) {
    settings = const Settings.empty();
  }
  List<String> compilerOptions = const bool.fromEnvironment("fletchc-verbose")
      ? <String>['--verbose'] : <String>[];
  compilerOptions.addAll(settings.options);
  Uri packageConfig = settings.packages;
  if (packageConfig == null) {
    packageConfig = executable.resolve("fletch-sdk.packages");
  }
  FletchCompiler compilerHelper = new FletchCompiler(
      options: compilerOptions, packageConfig: packageConfig,
      environment: settings.constants);

  return new SessionState(
      name, compilerHelper, compilerHelper.newIncrementalCompiler(), settings);
}

Future<int> run(SessionState state) async {
  List<FletchDelta> compilationResults = state.compilationResults;
  Session session = state.session;
  state.session = null;

  session.silent = true;

  for (FletchDelta delta in compilationResults) {
    await session.applyDelta(delta);
  }

  await session.enableDebugger();
  await session.spawnProcess();
  var command = await session.debugRun();

  int exitCode = exit_codes.COMPILER_EXITCODE_CRASH;
  if (command == null) {
    await session.kill();
    await session.shutdown();
    print(state.flushLog());
    throwInternalError("No command received from Fletch VM");
  }
  bool flushLog = true;
  Future printTrace() async {
    String list = await session.list();
    print(session.debugState.formatStackTrace());
    print(list);
  }
  try {
    switch (command.code) {
      case CommandCode.UncaughtException:
        state.log("Uncaught error");
        exitCode = exit_codes.DART_VM_EXITCODE_UNCAUGHT_EXCEPTION;
        await printTrace();
        // TODO(ahe): Need to continue to unwind stack.
        break;

      case CommandCode.ProcessCompileTimeError:
        state.log("Compile-time error");
        exitCode = exit_codes.DART_VM_EXITCODE_COMPILE_TIME_ERROR;
        await printTrace();
        // TODO(ahe): Continue to unwind stack?
        break;

      case CommandCode.ProcessTerminated:
        exitCode = 0;
        flushLog = false;
        break;

      case CommandCode.ConnectionError:
        state.log("Error on connection to Fletch VM: ${command.error}");
        exitCode = exit_codes.COMPILER_EXITCODE_CONNECTION_ERROR;
        break;

      default:
        throwInternalError("Unexpected result from Fletch VM: '$command'");
        break;
    }
  } finally {
    if (flushLog) {
      print(state.flushLog());
    }
    if (!session.terminated) {
      // TODO(ahe): Do not shut down the session.
      bool done = false;
      Timer timer = new Timer(const Duration(seconds: 5), () {
        if (!done) {
          print(state.flushLog());
          print("Timed out waiting for Fletch VM to shutdown; killing session");
          session.kill();
        }
      });
      await session.terminateSession();
      done = true;
      timer.cancel();
    }
  };

  return exitCode;
}

Future<int> export(SessionState state, Uri snapshot) async {
  List<FletchDelta> compilationResults = state.compilationResults;
  Session session = state.session;
  state.session = null;

  for (FletchDelta delta in compilationResults) {
    await session.applyDelta(delta);
  }

  await session.writeSnapshot(snapshot.toFilePath());
  await session.shutdown();

  return 0;
}

Future<int> compileAndAttachToVmThen(
    CommandSender commandSender,
    SessionState state,
    Uri script,
    Future<int> action()) async {
  bool startedVmDirectly = false;
  List<FletchDelta> compilationResults = state.compilationResults;
  Session session = state.session;
  if (compilationResults.isEmpty || script != null) {
    if (script == null) {
      throwFatalError(DiagnosticKind.noFileTarget);
    }
    int exitCode = await compile(script, state);
    if (exitCode != 0) return exitCode;
    compilationResults = state.compilationResults;
    assert(compilationResults != null);
  }

  if (session == null) {
    if (state.settings.deviceAddress != null) {
      await startAndAttachViaAgent(state);
      // TODO(wibling): read stdout from agent.
    } else {
      startedVmDirectly = true;
      await startAndAttachDirectly(state);
      state.fletchVm.stdoutLines.listen((String line) {
          commandSender.sendStdout("$line\n");
        });
      state.fletchVm.stderrLines.listen((String line) {
          commandSender.sendStderr("$line\n");
        });
    }
    session = state.session;
    assert(session != null);
  }

  state.attachCommandSender(commandSender);

  int exitCode = exit_codes.COMPILER_EXITCODE_CRASH;
  try {
    exitCode = await action();
  } catch (error, trace) {
    print(error);
    if (trace != null) {
      print(trace);
    }
  } finally {
    if (startedVmDirectly) {
      exitCode = await state.fletchVm.exitCode;
    }
    state.detachCommandSender();
  }
  return exitCode;
}

Future<IsolateController> allocateWorker(IsolatePool pool) async {
  IsolateController worker =
      new IsolateController(await pool.getIsolate(exitOnError: false));
  await worker.beginSession();
  return worker;
}

SharedTask combineTasks(SharedTask task1, SharedTask task2) {
  if (task1 == null) return task2;
  if (task2 == null) return task1;
  return new CombinedTask(task1, task2);
}

class CombinedTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final SharedTask task1;

  final SharedTask task2;

  const CombinedTask(this.task1, this.task2);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return invokeCombinedTasks(commandSender, commandIterator, task1, task2);
  }
}

Future<int> invokeCombinedTasks(
    CommandSender commandSender,
    StreamIterator<Command> commandIterator,
    SharedTask task1,
    SharedTask task2) async {
  await task1(commandSender, commandIterator);
  return task2(commandSender, commandIterator);
}

Address parseAddress(String address, {int defaultPort: 0}) {
  String host;
  int port;
  List<String> parts = address.split(":");
  if (parts.length == 1) {
    host = InternetAddress.LOOPBACK_IP_V4.address;
    port = int.parse(
        parts[0],
        onError: (String source) {
          host = source;
          return defaultPort;
        });
  } else {
    host = parts[0];
    port = int.parse(
        parts[1],
        onError: (String source) {
          throwFatalError(
              DiagnosticKind.expectedAPortNumber, userInput: source);
        });
  }
  return new Address(host, port);
}

class Address {
  final String host;
  final int port;

  const Address(this.host, this.port);

  String toString() => "Address($host, $port)";
}

/// See ../verbs/documentation.dart for a definition of this format.
Settings parseSettings(String jsonLikeData, Uri settingsUri) {
  String json = jsonLikeData.split("\n")
      .where((String line) => !line.trim().startsWith("//")).join("\n");
  var userSettings;
  try {
    userSettings = JSON.decode(json);
  } on FormatException catch (e) {
    throwFatalError(
        DiagnosticKind.settingsNotJson, uri: settingsUri, message: e.message);
  }
  if (userSettings is! Map) {
    throwFatalError(DiagnosticKind.settingsNotAMap, uri: settingsUri);
  }
  Uri packages;
  final List<String> options = <String>[];
  final Map<String, String> constants = <String, String>{};
  Address deviceAddress;
  userSettings.forEach((String key, value) {
    switch (key) {
      case "packages":
        if (value != null) {
          if (value is! String) {
            throwFatalError(
                DiagnosticKind.settingsPackagesNotAString, uri: settingsUri);
          }
          packages = fileUri(value, settingsUri);
        }
        break;

      case "options":
        if (value != null) {
          if (value is! List) {
            throwFatalError(
                DiagnosticKind.settingsOptionsNotAList, uri: settingsUri);
          }
          for (var option in value) {
            if (option is! String) {
              throwFatalError(
                  DiagnosticKind.settingsOptionNotAString, uri: settingsUri,
                  userInput: '$option');
            }
            if (option.startsWith("-D")) {
              throwFatalError(
                  DiagnosticKind.settingsCompileTimeConstantAsOption,
                  uri: settingsUri, userInput: '$option');
            }
            options.add(option);
          }
        }
        break;

      case "constants":
        if (value != null) {
          if (value is! Map) {
            throwFatalError(
                DiagnosticKind.settingsConstantsNotAMap, uri: settingsUri);
          }
          value.forEach((String key, value) {
            if (value == null) {
              // Ignore.
            } else if (value is bool || value is int || value is String) {
              constants[key] = '$value';
            } else {
              throwFatalError(
                  DiagnosticKind.settingsUnrecognizedConstantValue,
                  uri: settingsUri, userInput: key,
                  additionalUserInput: '$value');
            }
          });
        }
        break;

      case "device_address":
        if (value != null) {
          if (value is! String) {
            throwFatalError(
                DiagnosticKind.settingsDeviceAddressNotAString,
                uri: settingsUri, userInput: '$value');
          }
          deviceAddress =
              parseAddress(value, defaultPort: AGENT_DEFAULT_PORT);
        }
        break;

      default:
        throwFatalError(
            DiagnosticKind.settingsUnrecognizedKey, uri: settingsUri,
            userInput: key);
        break;
    }
  });
  return new Settings(packages, options, constants, deviceAddress);
}

class Settings {
  final Uri packages;

  final List<String> options;

  final Map<String, String> constants;

  final Address deviceAddress;

  const Settings(
      this.packages, this.options, this.constants, this.deviceAddress);

  const Settings.empty()
    : this(null, const <String>[], const <String, String>{}, null);

  String toString() {
    return "Settings("
        "packages: $packages, "
        "options: $options, "
        "constants: $constants, "
        "device_address: $deviceAddress)";
  }
}
