// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch_agent.agent;

import 'dart:convert' show UTF8;
import 'dart:fletch';
import 'dart:fletch.ffi';
import 'dart:fletch.os';
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:socket/socket.dart';

import '../lib/messages.dart';

class Logger {
  final String _prefix;
  final String _path;
  final bool _logToStdout;

  factory Logger(String prefix, String logPath, {stdout: true}) {
    return new Logger._(prefix, logPath, stdout);
  }

  const Logger._(this._prefix, this._path, this._logToStdout);

  void info(String msg) => _write('$_prefix INFO: $msg');
  void warn(String msg) => _write('$_prefix WARNING: $msg');
  void error(String msg) => _write('$_prefix ERROR: $msg');

  void _write(String msg) {
    msg  = '${new DateTime.now().toString()} $msg';
    if (_logToStdout) {
      print(msg);
    }
    File log;
    try {
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
  static final ForeignFunction _getenv = ForeignLibrary.main.lookup('getenv');

  static String _getEnv(String varName) {
    ForeignPointer ptr;
    var arg;
    try {
      arg = new ForeignMemory.fromStringAsUTF8(varName);
      ptr = _getenv.pcall$1(arg);
    } finally {
      arg.free();
    }
    if (ptr.address == 0) return null;
    var cstring = new ForeignCString.fromForeignPointer(ptr);
    return cstring.toString();
  }

  // Agent specific info.
  final String ip;
  final int    port;
  final String pidFile;
  final Logger logger;

  // Fletch-vm path and args.
  final String vmBinPath;
  final String vmLogDir;
  final String vmPidDir;

  factory AgentContext() {
    String ip = _getEnv('AGENT_IP');
    if (ip == null) {
      ip = '0.0.0.0';
    }
    int port;
    try {
      String portStr = _getEnv('AGENT_PORT');
      port = int.parse(portStr);
    } catch (_) {
      port = AGENT_DEFAULT_PORT; // default
    }
    String logFile = _getEnv('AGENT_LOG_FILE');
    if (logFile == null) {
      print('Agent requires a valid log file. Please specify file path in '
          'the AGENT_LOG_FILE environment variable.');
      Process.exit();
    }
    var logger = new Logger('Agent', logFile);
    String pidFile = _getEnv('AGENT_PID_FILE');
    if (pidFile == null) {
      logger.error('Agent requires a valid pid file. Please specify file path '
          'in the AGENT_PID_FILE environment variable.');
      Process.exit();
    }
    String vmBinPath = _getEnv('FLETCH_VM');
    String vmLogDir = _getEnv('VM_LOG_DIR');
    String vmPidDir = _getEnv('VM_PID_DIR');

    logger.info('Agent log file: $logFile');
    logger.info('Agent pid file: $pidFile');
    logger.info('Vm path: $vmBinPath');
    logger.info('Log path: $vmLogDir');
    logger.info('Run path: $vmPidDir');

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
    return new AgentContext._(
        ip, port, pidFile, logger, vmBinPath, vmLogDir, vmPidDir);
  }

  const AgentContext._(this.ip, this.port, this.pidFile, this.logger,
      this.vmBinPath, this.vmLogDir, this. vmPidDir);
}

class Agent {
  final AgentContext _context;

  Agent(this._context);

  void start() {
    var ip = _context.ip;
    var port = _context.port;
    _context.logger.info('starting server on $ip:$port');
    var socket = new ServerSocket(ip, port);
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
  static const int SIGHUB = 1;
  static const int SIGINT = 2;
  static const int SIGQUIT = 3;
  static const int SIGKILL = 9;
  static const int SIGTERM = 15;
  static const List<int> TERMINATION_SIGNALS =
      const [SIGHUB, SIGINT, SIGQUIT, SIGKILL, SIGTERM];
  static final ForeignFunction _kill = ForeignLibrary.main.lookup('kill');
  static final ForeignFunction _unlink = ForeignLibrary.main.lookup('unlink');

  final Socket _socket;
  final AgentContext _context;
  RequestHeader _requestHeader;

  factory CommandHandler(Socket socket, AgentContext context) {
    var bytes = socket.read(RequestHeader.HEADER_SIZE);
    if (bytes == null) {
      throw 'Connection closed by peer';
    } else if (bytes.lengthInBytes < RequestHeader.HEADER_SIZE) {
      throw 'Insufficient bytes ($bytes.lengthInBytes) received in request';
    }
    var header = new RequestHeader.fromBuffer(bytes);
    return new CommandHandler._(socket, context, header);
  }

  CommandHandler._(this._socket, this._context, this._requestHeader);

  void run() {
    if (_requestHeader.version > AGENT_VERSION) {
      _context.logger.warn('Received message with unsupported version '
          '${_requestHeader.version} and command ${_requestHeader.command}');
      _sendReply(
          new ReplyHeader(_requestHeader.id, ReplyHeader.UNSUPPORTED_VERSION));
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
      case RequestHeader.SIGNAL_VM:
        _signalVm();
        break;
      default:
        _context.logger.warn('Unknown command: ${_requestHeader.command}.');
        _sendReply(
            new ReplyHeader(_requestHeader.id, ReplyHeader.UNKNOWN_COMMAND));
        break;
    }
  }

  void _sendReply(ReplyHeader reply) {
    _socket.write(reply.toBuffer());
    _socket.close();
  }

  void _startVm() {
    int vmPid = 0;
    var reply;
    try {
      List<String> args = ['--log-dir=${_context.vmLogDir}',
          '--run-dir=${_context.vmPidDir}', '--host=0.0.0.0'];
      vmPid = NativeProcess.startDetached(_context.vmBinPath, args);
      // Find out what port the vm is listening on.
      int port = _retrieveVmPort(vmPid);
      reply = new StartVmReply(
          _requestHeader.id, ReplyHeader.SUCCESS, vmId: vmPid, vmPort: port);
      _context.logger.info('Started fletch vm with pid $vmPid on port $port');
    } catch (e) {
      reply = new StartVmReply(_requestHeader.id, ReplyHeader.START_VM_FAILED);
      // TODO(wibling): could extend the result with caught error string.
      _context.logger.warn('Failed to start vm with error: $e');
      if (vmPid > 0) {
        // Kill the vm and remove any pid and port files.
        _kill.icall$2(vmPid, SIGTERM);
        _cleanUpVm(vmPid);
      }
    }
    _sendReply(reply);
  }

  int _retrieveVmPort(int vmPid) {
    String portPath = '${_context.vmPidDir}/vm-$vmPid.port';
    _context.logger.info('Reading port from $portPath for vm $vmPid');

    // The fletch-vm will write the port it is listening on into the file
    // specified by 'portPath' above. The agent waits for the file to be
    // created (retries the File.open until it succeeds) and then reads the
    // port from the file.
    // To make sure we are reading a consistent value from the file, ie. the
    // vm could have written a partial value at the time we read it, we continue
    // reading the value from the file until we have read the same value from
    // file in two consecutive reads.
    // An alternative to the consecutive reading would be to use cooperative
    // locking, but consecutive reading is not relying on the fletch-vm to
    // behave.
    // TODO(wibling): Look into passing a socket port to the fletch-vm and
    // have it write the port to the socket. This allows the agent to just
    // wait on the socket and wake up when it is ready.
    int previousPort = -1;
    var lastException;
    for (int retries = 500; retries >= 0; --retries) {
      int port = _tryReadPort(portPath, retries == 0);
      // Check if we read the same port value twice in a row.
      if (previousPort != -1 && previousPort == port) return port;
      previousPort = port;
      sleep(10);
    }
    throw 'Failed to read port for vm $vmPid';
  }

  int _tryReadPort(String portPath, bool lastAttempt) {
    File portFile;
    var data;
    try {
      portFile = new File.open(portPath);
      data = portFile.read(10);
    } on FileException catch (_) {
      if (lastAttempt) rethrow;
      return -1;
    } finally {
      if (portFile != null) portFile.close();
    }
    try {
      if (data.lengthInBytes > 0) {
        var portString = UTF8.decode(data.asUint8List().toList());
        return int.parse(portString);
      }
    } on FormatException catch (_) {
      if (lastAttempt) rethrow;
    }
    // Retry if no data was read.
    return -1;
  }

  void _stopVm() {
    if (_requestHeader.payloadLength != 4) {
      _sendReply(
          new StopVmReply(_requestHeader.id, ReplyHeader.INVALID_PAYLOAD));
      return;
    }
    var reply;
    // Read in the vm id. It is only the first 2 bytes of the data sent.
    var pidBytes = _socket.read(4);
    if (pidBytes == null) {
      reply = new StopVmReply(_requestHeader.id, ReplyHeader.INVALID_PAYLOAD);
      _context.logger.warn('Missing pid of the fletch vm to stop.');
    } else {
      // The vm id (aka. pid) is the first 2 bytes of the data sent.
      int pid = readUint16(pidBytes, 0);
      int err = _kill.icall$2(pid, SIGTERM);
      if (err != 0) {
        reply = new StopVmReply(_requestHeader.id, ReplyHeader.UNKNOWN_VM_ID);
        _context.logger.warn(
            'Failed to stop pid $pid with error: ${Foreign.errno}');
      } else {
        reply = new StopVmReply(_requestHeader.id, ReplyHeader.SUCCESS);
        _context.logger.info('Stopped pid: $pid');
      }
      // Always clean up independent of errors.
      _cleanUpVm(pid);
    }
    _sendReply(reply);
  }

  void _signalVm() {
    if (_requestHeader.payloadLength != 4) {
      _sendReply(
          new SignalVmReply(_requestHeader.id, ReplyHeader.INVALID_PAYLOAD));
      return;
    }
    var reply;
    // Read in the vm id and the signal to send.
    var pidBytes = _socket.read(4);
    if (pidBytes == null) {
      reply = new SignalVmReply(_requestHeader.id, ReplyHeader.INVALID_PAYLOAD);
      _context.logger.warn('Missing pid of the fletch vm to signal.');
    } else {
      int pid = readUint16(pidBytes, 0);
      int signal = readUint16(pidBytes, 2);
      // TODO(wibling): Hack to make ctrl-c work for stopping spawed vms work
      // on Raspbian wheezy. For some unknown reason SIGINT doesn't work so we
      // map SIGINT to SIGTERM as a workaround.
      int err = _kill.icall$2(pid, signal == 2 ? 15 : signal);
      if (err != 0) {
        reply = new SignalVmReply(_requestHeader.id, ReplyHeader.UNKNOWN_VM_ID);
        _context.logger.warn('Failed to send signal $signal to  pid $pid with '
            'error: ${Foreign.errno}');
      } else {
        reply = new SignalVmReply(_requestHeader.id, ReplyHeader.SUCCESS);
        _context.logger.info('Sent signal $signal to pid: $pid');
        // Only cleanup if a termination signal was delivered.
        if (TERMINATION_SIGNALS.contains(signal)) {
          _cleanUpVm(pid);
        }
      }
    }
    _sendReply(reply);
  }

  void _cleanUpVm(int pid) {
    var portPath;
    var pidPath;
    try {
      String fileName = '${_context.vmPidDir}/vm-$pid.port';
      portPath = new ForeignMemory.fromStringAsUTF8(fileName);
      _unlink.icall$1(portPath);
      fileName = '${_context.vmPidDir}/vm-$pid.pid';
      pidPath = new ForeignMemory.fromStringAsUTF8(fileName);
      _unlink.icall$1(pidPath);
    } finally {
      if (portPath != null) portPath.free();
      if (pidPath != null) pidPath.free();
    }
  }

  void _listVms() {
    // TODO(wibling): implement this method. For now just hardcode some values.
    _sendReply(
        new ListVmsReply(_requestHeader.id, ReplyHeader.UNKNOWN_COMMAND));
  }

  void _upgradeVm() {
    int result;
    // TODO(wibling): implement this method.
    var binary = _socket.read(_requestHeader.payloadLength);
    if (binary == null) {
      _context.logger.warn(
          'Could not read VM binary of length ${_requestHeader.payloadLength}');
      result = ReplyHeader.INVALID_PAYLOAD;
    } else {
      // TODO(wibling); stream the bytes from the socket to file and swap with
      // current vm binary. For now we just return UNKNOWN_COMMAND.
      _context.logger.warn('Read VM binary of ${binary.lengthInBytes} bytes.');
      result = ReplyHeader.UNKNOWN_COMMAND;
    }
    _sendReply(new UpgradeVmReply(_requestHeader.id, result));
  }

  void _fletchVersion() {
    // TODO(wibling): implement this method, for now version is hardcoded to 1.
    int version = 1;
    _context.logger.warn('Returning fletch version $version');
    _sendReply(new FletchVersionReply(
        _requestHeader.id, ReplyHeader.SUCCESS, fletchVersion: version));
  }
}

void main(List<String> arguments) {
  // The agent context will initialize itself from the runtime environment.
  var context = new AgentContext();

  // Write the program's pid to the pid file if set.
  _writePid(context.pidFile);

  // Run fletch agent on given ip address and port.
  var agent = new Agent(context);
  agent.start();
}

void _writePid(String pidFilePath) {
  final ForeignFunction _getpid = ForeignLibrary.main.lookup('getpid');

  int pid = _getpid.icall$0();
  List<int> encodedPid = UTF8.encode('$pid');
  ByteBuffer buffer = new Uint8List.fromList(encodedPid).buffer;
  var pidFile = new File.open(pidFilePath, mode: File.WRITE);
  try {
    pidFile.write(buffer);
  } finally {
    pidFile.close();
  }
}

void printUsage() {
  print('Usage:');
  print('The Fletch agent supports the following flags');
  print('');
  print('  --port: specify the port on which to listen, default: '
      '$AGENT_DEFAULT_PORT');
  print('  --ip: specify the ip address on which to listen, default: 0.0.0.0');
  print('  --vm: specify the path to the vm binary, default: '
      '/opt/fletch/bin/fletch-vm.');
  print('');
  Process.exit();
}
