// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver.developer;

import 'dart:async' show
    Future,
    Timer;

import 'dart:convert' show
    JSON,
    JsonEncoder,
    UTF8;

import 'dart:io' show
    File,
    InternetAddress,
    Process,
    Socket,
    SocketException;

import 'package:sdk_library_metadata/libraries.dart' show
    Category;

import 'package:fletch_agent/agent_connection.dart' show
    AgentConnection,
    AgentException,
    VmData;

import 'package:fletch_agent/messages.dart' show
    AGENT_DEFAULT_PORT,
    MessageDecodeException;

import '../../commands.dart' show
    CommandCode,
    HandShakeResult,
    ProcessBacktrace,
    ProcessBacktraceRequest,
    ProcessRun,
    ProcessSpawnForMain,
    SessionEnd;

import 'session_manager.dart' show
    FletchVm,
    SessionState;

import 'driver_commands.dart' show
    DriverCommand,
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
    throwFatalError;

import '../../incremental/fletchc_incremental.dart' show
    IncrementalCompilationFailed;

import '../../fletch_compiler.dart' show fletchDeviceType;

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
    fletchVersion,
    guessFletchVm;

import '../device_type.dart' show
    DeviceType,
    parseDeviceType,
    unParseDeviceType;

import '../please_report_crash.dart' show
    pleaseReportCrash;

Uri configFileUri;

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

Future<AgentConnection> connectToAgent(SessionState state) async {
  // TODO(wibling): need to make sure the agent is running.
  assert(state.settings.deviceAddress != null);
  String host = state.settings.deviceAddress.host;
  int agentPort = state.settings.deviceAddress.port;
  Socket socket = await connect(
      host, agentPort, DiagnosticKind.socketAgentConnectError,
      "agentSocket", state);
  return new AgentConnection(socket);
}

void disconnectFromAgent(AgentConnection connection) {
  assert(connection.socket != null);
  connection.socket.close();
}

Future<Null> startAndAttachViaAgent(SessionState state) async {
  // TODO(wibling): integrate with the FletchVm class, e.g. have a
  // AgentFletchVm and LocalFletchVm that both share the same interface
  // where the former is interacting with the agent.
  AgentConnection connection = await connectToAgent(state);
  VmData vmData;
  try {
    vmData = await connection.startVm();
  } on AgentException catch (error) {
    throwFatalError(
        DiagnosticKind.socketAgentReplyError,
        address: '${connection.socket.remoteAddress.host}:'
            '${connection.socket.remotePort}',
        message: error.message);
  } on MessageDecodeException catch (error) {
    throwFatalError(
        DiagnosticKind.socketAgentReplyError,
        address: '${connection.socket.remoteAddress.host}:'
            '${connection.socket.remotePort}',
        message: error.message);
  } finally {
    disconnectFromAgent(connection);
  }
  state.fletchAgentVmId = vmData.id;
  String host = state.settings.deviceAddress.host;
  await attachToVm(host, vmData.port, state);
  await state.session.disableVMStandardOutput();
}

Future<Null> startAndAttachDirectly(SessionState state) async {
  String fletchVmPath = state.compilerHelper.fletchVm.toFilePath();
  state.fletchVm = await FletchVm.start(fletchVmPath);
  await attachToVm(state.fletchVm.host, state.fletchVm.port, state);
  await state.session.disableVMStandardOutput();
}

Future<Null> attachToVm(String host, int port, SessionState state) async {
  Socket socket = await connect(
      host, port, DiagnosticKind.socketVmConnectError, "vmSocket", state);

  Session session = new Session(socket, state.compiler, state.stdoutSink,
      state.stderrSink, null);

  // Perform handshake with VM which validates that VM and compiler
  // have the same versions.
  HandShakeResult handShakeResult = await session.handShake(fletchVersion);
  if (handShakeResult == null) {
    throwFatalError(DiagnosticKind.handShakeFailed, address: '$host:$port');
  }
  if (!handShakeResult.success) {
    throwFatalError(DiagnosticKind.versionMismatch,
                    address: '$host:$port',
                    userInput: fletchVersion,
                    additionalUserInput: handShakeResult.version);
  }

  // Enable debugging to be able to communicate with VM when there
  // are errors.
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
    pleaseReportCrash(error, stackTrace);
    return exit_codes.COMPILER_EXITCODE_CRASH;
  }
  state.addCompilationResult(newResult);

  state.log("Compiled '$script' to ${newResult.commands.length} commands");

  return 0;
}

Future<Settings> readSettings(Uri uri) async {
  if (await new File.fromUri(uri).exists()) {
    String jsonLikeData = await new File.fromUri(uri).readAsString();
    return parseSettings(jsonLikeData, uri);
  } else {
    return null;
  }
}

Future<Settings> createSettings(
    String sessionName,
    Uri uri,
    Uri base,
    Uri configFileUri,
    CommandSender commandSender,
    StreamIterator<Command> commandIterator) async {
  bool userProvidedSettings = uri != null;
  if (!userProvidedSettings) {
    Uri implicitSettingsUri = base.resolve('.fletch-settings');
    if (await new File.fromUri(implicitSettingsUri).exists()) {
      uri = implicitSettingsUri;
    }
  }

  Settings settings = new Settings.empty();
  if (uri != null) {
    String jsonLikeData = await new File.fromUri(uri).readAsString();
    settings = parseSettings(jsonLikeData, uri);
  }
  if (userProvidedSettings) return settings;

  Uri packagesUri;
  Address address;
  switch (sessionName) {
    case "remote":
      uri = configFileUri.resolve("remote.fletch-settings");
      Settings remoteSettings = await readSettings(uri);
      if (remoteSettings != null) return remoteSettings;
      packagesUri = executable.resolve("fletch-sdk.packages");
      address = await readAddressFromUser(commandSender, commandIterator);
      if (address == null) {
        // Assume user aborted data entry.
        return settings;
      }
      break;

    case "local":
      uri = configFileUri.resolve("local.fletch-settings");
      Settings localSettings = await readSettings(uri);
      if (localSettings != null) return localSettings;
      // TODO(ahe): Use mock packages here.
      packagesUri = executable.resolve("fletch-sdk.packages");
      break;

    default:
      return settings;
  }

  if (!await new File.fromUri(packagesUri).exists()) {
    packagesUri = null;
  }
  settings = settings.copyWith(packages: packagesUri, deviceAddress: address);
  print("Created settings file '$uri'");
  await new File.fromUri(uri).writeAsString(
      "${const JsonEncoder.withIndent('  ').convert(settings)}\n");
  return settings;
}

Future<Address> readAddressFromUser(
    CommandSender commandSender,
    StreamIterator<Command> commandIterator) async {
  commandSender.sendEventLoopStarted();
  commandSender.sendStdout("Please enter IP address of remote device: ");
  while (await commandIterator.moveNext()) {
    Command command = commandIterator.current;
    switch (command.code) {
      case DriverCommand.Stdin:
        if (command.data.length == 0) {
          // TODO(ahe): It may be safe to return null here, but we need to
          // check how this interacts with the debugger's InputHandler.
          throwInternalError("Unexpected end of input");
        }
        // TODO(ahe): This assumes that the user's input arrives as one
        // message. It is relatively safe to assume this for a normal terminal
        // session because we use canonical input processing (Unix line
        // buffering), but it doesn't work in general. So we should fix that.
        String line = UTF8.decode(command.data).trim();
        return parseAddress(line, defaultPort: AGENT_DEFAULT_PORT);

      case DriverCommand.Signal:
        // Send an empty line as the user didn't hit enter.
        commandSender.sendStdout("\n");
        // Assume user aborted data entry.
        return null;

      default:
        throwInternalError("Unexpected ${command.code}");
        return null;
    }
  }
}

SessionState createSessionState(
    String name,
    Settings settings,
    {Uri libraryRoot,
     Uri patchRoot,
     Uri fletchVm,
     Uri nativesJson}) {
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

  DeviceType deviceType = settings.deviceType ??
      parseDeviceType(fletchDeviceType);

  List<Category> categories = (deviceType == DeviceType.embedded)
      ? <Category>[Category.embedded]
      : null;

  FletchCompiler compilerHelper = new FletchCompiler(
      options: compilerOptions,
      packageConfig: packageConfig,
      environment: settings.constants,
      categories: categories,
      libraryRoot: libraryRoot,
      patchRoot: patchRoot,
      fletchVm: fletchVm,
      nativesJson: nativesJson);

  return new SessionState(
      name, compilerHelper, compilerHelper.newIncrementalCompiler(), settings);
}

Future<int> run(SessionState state, {String testDebuggerCommands}) async {
  List<FletchDelta> compilationResults = state.compilationResults;
  Session session = state.session;
  state.session = null;

  session.silent = true;

  for (FletchDelta delta in compilationResults) {
    await session.applyDelta(delta);
  }

  if (testDebuggerCommands != null) {
    session.silent = false;
    await session.testDebugger(testDebuggerCommands);
    await session.shutdown();
    return 0;
  }

  await session.enableDebugger();
  await session.spawnProcess();
  var command = await session.debugRun();

  int exitCode = exit_codes.COMPILER_EXITCODE_CRASH;
  if (command == null) {
    await session.kill();
    await session.shutdown();
    throwInternalError("No command received from Fletch VM");
  }

  Future printException() async {
    String exception = await session.exceptionAsString();
    print(exception);
  }

  Future printTrace() async {
    String list = await session.list();
    String stackTrace = session.debugState.formatStackTrace();
    if (!stackTrace.isEmpty) print(stackTrace);
    if (!stackTrace.isEmpty) print(list);
  }

  try {
    switch (command.code) {
      case CommandCode.UncaughtException:
        state.log("Uncaught error");
        exitCode = exit_codes.DART_VM_EXITCODE_UNCAUGHT_EXCEPTION;
        await printException();
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
    if (!session.terminated) {
      // TODO(ahe): Do not shut down the session.
      bool done = false;
      Timer timer = new Timer(const Duration(seconds: 5), () {
        if (!done) {
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

// TODO(wibling): refactor the debug_verb to not set up its own event handler
// and get rid of this deprecated compileAndAttachToVmThenDeprecated method.
Future<int> compileAndAttachToVmThenDeprecated(
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

Future<int> compileAndAttachToVmThen(
    CommandSender commandSender,
    StreamIterator<Command> commandIterator,
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

  // Setup a handler for incoming commands while the current task is executing.
  readCommands(commandIterator, state);

  // Notify controlling isolate (driver_main) that the event loop
  // [readCommands] has been started, and commands like DriverCommand.Signal
  // will be honored.
  commandSender.sendEventLoopStarted();

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

Future<Null> readCommands(
    StreamIterator<Command> commandIterator, SessionState state) async {
  while (await commandIterator.moveNext()) {
    Command command = commandIterator.current;
    switch (command.code) {
      case DriverCommand.Signal:
        int signalNumber = command.data;
        handleSignal(state, signalNumber);
        break;
      default:
        state.log("Unhandled command from client: $command");
    }
  }
}

void handleSignal(SessionState state, int signalNumber) {
  state.log("Received signal $signalNumber");
  if (!state.hasRemoteVm && state.fletchVm == null) {
    // This can happen if a user has attached to a vm using the "attach" verb
    // in which case we don't forward the signal to the vm.
    // TODO(wibling): Determine how to interpret the signal for the persistent
    // process.
    return;
  }
  if (state.hasRemoteVm) {
    signalAgentVm(state, signalNumber);
  } else {
    assert(state.fletchVm.process != null);
    int vmPid = state.fletchVm.process.pid;
    Process.runSync("kill", ["-$signalNumber", "$vmPid"]);
  }
}

Future signalAgentVm(SessionState state, int signalNumber) async {
  AgentConnection connection = await connectToAgent(state);
  try {
    await connection.signalVm(state.fletchAgentVmId, signalNumber);
  } on AgentException catch (error) {
    // Not sure if this is fatal. It happens when the vm is not found, ie.
    // already dead.
    throwFatalError(
        DiagnosticKind.socketAgentReplyError,
        address: '${connection.socket.remoteAddress.host}:'
            '${connection.socket.remotePort}',
        message: error.message);
  } on MessageDecodeException catch (error) {
    throwFatalError(
        DiagnosticKind.socketAgentReplyError,
        address: '${connection.socket.remoteAddress.host}:'
            '${connection.socket.remotePort}',
        message: error.message);
  } finally {
    disconnectFromAgent(connection);
  }
}

Future<int> upgradeAgent(
    SessionState state,
    Uri packageUri,
    String version) async {
  if (state.settings.deviceAddress == null) {
    throwFatalError(DiagnosticKind.noAgentFound);
  }
  AgentConnection connection;
  try {
    connection = await connectToAgent(state);
    List<int> data = await new File.fromUri(packageUri).readAsBytes();
    print('Sending package to fletch agent');
    await connection.upgradeAgent(version, data);
    print('Upgrade complete. Please allow the fletch-agent a few seconds '
        'to restart');
  } finally {
    if (connection != null) {
      disconnectFromAgent(connection);
    }
  }
  // TODO(karlklose): wait for the agent to come online again and verify
  // the version.
  return 0;
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

  String toJson() => "$host:$port";

  bool operator ==(other) {
    if (other is! Address) return false;
    return other.host == host && other.port == port;
  }

  int get hashCode => host.hashCode ^ port.hashCode;
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
  DeviceType deviceType;
  userSettings.forEach((String key, value) {
    switch (key) {
      case "packages":
        if (value != null) {
          if (value is! String) {
            throwFatalError(
                DiagnosticKind.settingsPackagesNotAString, uri: settingsUri);
          }
          packages = settingsUri.resolve(value);
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

      case "device_type":
        if (value != null) {
          if (value is! String) {
            throwFatalError(DiagnosticKind.settingsDeviceTypeNotAString,
                uri: settingsUri, userInput: '$value');
          }
          deviceType = parseDeviceType(value);
          if (deviceType == null) {
            throwFatalError(DiagnosticKind.settingsDeviceTypeUnrecognized,
                uri: settingsUri, userInput: '$value');
          }
        }
        break;

      default:
        throwFatalError(
            DiagnosticKind.settingsUnrecognizedKey, uri: settingsUri,
            userInput: key);
        break;
    }
  });
  return new Settings(packages, options, constants, deviceAddress, deviceType);
}

class Settings {
  final Uri packages;

  final List<String> options;

  final Map<String, String> constants;

  final Address deviceAddress;

  final DeviceType deviceType;

  const Settings(
      this.packages,
      this.options,
      this.constants,
      this.deviceAddress,
      this.deviceType);

  const Settings.empty()
    : this(null, const <String>[], const <String, String>{}, null, null);

  Settings copyWith({
      Uri packages,
      List<String> options,
      Map<String, String> constants,
      Address deviceAddress,
      DeviceType deviceType}) {

    if (packages == null) {
      packages = this.packages;
    }
    if (options == null) {
      options = this.options;
    }
    if (constants == null) {
      constants = this.constants;
    }
    if (deviceAddress == null) {
      deviceAddress = this.deviceAddress;
    }
    if (deviceType == null) {
      deviceType = this.deviceType;
    }
    return new Settings(
        packages,
        options,
        constants,
        deviceAddress,
        deviceType);
  }

  String toString() {
    return "Settings("
        "packages: $packages, "
        "options: $options, "
        "constants: $constants, "
        "device_address: $deviceAddress, "
        "device_type: $deviceType)";
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "packages": packages == null ? null : "$packages",
      "options": options,
      "constants": constants,
      "device_address": deviceAddress,
      "device_type": (deviceType == null)
          ? null
          : unParseDeviceType(deviceType),
    };
  }
}
