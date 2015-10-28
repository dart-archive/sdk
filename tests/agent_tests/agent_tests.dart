// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' show
    Directory,
    File,
    FileSystemException,
    Process,
    ProcessSignal,
    Socket,
    SocketException;

import 'dart:convert' show
    LineSplitter,
    UTF8,
    Utf8Decoder;

import 'dart:async' show
    Future;

import 'package:expect/expect.dart' show
    Expect;

import 'package:fletch_agent/messages.dart' show
    AGENT_VERSION,
    PACKAGE_FILE_NAME;

import 'package:fletch_agent/agent_connection.dart' show
    AgentConnection,
    AgentException,
    VmData;

import 'package:fletchc/src/guess_configuration.dart' show
    executable;

import '../fletchc/run.dart' show
    export;

typedef Future NoArgFuture();

List<AgentTest> AGENT_TESTS = <AgentTest>[
  new AgentLifeCycleTest(),
  new AgentUpgradeProtocolTest(),
  new AgentUnsupportedCommandsTest(),
];

const String fletchVmExecutable = const String.fromEnvironment('fletch-vm');
const String buildDirectory =
    const String.fromEnvironment('test.dart.build-dir');
const int SIGINT = 2;

abstract class AgentTest {
  final String name;
  final String outputDirectory;
  final String host = '127.0.0.1';
  final int port;
  Process process;
  Future stdoutFuture;
  Future stderrFuture;
  Map<String, String> environment;

  /// Each agent test must be assigned a unique port on which the fletch agent
  /// for the specific test is listening. The port must be unique since the
  /// tests are run in parallel.
  AgentTest(String name, int port)
      : this.name = name,
        this.port = port,
        outputDirectory = '$buildDirectory/tests/$name' {
    environment = {
      'FLETCH_VM': fletchVmExecutable,
      'AGENT_IP': host,
      'AGENT_PORT': port.toString(),
      'AGENT_PID_FILE': '$outputDirectory/fletch-agent.pid',
      'AGENT_LOG_FILE': '$outputDirectory/fletch-agent.log',
      'VM_LOG_DIR': outputDirectory,
      'VM_PID_DIR': outputDirectory,
      'AGENT_UPGRADE_DRY_RUN': 'true',
    };
  }

  Future<Null> execute();

  void createOutputDirectory() {
    new Directory(outputDirectory).createSync(recursive: true);
  }

  void deleteOutputDirectory() {
    new Directory(outputDirectory).deleteSync(recursive: true);
  }

  Future<Null> createSnapshot() async {
    // Find the path to the fletch agent script.
    Uri script = executable.resolve('../../pkg/fletch_agent/bin/agent.dart');
    await export(script.toFilePath(), '$outputDirectory/fletch-agent.snapshot');
    print('Agent snapshot generated: $outputDirectory/fletch-agent.snapshot');
  }

  Future<Null> start() async {
    process = await Process.start(
        fletchVmExecutable,
        ['$outputDirectory/fletch-agent.snapshot'],
        environment: environment);
    stdoutFuture = process.stdout.transform(UTF8.decoder)
        .transform(new LineSplitter())
        .listen(print).asFuture();
    stderrFuture = process.stderr.transform(UTF8.decoder)
        .transform(new LineSplitter())
        .listen(print).asFuture();
    print('Running agent with pid ${process.pid}');
  }

  Future<AgentConnection> connect() async {
    int attempt = 0;
    Socket socket = await retry(1000, () => Socket.connect(host, port));
    Expect.isTrue(socket != null, 'Failed to connect to agent');
    return new AgentConnection(socket);
  }

  Future<Null> disconnect(AgentConnection connection) async {
    if (connection != null) {
      print('Disconnecting from agent on port ${connection.socket.port}');
      await connection.socket.destroy();
    }
  }

  Future<dynamic> withConnection(testMethod(AgentConnection connection)) async {
    AgentConnection connection = await connect();
    Expect.isNotNull(connection, 'Expected to be connected to agent');
    var result;
    try {
      result = await testMethod(connection);
    } finally {
      await disconnect(connection);
    }
    return result;
  }

  Future<Null> stop() async {
    if (process != null) {
      process.kill();
      await process.exitCode;
      await stdoutFuture;
      await stderrFuture;
    }
  }

  Future<Null> run() async {
    createOutputDirectory();
    await createSnapshot();
    try {
      await start();
      await execute();
    } finally {
      await stop();
      deleteOutputDirectory();
    }
  }
}

Future<Map<String, NoArgFuture>> listTests() async {
  var tests = <String, NoArgFuture>{};
  for (AgentTest test in AGENT_TESTS) {
    tests['agent_tests/${test.name}'] = test.run;
  }
  return tests;
}

class AgentLifeCycleTest extends AgentTest {
  AgentLifeCycleTest() : super('testAgentLifeCycle', 20000);

  Future<Null> execute() async {
    // Check the version.
    await withConnection((AgentConnection connection) async {
      int version = await connection.fletchVersion();
      Expect.equals(AGENT_VERSION, version, 'Mismatching agent version');
    });

    // Start a VM.
    VmData data;
    await withConnection((AgentConnection connection) async {
      data = await connection.startVm();
      Expect.isNotNull(data, 'Failed to spawn new fletch VM');
      Expect.isNotNull(data.id, 'Null is not a valid VM pid');
      Expect.notEquals(0, data.id, 'Invalid pid returned for VM');
      Expect.isNotNull(data.port, 'Null is not a valid VM port');
      Expect.notEquals(0, data.port, 'Invalid port returned for VM');
      // This will not work on Windows, since the ProcessSignal argument
      // is ignored and the fletch-vm is killed.
      Expect.isTrue(Process.killPid(data.id, ProcessSignal.SIGCONT),
          'Fletch vm not running');
      print('Started 1. VM with id ${data.id} on port ${data.port}.');
    });

    // Stop the spawned vm.
    await withConnection((AgentConnection connection) async {
      await connection.stopVm(data.id);
      Expect.isFalse(Process.killPid(data.id, ProcessSignal.SIGCONT),
          'Fletch vm still running');
      print('Stopped VM with id ${data.id} on port ${data.port}.');
    });

    // Start a new vm.
    await withConnection((AgentConnection connection) async {
      data = await connection.startVm();
      Expect.isNotNull(data, 'Failed to spawn new fletch VM');
      Expect.isNotNull(data.id, 'Null is not a valid VM pid');
      Expect.notEquals(0, data.id, 'Invalid pid returned for VM');
      Expect.isNotNull(data.port, 'Null is not a valid VM port');
      Expect.notEquals(0, data.port, 'Invalid port returned for VM');
      // This will not work on Windows, since the ProcessSignal argument
      // is ignored and the fletch-vm is killed.
      Expect.isTrue(Process.killPid(data.id, ProcessSignal.SIGCONT),
          'Fletch vm not running');
      print('Started 2. VM with id ${data.id} on port ${data.port}.');
    });

    // Kill the spawned vm using a signal.
    await withConnection((AgentConnection connection) async {
      await connection.signalVm(data.id, SIGINT);
      Expect.isFalse(Process.killPid(data.id, ProcessSignal.SIGCONT),
          'Fletch vm still running');
      print('Killed VM with id ${data.id} on port ${data.port}.');
    });
  }
}

/// The AgentUpgrade test sends over mock binary data (as List<int> data),
/// representing the new agent package that should be used to upgrade the
/// agent.
/// When running the test we start the fletch agent with AGENT_UPGRADE_DRY_RUN
/// set so it won't actually do the dpkg. This allows us to test that the
/// fletch agent correctly receives the mock data and writes it into the temp
/// package file.
class AgentUpgradeProtocolTest extends AgentTest {
  AgentUpgradeProtocolTest() : super('testAgentUpgrade', 20001);

  Future<Null> execute() async {
    await withConnection((AgentConnection connection) async {
      List<int> data = [72, 69, 76, 76, 79, 10];
      await connection.upgradeAgent('1-test', data);
      List<int> readData =
          await retry(20, () => new File(PACKAGE_FILE_NAME).readAsBytes());
      Expect.isTrue(readData != null, 'Failed to open agent upgrade package');
      Expect.equals(data.length, readData.length,
          'Expected exactly ${data.length} bytes of data');
      for (int i = 0; i < data.length; ++i) {
        Expect.equals(data[i], readData[i], 'Mismatched bytes');
      }
    });
  }
}

class AgentUnsupportedCommandsTest extends AgentTest {
  AgentUnsupportedCommandsTest() : super('testUnsupportedCommands', 20002);

  Future<Null> execute() async {
    await withConnection((AgentConnection connection) async {
      try {
        await connection.listVms();
      } catch (error) {
        Expect.isTrue(
            error is AgentException, 'Got incorrect exception: $error');
      }
    });
  }
}

Future retry(int retries, Future func()) async {
  var result = null;
  for (int attempt = 0; result == null && attempt < retries; ++attempt) {
    try {
      result = await func();
    } catch(e) {
      if (attempt < retries) {
        await new Future.delayed(new Duration(milliseconds: 5));
        continue;
      }
    }
  }
  return result;
}
