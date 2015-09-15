// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:convert' show UTF8;
import 'dart:fletch';
import 'dart:fletch.io';
import 'dart:fletch.ffi';
import 'dart:typed_data';
import 'dart:fletch.os';

import '../lib/messages.dart';

class Logger {
  final String _prefix;
  final String _path;
  final bool _logToStdout;

  factory Logger(String prefix, String path, {stdout: true}) {
    if (!path.endsWith('/')) {
      path = '${path}/';
    }
    if (!File.existsAsFile(path)) {
      throw 'Cannot create logger at path: $path';
    }
    path = path + 'agent.log';
    return new Logger._(prefix, path, stdout);
  }

  const Logger._(this._prefix, this._path, this._logToStdout);

  void info(String msg) => _write('$_prefix INFO: $msg');
  void warn(String msg) => _write('$_prefix WARNING: $msg');
  void error(String msg) => _write('$_prefix ERROR: $msg');

  void _write(String msg) {
    File log;
    try {
      msg  = '${new DateTime.now().toString()} $msg';
      if (_logToStdout) {
        print(msg);
      }
      log = new File.open(_path, mode: File.APPEND);
      var encoded = UTF8.encode('$msg\n');
      var data = new Uint8List.fromList(encoded);
      log.write(data.buffer);
    } finally {
      if (log != null) log.close();
    }
  }
}

class AgentContext {
  final String vmBinPath;
  final String vmLogDir;
  final String vmPidDir;
  final Logger logger;

  const AgentContext(
      this.vmBinPath, this.vmLogDir, this. vmPidDir, this.logger);
}

class Agent {
  final String host;
  final int port;
  final AgentContext _context;
  final Logger _logger;

  Agent(this.host, this.port, String vmBinPath, String vmLogDir,
      String vmPidDir, Logger logger)
      : _logger = logger,
        _context = new AgentContext(vmBinPath, vmLogDir, vmPidDir, logger);

  void start() {
    _logger.info('starting server on $host:$port');
    var socket = new ServerSocket(host, port);
    // We have to make a final reference to the context to not have the
    // containing instance passed into the closure given to spawnAccept.
    final detachedContext = _context;
    while (true) {
      socket.spawnAccept((Socket s) => _handleCommand(s, detachedContext));
    }
    // We run until killed.
  }

  static void _handleCommand(Socket socket, AgentContext context) {
    try {
      var handler = new CommandHandler(socket, context);
      handler.run();
    } catch (error) {
      context.logger.warn('Caught error: $error. Closing socket');
      socket.close();
    }
  }
}

class CommandHandler {
  static const int SIGTERM = 15;
  static final ForeignFunction _kill = ForeignLibrary.main.lookup('kill');

  final Socket _socket;
  final AgentContext _context;
  RequestHeader _requestHeader;

  factory CommandHandler(Socket socket, AgentContext context) {
    var bytes = socket.read(RequestHeader.WIRE_SIZE);
    if (bytes == null || bytes.lengthInBytes < RequestHeader.WIRE_SIZE) {
      throw 'Insufficient bytes (${bytes.length}) received in request.';
    }
    var header = new RequestHeader.fromBuffer(bytes);
    return new CommandHandler._(socket, context, header);
  }

  CommandHandler._(this._socket, this._context, this._requestHeader);

  void run() {
    if (_requestHeader.version > AGENT_VERSION) {
      _context.logger.warn('Received message with unsupported version '
          '${_requestHeader.version} and command ${_requestHeader.command}');
      _sendReply(ReplyHeader.UNSUPPORTED_VERSION, null);
    }
    switch (_requestHeader.command) {
      case RequestHeader.START_VM:
        _startVm();
        break;
      case RequestHeader.STOP_VM:
        _stopVm();
        break;
      case RequestHeader.LIST_VMS:
        _listVms();
        break;
      case RequestHeader.UPGRADE_VM:
        _upgradeVm();
        break;
      case RequestHeader.FLETCH_VERSION:
        _fletchVersion();
        break;
      default:
        _context.logger.warn('Unknown command: ${_requestHeader.command}.');
        _sendReply(ReplyHeader.UNKNOWN_COMMAND, null);
        break;
    }
  }

  void _sendReply(int result, ByteBuffer payload) {
    var replyHeader = new ReplyHeader(_requestHeader.id, result);
    _socket.write(replyHeader.toBuffer);
    if (payload != null) {
      _socket.write(payload);
    }
    _socket.close();
  }

  void _startVm() {
    int result = ReplyHeader.SUCCESS;
    ByteBuffer replyPayload;
    try {
      int vmId  = NativeProcess.startDetached(_context.vmBinPath, null);
      replyPayload = new Uint16List(2).buffer;
      writeUint16(replyPayload, 0, vmId);
      // TODO(wibling): the -1 should be the vm's port.
      writeUint16(replyPayload, 2, -1);
      _context.logger.info('Started fletch vm with pid $vmId');
    } catch (e) {
      result = ReplyHeader.START_VM_FAILED;
      replyPayload = null;
      // TODO(wibling): could extend the result with caught error string.
      _context.logger.warn('Failed to start vm with error: $e');
    }
    _sendReply(result, replyPayload);
  }

  void _stopVm() {
    int result;
    // Read in the vm id. It is only the first 2 bytes of the data sent.
    var pidBytes = _socket.read(4);
    if (pidBytes == null) {
      result = ReplyHeader.INVALID_PAYLOAD;
      _context.logger.warn('Missing pid of the fletch vm to stop.');
    } else {
      // The vm id (aka. pid) is the first 2 bytes of the data sent.
      int pid = readUint16(pidBytes, 0);
      int err = _kill.icall$2(pid, SIGTERM);
      if (err != 0) {
        result = ReplyHeader.UNKNOWN_VM_ID;
        _context.logger.warn(
            'Failed to stop pid $pid with error: ${Foreign.errno}');
      } else {
        result = ReplyHeader.SUCCESS;
        _context.logger.info('Stopped pid: $pid');
      }
    }
    _sendReply(result, null);
  }

  void _listVms() {
    // TODO(wibling): implement this method.
    var payload = new Uint32List(4).buffer;
    // The number of vms (3) is the first 4 bytes of the payload.
    writeUint32(payload, 0, 3);
    // The actual vm id and port pairs follow (here we hardcode 3 pairs).
    int offset = 4;
    for (int i = 0; i < 3; ++i) {
      int vmId = (i+2) * 1234;
      int vmPort = (i+3) * 5432;
      _context.logger.info('Found VM with id: $vmId, port: $vmPort');
      writeUint16(payload, offset, vmId);
      offset += 2;
      writeUint16(payload, offset,  vmPort);
      offset += 2;
    }
    _sendReply(ReplyHeader.SUCCESS, payload);
  }

  void _upgradeVm() {
    int result;
    // TODO(wibling): implement this method.
    // Read the length of the vm binary data.
    ByteBuffer lengthBytes = _socket.read(4);
    if (lengthBytes == null) {
      result = ReplyHeader.INVALID_PAYLOAD;
      _context.logger.warn('Missing length in upgradeVm message.');
    } else {
      var length = readUint32(lengthBytes, 0);
      // TODO(wibling); stream the bytes from the socket to file and swap with
      // current vm binary.
      _context.logger.warn('Reading $length bytes and updating VM binary.');
      var binary = _socket.read(length);
      result = ReplyHeader.SUCCESS;
    }
    _sendReply(result, null);
  }

  void _fletchVersion() {
    // TODO(wibling): implement this method, for now version is hardcoded to 1.
    var payload = new Uint32List(1).buffer;
    int version = 1;
    writeUint32(payload, 0, version);
    _context.logger.warn('Returning fletch version $version');
    _sendReply(ReplyHeader.SUCCESS, payload);
  }
}

void main(List<String> arguments) {
  // Startup the agent listening on specified port.

  // TODO(wibling): the below should be command line arguments, but passing
  // arguments to a fletch programs is not currently supported, so hardcoding
  // for now.
  int port = 12121;
  String host = '0.0.0.0';
  String vmBinPath = '/usr/local/google/home/wibling/fletch/fletch-vm';
  String vmLogDir = '/var/log/fletch/';
  String vmPidDir = '/var/run/fletch';  // no end / to check code works

  var logger = new Logger('Agent', vmLogDir);
  logger.info('Vm path: $vmBinPath');
  logger.info('Log path: $vmLogDir');
  logger.info('Run path: $vmPidDir');

  for (var argument in arguments) {
    var parts = argument.split('=');
    if (parts[0] == '--port') {
      if (parts.length != 2) {
        print('Invalid flag: $argument\n');
        printUsage();
      }
      port = int.parse(parts[1]);
    } else if (parts[0] == '--host') {
      if (parts.length != 2) {
        print('Invalid flag: $argument\n');
        printUsage();
      }
      host = parts[1];
    } else if (parts[0] == '--vm') {
      if (parts.length != 2) {
        print('Invalid flag: $argument\n');
        printUsage();
      }
      vmBinPath = parts[1];
    }
  }
  // Make sure we have a fletch-vm binary we can use for launching a vm.
  if (!File.existsAsFile(vmBinPath)) {
    logger.error('Cannot find fletch vm at path: $vmBinPath');
    Process.exit();
  }
  // Make sure we have a valid log directory.
  if (!File.existsAsFile(vmLogDir)) {
    logger.error('Cannot find log directory: $vmLogDir');
    Process.exit();
  }
  // Make sure we have a valid pid directory.
  if (!File.existsAsFile(vmPidDir)) {
    logger.error('Cannot find directory: $vmPidDir in which to write pid');
    Process.exit();
  }

  // Run fletch agent on given host address and port.
  var agent = new Agent(host, port, vmBinPath, vmLogDir, vmPidDir, logger);
  agent.start();
}

void printUsage() {
  print('Usage:');
  print('The Fletch agent supports the following flags');
  print('');
  print('  --port: specify the port on which to listen, default: 12121');
  print('  --host: specify the ip address on which to listen, default: 0.0.0.0');
  print('  --vm: specify the path to the vm binary, default: /opt/fletch/bin/fletch-vm.');
  print('');
  Process.exit();
}
