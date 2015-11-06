// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch_agent.client;

import 'dart:io';
import 'dart:typed_data';

import '../lib/messages.dart';
import '../lib/agent_connection.dart';

void printUsage() {
  print('''
Usage:
The Fletch agent command line client supports the following flags:

  --port:   the port on which to connect, default: 12121
  --host:   the ip address on which to connect, default: 127.0.0.1
  --cmd:    the command to send to the Fletch agent, default: 0 (START_VM)
  --pid:    the pid of the vm to stop, only used when --cmd=1 (STOP_VM)
  --signal: which signal to send to the vm. Requires the --pid option to
            be specified
  --pkg:    path to the package file to be used with --cmd=3 (UPGRADE_PKG)

Example: Get the version of the agent running on 192.168.1.1:
  dart client.dart --cmd=4 --host=192.168.1.1.''');
  exit(1);
}

/// Small dart program to issue commands to the fletch agent.
void main(List<String> arguments) async {
  // Startup the agent listening on specified port.
  int port = 12121;
  String host = '127.0.0.1';
  int cmd = RequestHeader.START_VM;
  int id = 1; // The default id used.
  int pid;
  int signal;
  Socket socket;
  String packageFile;

  void checkSuccess(ReplyHeader header) {
    if (header == null) {
      print('Received invalid reply. Could not parse header.');
      socket.close();
      exit(1);
    }
    if (header.id != id) {
      print('Received out of sync message. Expected id $id and got '
            'id ${header.id}');
      socket.close();
      exit(1);
    }
    if (header.result != ReplyHeader.SUCCESS) {
      print('Received reply with id ${header.id} and result '
            '${header.result}');
      socket.close();
      exit(1);
    }
  }

  for (var argument in arguments) {
    var parts = argument.split('=');
    if (parts[0] == '--cmd') {
      if (parts.length != 2) {
        printUsage();
      }
      cmd = int.parse(parts[1]);
    } else if (parts[0] == '--id') {
      if (parts.length != 2) {
        printUsage();
      }
      id = int.parse(parts[1]);
    } else if (parts[0] == '--pid') {
      if (parts.length != 2) {
        printUsage();
      }
      pid = int.parse(parts[1]);
    } else if (parts[0] == '--host') {
      if (parts.length != 2) {
        printUsage();
      }
      host = parts[1];
    } else if (parts[0] == '--port') {
      if (parts.length != 2) {
        printUsage();
      }
      port = int.parse(parts[1]);
    } else if (parts[0] == '--signal') {
      if (parts.length != 2) {
        printUsage();
      }
      signal = int.parse(parts[1]);
    } else if (parts[0] == '--pkg') {
      if (parts.length != 2) {
        printUsage();
      }
      packageFile = parts[1];
    }
  }

  try {
    socket = await Socket.connect(host, port);
  } on SocketException catch (error) {
    print('Could not connect to Fletch Agent on \'$host:$port\'. '
        'Received error: $error');
    printUsage();
  }

  var connection = new AgentConnection(socket);
  switch (cmd) {
    case RequestHeader.START_VM:
      VmData vmData = await connection.startVm();
      print('Started VM: id=${vmData.id}, port=${vmData.port}');
      break;
    case RequestHeader.STOP_VM:
      if (pid == null) {
        print('Please specify which pid to stop with --pid=<pid>');
        exit(1);
      }
      await connection.stopVm(pid);
      print('Stopped VM: id=$pid');
      break;
    case RequestHeader.LIST_VMS:
      await connection.listVms();
      break;
    case RequestHeader.UPGRADE_AGENT:
      if (packageFile == null) {
        print('Please specify the path to the package with --pkg=<path>');
        exit(1);
      }
      Uri packageUri = new Uri.file(packageFile);
      List<String> nameParts = packageUri.pathSegments.last.split('_');
      if (nameParts.length != 3 || nameParts[0] != 'fletch-agent') {
        print('A fletch-agent package must have a name of the form\n'
            '  fletch-agent_<version>_<platform>');
        exit(1);
      }
      String version = nameParts[1];
      List<int> data = await new File(packageFile).readAsBytes();
      print('Sending package for version $version'
          ' (length: ${data.length} bytes).');
      await connection.upgradeAgent(version, data);
      print('Update finished');
      break;
    case RequestHeader.FLETCH_VERSION:
      int version = await connection.fletchVersion();
      print('Fletch Agent Version $version');
      break;
    case RequestHeader.SIGNAL_VM:
      if (pid == null) {
        print('Please specify which pid to stop with --pid=<pid>');
        printUsage();
        exit(1);
      }
      if (signal == null) {
        print('Please specify the signal to send to pid.');
        printUsage();
        exit(1);
      }
      await connection.signalVm(pid, signal);
      print('Send signal $signal to VM: id=$pid');
      break;
    default:
      print('Invalid command: $cmd');
      exit(1);
  }
  socket.close();
}
