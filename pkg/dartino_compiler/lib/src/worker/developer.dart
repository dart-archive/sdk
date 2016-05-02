// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.worker.developer;

import 'dart:async' show
    Future;

import 'dart:convert' show
    JSON,
    JsonEncoder,
    LineSplitter,
    UTF8;

import 'dart:io' show
    Directory,
    File,
    FileSystemEntity,
    InternetAddress,
    Platform,
    Process,
    ProcessResult,
    SocketException;

import 'package:sdk_services/sdk_services.dart' show
    OutputService,
    SDKServices,
    DownloadException;

import 'package:dartino_agent/agent_connection.dart' show
    AgentConnection,
    AgentException,
    VmData;

import 'package:dartino_agent/messages.dart' show
    AGENT_DEFAULT_PORT,
    MessageDecodeException;

import 'package:mdns/mdns.dart' show
    MDnsClient,
    ResourceRecord,
    RRType;

import 'package:path/path.dart' show
    basename,
    basenameWithoutExtension,
    join,
    withoutExtension;

import '../../vm_commands.dart' show
    ConnectionError,
    HandShakeResult,
    ProgramInfoCommand,
    VmCommandCode;

import '../../program_info.dart' show
    IdOffsetMapping,
    NameOffsetMapping,
    ProgramInfoJson,
    buildIdOffsetMapping,
    getConfiguration;

import '../hub/session_manager.dart' show
    DartinoVm,
    SessionState,
    Sessions;

import '../hub/client_commands.dart' show
    ClientCommandCode;

import '../verbs/infrastructure.dart' show
    ClientCommand,
    ClientConnection,
    CommandSender,
    DiagnosticKind,
    DartinoCompiler,
    DartinoDelta,
    IncrementalCompiler,
    WorkerConnection,
    IsolatePool,
    DartinoVmContext,
    SharedTask,
    StreamIterator,
    throwFatalError;

import '../../incremental/dartino_compiler_incremental.dart' show
    IncrementalCompilationFailed;

import '../dartino_compiler_options.dart' show
    IncrementalMode,
    parseIncrementalMode,
    unparseIncrementalMode;

export '../dartino_compiler_options.dart' show
    IncrementalMode;

import '../../dartino_compiler.dart' show dartinoDeviceType;

import '../hub/exit_codes.dart' as exit_codes;

import '../diagnostic.dart' show
    throwInternalError;

import '../guess_configuration.dart' show
    executable,
    dartinoVersion;

import '../device_type.dart' show
    DeviceType,
    parseDeviceType,
    unParseDeviceType;

export '../device_type.dart' show
    DeviceType;

import '../please_report_crash.dart' show
    pleaseReportCrash;

import '../../debug_state.dart' as debug show
    RemoteObject,
    BackTrace;

import '../vm_connection.dart' show
  TcpConnection,
  TtyConnection,
  VmConnection;

import '../dartino_compiler_options.dart' show
    DartinoCompilerOptions;

typedef Future<Null> ClientEventHandler(DartinoVmContext vmContext);

Uri configFileUri;

Future<AgentConnection> connectToAgent(SessionState state) async {
  // TODO(wibling): need to make sure the agent is running.
  assert(state.settings.deviceAddress != null);
  String host = state.settings.deviceAddress.host;
  int agentPort = state.settings.deviceAddress.port;
  TcpConnection connection = await TcpConnection.connect(
      host, agentPort, "agentSocket", state.log,
      messageKind: DiagnosticKind.socketAgentConnectError);
  return new AgentConnection(connection);
}

/// Return the result of a function in the context of an open [AgentConnection].
///
/// The result is a [Future] of this value.
/// This function handles [AgentException] and [MessageDecodeException].
Future withAgentConnection(
    SessionState state,
    Future f(AgentConnection connection)) async {
  AgentConnection connection = await connectToAgent(state);
  try {
    return await f(connection);
  } on AgentException catch (error) {
    throwFatalError(
        DiagnosticKind.socketAgentReplyError,
        address: '${connection.connection.description}',
        message: error.message);
  } on MessageDecodeException catch (error) {
    throwFatalError(
        DiagnosticKind.socketAgentReplyError,
        address: '${connection.connection.description}',
        message: error.message);
  } finally {
    disconnectFromAgent(connection);
  }
}

void disconnectFromAgent(AgentConnection connection) {
  assert(connection.connection != null);
  connection.connection.close();
}

Future<Null> checkAgentVersion(Uri base, SessionState state) async {
  String deviceDartinoVersion = await withAgentConnection(state,
      (connection) => connection.dartinoVersion());
  Uri packageFile = await lookForAgentPackage(base, version: dartinoVersion);
  String fixit;
  if (packageFile != null) {
    fixit = "Try running\n"
      "  'dartino x-upgrade agent in session ${state.name}'.";
  } else {
    fixit = "Try downloading a matching SDK and running\n"
      "  'dartino x-upgrade agent in session ${state.name}'\n"
      "from the SDK's root directory.";
  }

  if (dartinoVersion != deviceDartinoVersion) {
    throwFatalError(DiagnosticKind.agentVersionMismatch,
        userInput: dartinoVersion,
        additionalUserInput: deviceDartinoVersion,
        fixit: fixit);
  }
}

Future<Null> startAndAttachViaAgent(Uri base, SessionState state) async {
  // TODO(wibling): integrate with the DartinoVm class, e.g. have a
  // AgentDartinoVm and LocalDartinoVm that both share the same interface
  // where the former is interacting with the agent.
  await checkAgentVersion(base, state);
  VmData vmData = await withAgentConnection(state,
      (connection) => connection.startVm());
  state.dartinoAgentVmId = vmData.id;
  String host = state.settings.deviceAddress.host;
  await attachToVmTcp(host, vmData.port, state);
  await state.vmContext.disableVMStandardOutput();
}

Future<Null> startAndAttachDirectly(SessionState state, Uri base) async {
  String dartinoVmPath = state.compilerHelper.dartinoVm.toFilePath();
  state.dartinoVm =
      await DartinoVm.start(dartinoVmPath, workingDirectory: base);
  await attachToVmTcp(state.dartinoVm.host, state.dartinoVm.port, state);
  await state.vmContext.disableVMStandardOutput();
}

/// Analyze the target and report the results to the user.
Future<int> analyze(
    Uri fileUri,
    SessionState state,
    Uri base) async {
  Directory dartSdkDir = await locateDartSdkDirectory();
  String analyzerPath = join(dartSdkDir.path, 'bin', 'dartanalyzer');

  List<String> arguments = <String>[];
  arguments.add('--packages');
  arguments.add(new File.fromUri(state.settings.packages).path);
  arguments.add(new File.fromUri(fileUri).path);

  state.log('Analyze: $analyzerPath ${arguments.join(' ')}');
  Process process = await Process.start(analyzerPath, arguments);
  process.stdout.transform(UTF8.decoder).transform(new LineSplitter())
      .listen(print);
  process.stderr.transform(UTF8.decoder).transform(new LineSplitter())
      .listen(print);
  return process.exitCode;
}

Future<Null> attachToVmTty(String ttyDevice, SessionState state) async {
  TtyConnection connection = await TtyConnection.connect(
      ttyDevice, "vmTty", state.log);
  await attachToVm(connection, state);
}

Future<Null> attachToVmTcp(String host, int port, SessionState state) async {
  TcpConnection connection = await TcpConnection.connect(
      host, port, "vmSocket", state.log);
  await attachToVm(connection, state);
}

Future<Null> attachToVm(VmConnection connection, SessionState state) async {
  DartinoVmContext vmContext = new DartinoVmContext(
      connection,
      state.compiler,
      state.stdoutSink,
      state.stderrSink,
      null);

  // Perform handshake with VM which validates that VM and compiler
  // have the same versions.
  HandShakeResult handShakeResult = await vmContext.handShake(dartinoVersion);
  if (handShakeResult == null) {
    throwFatalError(
        DiagnosticKind.handShakeFailed, address: connection.description);
  }
  if (!handShakeResult.success) {
    throwFatalError(DiagnosticKind.versionMismatch,
                    address: connection.description,
                    userInput: dartinoVersion,
                    additionalUserInput: handShakeResult.version);
  }
  vmContext.configuration = getConfiguration(handShakeResult.wordSize,
      handShakeResult.dartinoDoubleSize);

  state.vmContext = vmContext;
}

/// Create the new project directory and copy the specified template into it.
Future<int> createProject(Uri projectUri, String boardName,
    [String templateName]) async {
  Uri templateUri = await findProjectTemplate(boardName, templateName);
  if (templateUri == null) return -1;

  // Recursively copy the template
  recursiveCopy(Directory src, Directory dst) async {
    await dst.create(recursive: true);
    await for (FileSystemEntity srcChild in src.list()) {
      String dstChildPath = join(dst.path, basename(srcChild.path));
      if (srcChild is File) {
        await srcChild.copy(dstChildPath);
      } else if (srcChild is Directory) {
        await recursiveCopy(srcChild, new Directory(dstChildPath));
      }
    }
  }
  recursiveCopy(
    new Directory.fromUri(templateUri), new Directory.fromUri(projectUri));
  return 0;
}

Future<int> compile(
    Uri script,
    SessionState state,
    Uri base,
    {bool analyzeOnly: false,
     bool fatalIncrementalFailures: false}) async {
  IncrementalCompiler compiler = state.compiler;
  if (!compiler.isProductionModeEnabled) {
    state.resetCompiler();
  }
  Uri firstScript = state.script;
  List<DartinoDelta> previousResults = state.compilationResults;

  DartinoDelta newResult;
  try {
    if (analyzeOnly) {
      state.resetCompiler();
      state.log("Analyzing '$script'");
      return await compiler.analyze(script, base);
    } else if (previousResults.isEmpty) {
      state.script = script;
      await compiler.compile(script, base);
      newResult = compiler.computeInitialDelta();
    } else {
      try {
        state.log("Compiling difference from $firstScript to $script");
        newResult = await compiler.compileUpdates(
            previousResults.last.system, <Uri, Uri>{firstScript: script},
            Uri.base, logTime: state.log, logVerbose: state.log);
      } on IncrementalCompilationFailed catch (error) {
        state.log(error);
        state.resetCompiler();
        if (fatalIncrementalFailures) {
          print(error);
          state.log(
              "Aborting compilation due to --fatal-incremental-failures...");
          return exit_codes.INCREMENTAL_COMPILER_FAILED;
        }
        state.log("Attempting full compile...");
        state.script = script;
        await compiler.compile(script, base);
        newResult = compiler.computeInitialDelta();
      }
    }
  } catch (error, stackTrace) {
    pleaseReportCrash(error, stackTrace);
    return exit_codes.COMPILER_EXITCODE_CRASH;
  }
  if (newResult == null) {
    return exit_codes.DART_VM_EXITCODE_COMPILE_TIME_ERROR;
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

Future<Uri> findFile(Uri cwd, String fileName) async {
  Uri uri = cwd.resolve(fileName);
  while (true) {
    if (await new File.fromUri(uri).exists()) return uri;
    if (uri.pathSegments.length <= 1) return null;
    uri = uri.resolve('../$fileName');
  }
}

Future<Uri> findDirectory(Uri cwd, String directoryName) async {
  // Ensure returned Uri ends with a `/`
  if (!directoryName.endsWith('/')) directoryName = '$directoryName/';
  Uri uri = cwd.resolve(directoryName);
  while (true) {
    if (await new Directory.fromUri(uri).exists()) return uri;
    if (uri.pathSegments.length <= 2) return null;
    // Because uri ends with `/`, must move up 2 levels
    uri = uri.resolve('../../$directoryName');
  }
}

/// Return a list of board names or `null` if none can be found
Future<List<String>> findBoardNames() async {
  Uri platformsUri = await findDirectory(executable, 'platforms');
  if (platformsUri == null) return null;
  return new Directory.fromUri(platformsUri).list()
      .map((FileSystemEntity e) => basename(e.path)).toList();
}

/// Return the [Uri] of the project template for the specified board.
/// Return `null` if it cannot be found.
Future<Uri> findProjectTemplate(String boardName, [String templateName]) async {
  templateName ??= 'default';
  Uri platformsUri = await findDirectory(executable, 'platforms');
  if (platformsUri == null) return null;
  Uri boardUri = platformsUri.resolve('$boardName/');
  if (!await new Directory.fromUri(boardUri).exists()) return null;
  return boardUri.resolve('templates/$templateName/');
}

Future<Settings> createSettings(
    String sessionName,
    Uri uri,
    Uri cwd,
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator) async {
  String settingsFileName = '$sessionName.dartino-settings';

  if (uri == null) {
    // Try to find a $sessionName.dartino-settings file starting from the
    // current working directory and walking up its parent directories.
    uri = await findFile(cwd, settingsFileName);
  }

  if (uri != null) {
    return await readSettings(uri);
  }

  // If no settings file has been found, try to find the settings template file
  // (in the SDK or git repo) by looking for a .dartino-settings file starting
  // from the dart executable's directory and walking up its parent directory
  // chain.
  Settings settings;
  uri = await findFile(executable, '.dartino-settings');
  if (uri != null) {
    print("Using template settings file '${uri.toFilePath()}'");
    settings = await readSettings(uri);
  } else {
    print('Warning: no template settings file found!');
    settings = const Settings.empty();
  }

  /// Should be set to true if the settings have been modified due to user input
  /// and should be saved to disk.
  bool persistSettings = false;

  if (sessionName == "remote") {
    Address address = await readAddressFromUser(commandSender, commandIterator);
    settings = settings.copyWith(deviceAddress: address);
    persistSettings = true;
  }

  if (persistSettings) {
    Uri path = await readPathFromUser(cwd, commandSender, commandIterator);
    uri = path.resolve(settingsFileName);
    print("Creating settings file '${uri.toFilePath()}'");
    await new File.fromUri(uri).writeAsString(
        "${const JsonEncoder.withIndent('  ').convert(settings)}\n");
  }

  return settings;
}

Future<Address> readAddressFromUser(
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator) async {
  String message = "Please enter IP address of remote device "
      "(press Enter to search for devices):";
  commandSender.sendStdout(message);
  // The list of devices found by running discovery.
  List<InternetAddress> devices = <InternetAddress>[];
  while (await commandIterator.moveNext()) {
    ClientCommand command = commandIterator.current;
    switch (command.code) {
      case ClientCommandCode.Stdin:
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
        if (line.isEmpty && devices.isEmpty) {
          commandSender.sendStdout("\n");
          // [discoverDevices] will print out the list of device with their
          // IP address, hostname, and agent version.
          devices = await discoverDevices(prefixWithNumber: true);
          if (devices.isEmpty) {
            commandSender.sendStdout(
                "Couldn't find Dartino capable devices\n");
            commandSender.sendStdout(message);
          } else {
            if (devices.length == 1) {
              commandSender.sendStdout("\n");
              commandSender.sendStdout("Press Enter to use this device");
            } else {
              commandSender.sendStdout("\n");
              commandSender.sendStdout(
                  "Found ${devices.length} Dartino capable devices\n");
              commandSender.sendStdout(
                  "Please enter the number or the IP address of "
                  "the remote device you would like to use "
                  "(press Enter to use the first device): ");
            }
          }
        } else {
          bool checkedIndex = false;
          if (devices.length > 0) {
            if (line.isEmpty) {
              return new Address(devices[0].address, AGENT_DEFAULT_PORT);
            }
            try {
              checkedIndex = true;
              int index = int.parse(line);
              if (1 <= index  && index <= devices.length) {
                return new Address(devices[index - 1].address,
                                   AGENT_DEFAULT_PORT);
              } else {
                commandSender.sendStdout("Invalid device index $line\n\n");
                commandSender.sendStdout(message);
              }
            } on FormatException {
              // Ignore FormatException and fall through to parse as IP address.
            }
          }
          if (!checkedIndex) {
            return parseAddress(line, defaultPort: AGENT_DEFAULT_PORT);
          }
        }
        break;

      default:
        throwInternalError("Unexpected ${command.code}");
        return null;
    }
  }
  return null;
}

Future<Uri> readPathFromUser(
    Uri proposal,
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator) async {
 commandSender.sendStdout(
     "Please enter the directory in which to store the settings file.\n"
     "Press (Enter) to select the current directory "
     "(${proposal.toFilePath()}):\n");
  while (await commandIterator.moveNext()) {
    ClientCommand command = commandIterator.current;
    switch (command.code) {
      case ClientCommandCode.Stdin:
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
        if (line.isEmpty) {
          return proposal;
        }

        if (await new Directory(line).exists()) {
          return new Uri.directory(line);
        } else {
          commandSender.sendStdout("Directory $line does not exist!\n");
        }
        break;

      default:
        throwInternalError("Unexpected ${command.code}");
        return null;
    }
  }
  return null;
}

SessionState createSessionState(
    String name,
    Uri base,
    Settings settings,
    {Uri libraryRoot,
     Uri dartinoVm,
     Uri nativesJson}) {
  if (settings == null) {
    settings = const Settings.empty();
  }

  Uri packageConfig = settings.packages;
  if (packageConfig == null) {
    packageConfig = executable.resolve("dartino-sdk.packages");
  }

  DeviceType deviceType = settings.deviceType ??
      parseDeviceType(dartinoDeviceType);

  String platform = (deviceType == DeviceType.embedded)
      ? "dartino_embedded.platform"
      : "dartino_mobile.platform";

  DartinoCompilerOptions compilerOptions = DartinoCompilerOptions.parse(
      settings.compilerOptions,
      base,
      platform: platform,
      libraryRoot: libraryRoot,
      packageConfig: packageConfig,
      environment: settings.constants);

  if (const bool.fromEnvironment("dartino_compiler-verbose")) {
    compilerOptions =
        DartinoCompilerOptions.copy(compilerOptions, verbose: true);
  }

  DartinoCompiler compilerHelper = new DartinoCompiler(
      options: compilerOptions,
      dartinoVm: dartinoVm,
      nativesJson: nativesJson);

  return new SessionState(
      name, compilerHelper,
      compilerHelper.newIncrementalCompiler(settings.incrementalMode),
      settings);
}

Future<int> run(
    SessionState state,
    List<String> arguments,
    {bool terminateDebugger: true}) async {
  List<DartinoDelta> compilationResults = state.compilationResults;
  DartinoVmContext vmContext = state.vmContext;

  vmContext.enableLiveEditing();
  for (DartinoDelta delta in compilationResults) {
    await vmContext.applyDelta(delta);
  }

  vmContext.silent = true;

  await vmContext.spawnProcess(arguments);
  var command = await vmContext.startRunning();

  int exitCode = exit_codes.COMPILER_EXITCODE_CRASH;
  if (command == null) {
    await vmContext.kill();
    await vmContext.shutdown();
    throwInternalError("No command received from Dartino VM");
  }

  Future printException() async {
    if (!vmContext.loaded) {
      print('### process not loaded, cannot print uncaught exception');
      return;
    }
    debug.RemoteObject exception = await vmContext.uncaughtException();
    if (exception != null) {
      print(vmContext.exceptionToString(exception));
    }
  }

  Future printTrace() async {
    if (!vmContext.loaded) {
      print("### process not loaded, cannot print stacktrace and code");
      return;
    }
    debug.BackTrace stackTrace = await vmContext.backTrace();
    if (stackTrace != null) {
      print(stackTrace.format());
      print(stackTrace.list(state));
    }
  }

  try {
    switch (command.code) {
      case VmCommandCode.UncaughtException:
        state.log("Uncaught error");
        exitCode = exit_codes.DART_VM_EXITCODE_UNCAUGHT_EXCEPTION;
        await printException();
        await printTrace();
        // TODO(ahe): Need to continue to unwind stack.
        break;
      case VmCommandCode.ProcessCompileTimeError:
        state.log("Compile-time error");
        exitCode = exit_codes.DART_VM_EXITCODE_COMPILE_TIME_ERROR;
        await printTrace();
        // TODO(ahe): Continue to unwind stack?
        break;

      case VmCommandCode.ProcessTerminated:
        exitCode = 0;
        break;

      case VmCommandCode.ConnectionError:
        state.log("Error on connection to Dartino VM: ${command.error}");
        exitCode = exit_codes.COMPILER_EXITCODE_CONNECTION_ERROR;
        break;

      default:
        throwInternalError("Unexpected result from Dartino VM: '$command'");
        break;
    }
  } finally {
    if (terminateDebugger) {
      await state.terminateSession();
    } else {
      // If the vmContext terminated due to a ConnectionError or the program
      // finished don't reuse the state's vmContext.
      if (vmContext.terminated) {
        state.vmContext = null;
      }
      vmContext.silent = false;
    }
  };

  return exitCode;
}

/// Returns the [NameOffsetMapping] stored in the '.info.json' adjacent to a
/// snapshot location.
Future<NameOffsetMapping> getInfoFromSnapshotLocation(Uri snapshot) async {
  Uri info = snapshot.replace(path: "${snapshot.path}.info.json");
  File infoFile = new File.fromUri(info);

  if (!await infoFile.exists()) {
    throwFatalError(DiagnosticKind.infoFileNotFound, uri: snapshot);
  }

  try {
    return ProgramInfoJson.decode(await infoFile.readAsString());
  } on FormatException {
    throwFatalError(DiagnosticKind.malformedInfoFile, uri: snapshot);
  }
}

Future<int> export(SessionState state, Uri snapshot) async {
  List<DartinoDelta> compilationResults = state.compilationResults;
  DartinoVmContext vmContext = state.vmContext;
  state.vmContext = null;

  await vmContext.enableLiveEditing();
  for (DartinoDelta delta in compilationResults) {
    await vmContext.applyDelta(delta);
  }

  var result = await vmContext.createSnapshot(
      snapshotPath: snapshot.toFilePath());
  if (result is ProgramInfoCommand) {
    ProgramInfoCommand snapshotResult = result;

    await vmContext.shutdown();

    IdOffsetMapping idOffsetMapping =
        buildIdOffsetMapping(
            state.compiler.compiler.libraryLoader.libraries,
            compilationResults.last.system, snapshotResult);

    File jsonFile = new File('${snapshot.toFilePath()}.info.json');
    await jsonFile.writeAsString(
        ProgramInfoJson.encode(idOffsetMapping.nameOffsets));

    return 0;
  } else {
    assert(result is ConnectionError);
    print("There was a connection error while writing the snapshot.");
    return exit_codes.COMPILER_EXITCODE_CONNECTION_ERROR;
  }
}

Future<int> compileAndAttachToVmThen(
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator,
    SessionState state,
    Uri script,
    Uri base,
    bool waitForVmExit,
    Future<int> action(),
    {ClientEventHandler eventHandler}) async {
  bool startedVmDirectly = false;
  List<DartinoDelta> compilationResults = state.compilationResults;
  if (compilationResults.isEmpty || script != null) {
    if (script == null) {
      throwFatalError(DiagnosticKind.noFileTarget);
    }
    int exitCode = await compile(script, state, base);
    if (exitCode != 0) return exitCode;
    compilationResults = state.compilationResults;
    assert(compilationResults != null);
  }

  DartinoVmContext vmContext = state.vmContext;
  if (vmContext != null && vmContext.loaded) {
    // We cannot reuse a vmContext that has already been loaded. Loading
    // currently implies that some of the code has been run.
    if (state.explicitAttach) {
      // If the user explicitly called 'dartino attach' we cannot
      // create a new vmContext since we don't know if the vm is
      // running locally or remotely and if running remotely there
      // is no guarantee there is an agent to start a new vm.
      //
      // The UserSession is invalid in its current state as the
      // vm context has already been loaded and run some code.
      throwFatalError(DiagnosticKind.sessionInvalidState,
          sessionName: state.name);
    }
    state.log('Cannot reuse existing VM session, creating new.');
    await state.terminateSession();
    vmContext = null;
  }
  if (vmContext == null) {
    if (state.settings.deviceAddress != null) {
      await startAndAttachViaAgent(base, state);
      // TODO(wibling): read stdout from agent.
    } else {
      startedVmDirectly = true;
      await startAndAttachDirectly(state, base);
      state.dartinoVm.stdoutLines.listen((String line) {
          commandSender.sendStdout("$line\n");
        });
      state.dartinoVm.stderrLines.listen((String line) {
          commandSender.sendStderr("$line\n");
        });
    }
    vmContext = state.vmContext;
    assert(vmContext != null);
  }

  eventHandler ??= defaultClientEventHandler(state, commandIterator);
  setupClientInOut(state, commandSender, eventHandler);

  int exitCode = exit_codes.COMPILER_EXITCODE_CRASH;
  try {
    exitCode = await action();
  } catch (error, trace) {
    print(error);
    if (trace != null) {
      print(trace);
    }
  } finally {
    if (waitForVmExit && startedVmDirectly) {
      exitCode = await state.dartinoVm.exitCode;
    }
    state.detachCommandSender();
  }
  return exitCode;
}

void setupClientInOut(
    SessionState state,
    CommandSender commandSender,
    ClientEventHandler eventHandler) {
  // Forward output going into the state's outputSink using the passed in
  // commandSender. This typically forwards output to the hub (main isolate)
  // which forwards it on to stdout of the Dartino C++ client.
  state.attachCommandSender(commandSender);

  // Start event handling for input passed from the Dartino C++ client.
  eventHandler(state.vmContext);

  // Let the hub (main isolate) know that event handling has been started.
  commandSender.sendEventLoopStarted();
}

/// Return a default client event handler bound to the current session's
/// commandIterator and state.
/// This handler only takes care of signals coming from the client.
ClientEventHandler defaultClientEventHandler(
    SessionState state,
    StreamIterator<ClientCommand> commandIterator) {
  return (DartinoVmContext vmContext) async {
    while (await commandIterator.moveNext()) {
      ClientCommand command = commandIterator.current;
      switch (command.code) {
        case ClientCommandCode.Signal:
          int signalNumber = command.data;
          handleSignal(state, signalNumber);
          break;
        default:
          state.log("Unhandled command from client: $command");
      }
    }
  };
}

void handleSignal(SessionState state, int signalNumber) {
  state.log("Received signal $signalNumber");
  if (!state.hasRemoteVm && state.dartinoVm == null) {
    // This can happen if a user has attached to a vm using the "attach" verb
    // in which case we don't forward the signal to the vm.
    // TODO(wibling): Determine how to interpret the signal for the persistent
    // process.
    state.log('Signal $signalNumber ignored. VM was manually attached.');
    print('Signal $signalNumber ignored. VM was manually attached.');
    return;
  }
  if (state.hasRemoteVm) {
    signalAgentVm(state, signalNumber);
  } else {
    assert(state.dartinoVm.process != null);
    int vmPid = state.dartinoVm.process.pid;
    Process.runSync("kill", ["-$signalNumber", "$vmPid"]);
  }
}

Future signalAgentVm(SessionState state, int signalNumber) async {
  await withAgentConnection(state, (connection) {
    return connection.signalVm(state.dartinoAgentVmId, signalNumber);
  });
}

String extractVersion(Uri uri) {
  List<String> nameParts = uri.pathSegments.last.split('_');
  if (nameParts.length != 3 || nameParts[0] != 'dartino-agent') {
    throwFatalError(DiagnosticKind.upgradeInvalidPackageName);
  }
  String version = nameParts[1];
  // create_debian_packages.py adds a '-1' after the hash in the package name.
  if (version.endsWith('-1')) {
    version = version.substring(0, version.length - 2);
  }
  return version;
}

/// Try to locate an Dartino agent package file assuming the normal SDK layout
/// with SDK base directory [base].
///
/// If the parameter [version] is passed, the Uri is only returned, if
/// the version matches.
Future<Uri> lookForAgentPackage(Uri base, {String version}) async {
  String platform = "raspberry-pi2";
  Uri platformUri = base.resolve("platforms/$platform");
  Directory platformDir = new Directory.fromUri(platformUri);

  // Try to locate the agent package in the SDK for the selected platform.
  if (await platformDir.exists()) {
    for (FileSystemEntity entry in platformDir.listSync()) {
      Uri uri = entry.uri;
      String name = uri.pathSegments.last;
      if (name.startsWith('dartino-agent') &&
          name.endsWith('.deb') &&
          (version == null || extractVersion(uri) == version)) {
        return uri;
      }
    }
  }
  return null;
}

Future<Uri> readPackagePathFromUser(
    Uri base,
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator) async {
  Uri sdkAgentPackage = await lookForAgentPackage(base);
  if (sdkAgentPackage != null) {
    String path = sdkAgentPackage.toFilePath();
    commandSender.sendStdout("Found SDK package: $path\n");
    commandSender.sendStdout("Press Enter to use this package to upgrade "
        "or enter the path to another package file:\n");
  } else {
    commandSender.sendStdout("Please enter the path to the package file "
        "you want to use:\n");
  }

  while (await commandIterator.moveNext()) {
    ClientCommand command = commandIterator.current;
    switch (command.code) {
      case ClientCommandCode.Stdin:
        if (command.data.length == 0) {
          throwInternalError("Unexpected end of input");
        }
        // TODO(karlklose): This assumes that the user's input arrives as one
        // message. It is relatively safe to assume this for a normal terminal
        // session because we use canonical input processing (Unix line
        // buffering), but it doesn't work in general. So we should fix that.
        String line = UTF8.decode(command.data).trim();
        if (line.isEmpty) {
          return sdkAgentPackage;
        } else {
          return base.resolve(line);
        }
        break;

      default:
        throwInternalError("Unexpected ${command.code}");
        return null;
    }
  }
  return null;
}

class Version {
  final List<int> version;
  final String label;

  Version(this.version, this.label) {
    if (version.length != 3) {
      throw new ArgumentError("version must have three parts");
    }
  }

  /// Returns `true` if this version's digits are greater in lexicographical
  /// order.
  ///
  /// We use a function instead of [operator >] because [label] is not used
  /// in the comparison, but it is used in [operator ==].
  bool isGreaterThan(Version other) {
    for (int part = 0; part < 3; ++part) {
      if (version[part] < other.version[part]) {
        return false;
      }
      if (version[part] > other.version[part]) {
        return true;
      }
    }
    return false;
  }

  bool operator ==(other) {
    return other is Version &&
        version[0] == other.version[0] &&
        version[1] == other.version[1] &&
        version[2] == other.version[2] &&
        label == other.label;
  }

  int get hashCode {
    return 3 * version[0] +
        5 * version[1] +
        7 * version[2] +
        13 * label.hashCode;
  }

  /// Check if this version is a bleeding edge version.
  bool get isEdgeVersion => label == null ? false : label.startsWith('edge.');

  /// Check if this version is a dev version.
  bool get isDevVersion => label == null ? false : label.startsWith('dev.');

  String toString() {
    String labelPart = label == null ? '' : '-$label';
    return '${version[0]}.${version[1]}.${version[2]}$labelPart';
  }
}

Version parseVersion(String text) {
  List<String> labelParts = text.split('-');
  if (labelParts.length > 2) {
    throw new ArgumentError('Not a version: $text.');
  }
  List<String> digitParts = labelParts[0].split('.');
  if (digitParts.length != 3) {
    throw new ArgumentError('Not a version: $text.');
  }
  List<int> digits = digitParts.map(int.parse).toList();
  return new Version(digits, labelParts.length == 2 ? labelParts[1] : null);
}

Future<int> upgradeAgent(
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator,
    SessionState state,
    Uri base,
    Uri packageUri) async {
  if (state.settings.deviceAddress == null) {
    throwFatalError(DiagnosticKind.noAgentFound);
  }

  while (packageUri == null) {
    packageUri =
      await readPackagePathFromUser(base, commandSender, commandIterator);
  }

  if (!await new File.fromUri(packageUri).exists()) {
    print('File not found: $packageUri');
    return 1;
  }

  Version version = parseVersion(extractVersion(packageUri));

  Version existingVersion = parseVersion(
      await withAgentConnection(state,
          (connection) => connection.dartinoVersion()));

  if (existingVersion == version) {
    print('Target device is already at $version');
    return 0;
  }

  print("Attempting to upgrade device from "
      "$existingVersion to $version");

  if (existingVersion.isGreaterThan(version)) {
    commandSender.sendStdout("The existing version is greater than the "
        "version you want to use to upgrade.\n"
        "Please confirm this operation by typing 'yes' "
        "(press Enter to abort): ");
    Confirm: while (await commandIterator.moveNext()) {
      ClientCommand command = commandIterator.current;
      switch (command.code) {
        case ClientCommandCode.Stdin:
        if (command.data.length == 0) {
          throwInternalError("Unexpected end of input");
        }
        String line = UTF8.decode(command.data).trim();
        if (line.isEmpty) {
          commandSender.sendStdout("Upgrade aborted\n");
          return 0;
        } else if (line.trim().toLowerCase() == "yes") {
          break Confirm;
        }
        break;

      default:
        throwInternalError("Unexpected ${command.code}");
        return null;
      }
    }
  }

  List<int> data = await new File.fromUri(packageUri).readAsBytes();
  print("Sending package to dartino agent");
  await withAgentConnection(state,
      (connection) => connection.upgradeAgent(version.toString(), data));
  print("Transfer complete, waiting for the Dartino agent to restart. "
      "This can take a few seconds.");

  Version newVersion;
  int remainingTries = 20;
  // Wait for the agent to come back online to verify the version.
  while (--remainingTries > 0) {
    await new Future.delayed(const Duration(seconds: 1));
    VmConnection vmConnection = await TcpConnection.connect(
        state.settings.deviceAddress.host,
        state.settings.deviceAddress.port,
        "waitForAgentUpgrade",
        state.log,
        // Ignore this error and keep waiting.
        onConnectionError: (SocketException _) {});
    AgentConnection connection = new AgentConnection(vmConnection);
    newVersion = parseVersion(await connection.dartinoVersion());
    disconnectFromAgent(connection);
    if (newVersion != existingVersion) {
      break;
    }
  }

  if (newVersion == existingVersion) {
    print("Failed to upgrade: the device is still at the old version.");
    print("Try running x-upgrade again. "
        "If the upgrade fails again, try rebooting the device.");
    return 1;
  } else if (newVersion == null) {
    print("Could not connect to Dartino agent after upgrade.");
    print("Try running 'dartino show devices' later to see if it has been"
        " restarted. If the device does not show up, try rebooting it.");
    return 1;
  } else {
    print("Upgrade successful.");
  }

  return 0;
}

void throwUnsupportedPlatform() {
  throwFatalError(
      DiagnosticKind.unsupportedPlatform,
      message: Platform.operatingSystem);
}

Future<int> downloadTools(
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator,
    SessionState state) async {

  Future decompressFile(File zipFile, Directory destination) async {
    ProcessResult result;
    if (Platform.isLinux) {
      result = await Process.run(
          "unzip", ["-o", zipFile.path, "-d", destination.path]);
    } else if (Platform.isMacOS) {
      result = await Process.run(
          "ditto", ["-x", "-k", zipFile.path, destination.path]);
    } else {
      throwUnsupportedPlatform();
    }
    if (result.exitCode != 0) {
        throwInternalError(
            "Failed to decompress ${zipFile.path} to ${destination.path}, "
            "error = ${result.exitCode}");
    }
  }

  const String gcsRoot = "https://storage.googleapis.com";
  String gcsBucket = "dartino-archive";

  Future<int> downloadTool(String gcsPath, String zipFile,
                           String toolName) async {
    Uri url = Uri.parse("$gcsRoot/$gcsBucket/$gcsPath/$zipFile");
    Directory tmpDir = Directory.systemTemp.createTempSync("dartino_download");
    File tmpZip = new File(join(tmpDir.path, zipFile));

    OutputService outputService =
        new OutputService(commandSender.sendStdout, state.log);
    SDKServices service = new SDKServices(outputService);
    print("Downloading: $toolName");
    state.log("Downloading $toolName from $url to $tmpZip");
    try {
      await service.downloadWithProgress(url, tmpZip);
    } on DownloadException catch (e) {
      print("Failed to download $url: $e");
      return 1;
    }
    print(""); // service.downloadWithProgress does not write newline when done.

    // In the SDK, the tools directory is at the same level as the
    // internal (and bin) directory.
    Directory toolsDirectory =
        new Directory.fromUri(executable.resolve('../tools'));
    state.log("Decompressing ${tmpZip.path} to ${toolsDirectory.path}");
    await decompressFile(tmpZip, toolsDirectory);
    state.log("Deleting temporary directory ${tmpDir.path}");
    await tmpDir.delete(recursive: true);
    return 0;
  }

  String gcsPath;

  Version version = parseVersion(dartinoVersion);
  if (version.isEdgeVersion) {
    // For edge versions download use a well known version for now.
    var knownVersion = "0.3.0-dev.5.2";
    print("WARNING: For bleeding edge tools from version "
          "$knownVersion is used.");
    gcsPath = "channels/dev/raw/$knownVersion/sdk";
  } else if (version.isDevVersion) {
    // TODO(sgjesse): Change this to channels/dev/release at some point.
    gcsPath = "channels/dev/raw/$version/sdk";
  } else {
    print("Stable version not supported. Got version $version.");
  }

  String osName;
  if (Platform.isLinux) {
    osName = "linux";
  } else if (Platform.isMacOS) {
    osName = "mac";
  } else {
    throwUnsupportedPlatform();
  }

  String gccArmEmbedded = "gcc-arm-embedded-${osName}.zip";
  var result =
      await downloadTool(gcsPath, gccArmEmbedded, "GCC ARM Embedded toolchain");
  if (result != 0) return result;
  String openocd = "openocd-${osName}.zip";
  result =
      await downloadTool(gcsPath, openocd, "Open On-Chip Debugger (OpenOCD)");
  if (result != 0) return result;

  print("Third party tools downloaded");

  return 0;
}

Future<Directory> locateBinDirectory() async {
  // In the SDK, the tools directory is at the same level as the
  // internal (and bin) directory.
  String path = 'platforms/stm32f746g-discovery/bin';
  Directory binDirectory =
      new Directory.fromUri(executable.resolve(
          '../$path'));
  if ((await binDirectory.exists())) {
    // In the SDK, the tools directory is at the same level as the
    // internal (and bin) directory.
    Directory toolsDirectory =
        new Directory.fromUri(executable.resolve('../tools'));
    if (!(await toolsDirectory.exists())) {
      throwFatalError(DiagnosticKind.toolsNotInstalled);
    }
  } else {
    // In the Git checkout the platform scripts is under platforms.
    binDirectory =
        new Directory.fromUri(executable.resolve(
                '../../$path'));
    assert(await binDirectory.exists());
  }

  return binDirectory;
}

Future<Directory> locateDartSdkDirectory() async {
  // In the SDK, the dart-sdk directory is in the internal directory.
  Directory dartSdkDirectory =
      new Directory.fromUri(executable.resolve(
          '../internal/dart-sdk'));
  if (!await dartSdkDirectory.exists()) {
    // When running in a Git checkout...
    dartSdkDirectory =
        new Directory.fromUri(executable.resolve(
                'dartino-sdk/internal/dart-sdk'));
    assert(await dartSdkDirectory.exists());
  }

  return dartSdkDirectory;
}

// Creates a c-file containing the options options in an array.
void createEmbedderOptionsCFile(Directory location, List<String> options) {
  String tmpOptionsFilename = join(location.path, "embedder_options.c");
  String optionStrings = (options ?? <String>[])
      .map((String option) {
    String escaped = option
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"');
    return '\n  "$escaped",';
  }).join();
  new File(tmpOptionsFilename).writeAsStringSync("""
const char *dartino_embedder_options[] = {$optionStrings
  0
};
""");
}

Future<int> buildImage(
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator,
    SessionState state,
    Uri snapshot) async {
  if (snapshot == null) {
    throwFatalError(DiagnosticKind.noFileTarget);
  }
  assert(snapshot.scheme == 'file');
  Directory binDirectory = await locateBinDirectory();

  Directory tmpDir;
  try {
    String baseName = basenameWithoutExtension(snapshot.path);

    // Create a temp directory for building.
    tmpDir = Directory.systemTemp.createTempSync("dartino_build");
    String tmpSnapshot = join(tmpDir.path, "snapshot");
    await new File.fromUri(snapshot).copy(tmpSnapshot);

    createEmbedderOptionsCFile(tmpDir, state.settings.embedderOptions);

    ProcessResult result;
    File linkScript = new File(join(binDirectory.path, 'link.sh'));
    if (Platform.isLinux || Platform.isMacOS) {
      state.log("Linking image: '${linkScript.path} ${baseName}'");
      result = await Process.run(
          linkScript.path,
          [baseName, tmpDir.path],
          workingDirectory: tmpDir.path);
    } else {
      throwUnsupportedPlatform();
    }
    state.log("STDOUT:\n${result.stdout}");
    state.log("STDERR:\n${result.stderr}");
    if (result.exitCode != 0) {
      print("STDOUT:\n${result.stdout}");
      print("STDERR:\n${result.stderr}");
      throwInternalError(
          "Failed to build image, "
          "error = ${result.exitCode}");
    }
    // Copy the .bin file from the tmp directory.
    String tmpBinFile = join(tmpDir.path, "${baseName}.bin");
    String binFile = "${withoutExtension(snapshot.path)}.bin";
    await new File(tmpBinFile).copy(binFile);
    print("Done building image: $binFile");
  } finally {
    if (tmpDir != null) {
      await tmpDir.delete(recursive: true);
    }
  }

  return 0;
}

Future<int> flashImage(
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator,
    SessionState state,
    Uri image) async {
  assert(image.scheme == 'file');
  Directory binDirectory = await locateBinDirectory();
  ProcessResult result;
  File flashScript = new File(join(binDirectory.path, 'flash.sh'));
  if (Platform.isLinux || Platform.isMacOS) {
    state.log("Flashing image: '${flashScript.path} ${image}'");
    print("Flashing image: ${image}");
    result = await Process.run(flashScript.path, [image.path]);
  } else {
    throwUnsupportedPlatform();
  }
  state.log("STDOUT:\n${result.stdout}");
  state.log("STDERR:\n${result.stderr}");
  if (result.exitCode != 0) {
    print("Failed to flash the image: ${image}\n");
    print("Please check that the device is connected and ready. "
          "In some situations un-plugging and plugging the device, "
          "and then retrying will solve the problem.\n");
    if (Platform.isLinux) {
      print("On Linux, users must be granted with rights for accessing "
            "the ST-LINK USB devices. To do that, it might be necessary to "
            "add rules into /etc/udev/rules.d: for instance on Ubuntu, "
            "this is done through the command "
            "'sudo cp 49-stlinkv2-1.rules /etc/udev/rules.d'\n");
      print("For more information see the release notes "
            "http://www.st.com/st-web-ui/static/active/en/resource/"
            "technical/document/release_note/DM00107009.pdf\n");
    }
    print("Output from the OpenOCD tool:");
    if (result.stdout.length == 0 || result.stderr.length == 0) {
      print("${result.stdout}");
      print("${result.stderr}");
    } else {
      print("STDOUT:\n${result.stdout}");
      print("STDERR:\n${result.stderr}");
    }
    return 1;
  }
  print("Done flashing image: ${image.path}");

  return 0;
}

Future<WorkerConnection> allocateWorker(IsolatePool pool) async {
  WorkerConnection workerConnection =
      new WorkerConnection(await pool.getIsolate(exitOnError: false));
  await workerConnection.beginSession();
  return workerConnection;
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
      StreamIterator<ClientCommand> commandIterator) {
    return invokeCombinedTasks(commandSender, commandIterator, task1, task2);
  }
}

Future<int> invokeCombinedTasks(
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator,
    SharedTask task1,
    SharedTask task2) async {
  int result = await task1(commandSender, commandIterator);
  if (result != 0) return result;
  return task2(commandSender, commandIterator);
}

Future<String> getAgentVersion(InternetAddress host, int port) async {
  SocketException connectionError = null;
  VmConnection vmConnection = await TcpConnection.connect(
      host,
      port,
      "getAgentVersionSocket",
      (String message) {},
      onConnectionError:
          (SocketException e) => connectionError = e);
  if (connectionError != null) return 'Error: no agent: $connectionError';
  try {
    AgentConnection connection = new AgentConnection(vmConnection);
    return await connection.dartinoVersion();
  } finally {
    vmConnection.close();
  }
}

Future<List<InternetAddress>> discoverDevices(
    {bool prefixWithNumber: false}) async {
  const ipV4AddressLength = 'xxx.xxx.xxx.xxx'.length;
  print("Looking for Dartino capable devices (will search for 5 seconds)...");
  MDnsClient client = new MDnsClient();
  await client.start();
  List<InternetAddress> result = <InternetAddress>[];
  String name = '_dartino_agent._tcp.local';
  await for (ResourceRecord ptr in client.lookup(RRType.PTR, name)) {
    String domain = ptr.domainName;
    await for (ResourceRecord srv in client.lookup(RRType.SRV, domain)) {
      String target = srv.target;
      await for (ResourceRecord a in client.lookup(RRType.A, target)) {
        InternetAddress address = a.address;
        if (!address.isLinkLocal) {
          result.add(address);
          String version = await getAgentVersion(address, AGENT_DEFAULT_PORT);
          String prefix = prefixWithNumber ? "${result.length}: " : "";
          print("${prefix}Device at "
                "${address.address.padRight(ipV4AddressLength + 1)} "
                "$target ($version)");
        }
      }
    }
    // TODO(karlklose): Verify that we got an A/IP4 result for the PTR result.
    // If not, maybe the cache was flushed before access and we need to query
    // for the SRV or A type again.
  }
  client.stop();
  return result;
}

void showSessions() {
  Sessions.names.forEach(print);
}

Future<int> showSessionSettings() async {
  Settings settings = SessionState.current.settings;
  Uri source = settings.source;
  if (source != null) {
    // This should output `source.toFilePath()`, but we do it like this to be
    // consistent with the format of the [Settings.packages] value.
    print('Configured from $source}');
  }
  settings.toJson().forEach((String key, value) {
    print('$key: $value');
  });
  return 0;
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

  List<String> compilerOptions;
  final Map<String, String> constants = <String, String>{};
  List<String> embedderOptions;

  Address deviceAddress;
  DeviceType deviceType;
  IncrementalMode incrementalMode = IncrementalMode.none;

  List<String> listOfStrings(value, String key, {bool restrictDashD: false}) {
    List<String> result = new List<String>();
    if (value != null) {
      if (value is! List) {
        throwFatalError(
            DiagnosticKind.settingsOptionsNotAList, uri: settingsUri,
            userInput: "$value",
            additionalUserInput: key);
      }
      for (var option in value) {
        if (option is! String) {
          throwFatalError(
              DiagnosticKind.settingsOptionNotAString, uri: settingsUri,
              userInput: '$option',
              additionalUserInput: key);
        }
        if (restrictDashD && option.startsWith("-D")) {
          throwFatalError(
              DiagnosticKind.settingsCompileTimeConstantAsOption,
              uri: settingsUri,
              userInput: '$option',
              additionalUserInput: key);
        }
        result.add(option);
      }
    }
    return result;
  }

  userSettings.forEach((String key, value) {
    switch (key) {
      case "packages":
        if (value != null) {
          if (value is! String) {
            throwFatalError(
                DiagnosticKind.settingsPackagesNotAString, uri: settingsUri,
                userInput: '$value');
          }
          packages = settingsUri.resolve(value);
        }
        break;

      case "options":
        throwFatalError(
            DiagnosticKind.optionsObsolete, uri: settingsUri,
            userInput: '$value');
        break;

      case "compiler_options":
        compilerOptions = listOfStrings(value, key, restrictDashD: true);
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

      case "embedder_options":
        embedderOptions = listOfStrings(value, key);
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
            throwFatalError(
                DiagnosticKind.settingsDeviceTypeNotAString,
                uri: settingsUri, userInput: '$value');
          }
          deviceType = parseDeviceType(value);
          if (deviceType == null) {
            throwFatalError(
                DiagnosticKind.settingsDeviceTypeUnrecognized,
                uri: settingsUri, userInput: '$value');
          }
        }
        break;

      case "incremental_mode":
        if (value != null) {
          if (value is! String) {
            throwFatalError(
                DiagnosticKind.settingsIncrementalModeNotAString,
                uri: settingsUri, userInput: '$value');
          }
          incrementalMode = parseIncrementalMode(value);
          if (incrementalMode == null) {
            throwFatalError(
                DiagnosticKind.settingsIncrementalModeUnrecognized,
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
  return new Settings.fromSource(
      settingsUri,
      packages,
      compilerOptions,
      constants,
      embedderOptions,
      deviceAddress,
      deviceType,
      incrementalMode);
}

class Settings {
  final Uri source;

  final Uri packages;

  final List<String> compilerOptions;

  final List<String> embedderOptions;

  final Map<String, String> constants;

  final Address deviceAddress;

  final DeviceType deviceType;

  final IncrementalMode incrementalMode;

  const Settings(
      this.packages,
      this.compilerOptions,
      this.constants,
      this.embedderOptions,
      this.deviceAddress,
      this.deviceType,
      this.incrementalMode) : source = null;

  const Settings.fromSource(
      this.source,
      this.packages,
      this.compilerOptions,
      this.constants,
      this.embedderOptions,
      this.deviceAddress,
      this.deviceType,
      this.incrementalMode);

  const Settings.empty()
      : this(null, const <String>[], const <String, String>{}, const<String>[],
          null, null, IncrementalMode.none);

  Settings copyWith({
      Uri packages,
      List<String> compilerOptions,
      Map<String, String> constants,
      List<String> vmOptions,
      Address deviceAddress,
      DeviceType deviceType,
      IncrementalMode incrementalMode}) {

    if (packages == null) {
      packages = this.packages;
    }
    if (compilerOptions == null) {
      compilerOptions = this.compilerOptions;
    }
    if (constants == null) {
      constants = this.constants;
    }
    if (vmOptions == null) {
      compilerOptions = this.compilerOptions;
    }
    if (deviceAddress == null) {
      deviceAddress = this.deviceAddress;
    }
    if (deviceType == null) {
      deviceType = this.deviceType;
    }
    if (incrementalMode == null) {
      incrementalMode = this.incrementalMode;
    }
    return new Settings(
        packages,
        compilerOptions,
        constants,
        vmOptions,
        deviceAddress,
        deviceType,
        incrementalMode);
  }

  String toString() {
    return "Settings("
        "packages: $packages, "
        "compiler_options: $compilerOptions, "
        "constants: $constants, "
        "embedder_options: $embedderOptions, "
        "device_address: $deviceAddress, "
        "device_type: $deviceType, "
        "incremental_mode: $incrementalMode)";
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = <String, dynamic>{};

    void addIfNotNull(String name, value) {
      if (value != null) {
        result[name] = value;
      }
    }

    addIfNotNull("packages", packages == null ? null : "$packages");
    addIfNotNull("compiler_options", compilerOptions);
    addIfNotNull("constants", constants);
    addIfNotNull("embedder_options", embedderOptions);
    addIfNotNull("device_address", deviceAddress);
    addIfNotNull(
        "device_type",
        deviceType == null ? null : unParseDeviceType(deviceType));
    addIfNotNull(
        "incremental_mode",
        incrementalMode == null
            ? null : unparseIncrementalMode(incrementalMode));

    return result;
  }
}

Uri defaultSnapshotLocation(Uri script) {
  // TODO(sgjesse): Use a temp directory for the snapshot.
  String snapshotName = basenameWithoutExtension(script.path) + '.snapshot';
  return script.resolve(snapshotName);
}
