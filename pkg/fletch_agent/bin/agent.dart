// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch_agent.agent;

import 'dart:convert' show UTF8;
import 'dart:fletch';
import 'dart:fletch.ffi';
import 'dart:fletch.os' as os;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:file/file.dart';
import 'package:fletch/fletch.dart' as fletch;
import 'package:os/os.dart' show sys;
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
    return cStringToString(ptr);
  }

  // Agent specific info.
  final String ip;
  final int    port;
  final String pidFile;
  final Logger logger;
  final bool applyUpgrade;

  // Fletch-vm path and args.
  final String vmBinPath;
  final String vmLogDir;
  final String tmpDir;

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
    String tmpDir = _getEnv('TMPDIR');
    if (tmpDir == null) tmpDir = '/tmp';

    // If the below ENV variable is set the agent will just store the agent
    // debian package but not apply it.
    bool applyUpgrade = _getEnv('AGENT_UPGRADE_DRY_RUN') == null;

    logger.info('Agent log file: $logFile');
    logger.info('Agent pid file: $pidFile');
    logger.info('Vm path: $vmBinPath');
    logger.info('Log path: $vmLogDir');

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
    return new AgentContext._(
        ip, port, pidFile, logger, vmBinPath, vmLogDir, tmpDir, applyUpgrade);
  }

  const AgentContext._(
      this.ip, this.port, this.pidFile, this.logger, this.vmBinPath,
      this.vmLogDir, this.tmpDir, this.applyUpgrade);
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
      case RequestHeader.UPGRADE_AGENT:
        _upgradeAgent();
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
    // Create a tmp file for reading the port the vm is listening on.
    File portFile = new File.temporary("${_context.tmpDir}/vm-port-");
    try {
      List<String> args = ['--log-dir=${_context.vmLogDir}',
          '--port-file=${portFile.path}', '--host=0.0.0.0'];
      vmPid = os.NativeProcess.startDetached(_context.vmBinPath, args);
      // Find out what port the vm is listening on.
      _context.logger.info('Reading port from ${portFile.path} for vm $vmPid');
      int port = _retrieveVmPort(portFile.path);
      reply = new StartVmReply(
          _requestHeader.id, ReplyHeader.SUCCESS, vmId: vmPid, vmPort: port);
      _context.logger.info('Started fletch vm with pid $vmPid on port $port');
    } catch (e) {
      reply = new StartVmReply(_requestHeader.id, ReplyHeader.START_VM_FAILED);
      // TODO(wibling): could extend the result with caught error string.
      _context.logger.warn('Failed to start vm with error: $e');
      if (vmPid > 0) {
        // Kill the vm.
        _kill.icall$2(vmPid, SIGTERM);
      }
    } finally {
      File.delete(portFile.path);
    }
    _sendReply(reply);
  }

  int _retrieveVmPort(String portPath) {
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
    for (int retries = 500; retries >= 0; --retries) {
      int port = _tryReadPort(portPath, retries == 0);
      // Check if we read the same port value twice in a row.
      if (previousPort != -1 && previousPort == port) return port;
      previousPort = port;
      os.sleep(10);
    }
    throw 'Failed to read port from $portPath';
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
    // Read in the vm id.
    var pidBytes = _socket.read(4);
    if (pidBytes == null) {
      reply = new StopVmReply(_requestHeader.id, ReplyHeader.INVALID_PAYLOAD);
      _context.logger.warn('Missing pid of the fletch vm to stop.');
    } else {
      int pid = readUint32(pidBytes, 0);
      int err = _kill.icall$2(pid, SIGTERM);
      if (err != 0) {
        reply = new StopVmReply(_requestHeader.id, ReplyHeader.UNKNOWN_VM_ID);
        _context.logger.warn(
            'Failed to stop pid $pid with error: ${Foreign.errno}');
      } else {
        reply = new StopVmReply(_requestHeader.id, ReplyHeader.SUCCESS);
        _context.logger.info('Stopped pid: $pid');
      }
    }
    _sendReply(reply);
  }

  void _signalVm() {
    if (_requestHeader.payloadLength != 8) {
      _sendReply(
          new SignalVmReply(_requestHeader.id, ReplyHeader.INVALID_PAYLOAD));
      return;
    }
    var reply;
    // Read in the vm id and the signal to send.
    var pidBytes = _socket.read(8);
    if (pidBytes == null) {
      reply = new SignalVmReply(_requestHeader.id, ReplyHeader.INVALID_PAYLOAD);
      _context.logger.warn('Missing pid of the fletch vm to signal.');
    } else {
      int pid = readUint32(pidBytes, 0);
      int signal = readUint32(pidBytes, 4);
      // Hack to make ctrl-c work for stopping spawned vms work on Raspbian
      // wheezy. For some reason SIGINT doesn't work so we map it to SIGTERM as
      // a workaround.
      if (signal == SIGINT && sys.info().release.startsWith('3.18')) {
        _context.logger.info('Remapping SIGINT to SIGTERM on Raspbian wheezy');
        signal = SIGTERM;
      }
      int err = _kill.icall$2(pid, signal);
      if (err != 0) {
        reply = new SignalVmReply(_requestHeader.id, ReplyHeader.UNKNOWN_VM_ID);
        _context.logger.warn('Failed to send signal $signal to  pid $pid with '
            'error: ${Foreign.errno}');
      } else {
        reply = new SignalVmReply(_requestHeader.id, ReplyHeader.SUCCESS);
        _context.logger.info('Sent signal $signal to pid: $pid');
      }
    }
    _sendReply(reply);
  }

  void _listVms() {
    // TODO(wibling): implement this method. For now just hardcode some values.
    _sendReply(
        new ListVmsReply(_requestHeader.id, ReplyHeader.UNKNOWN_COMMAND));
  }

  void _upgradeAgent() {
    int result;
    ByteBuffer binary = _socket.read(_requestHeader.payloadLength);
    if (binary == null) {
      _context.logger.warn('Could not read fletch-agent package binary'
          ' of length ${_requestHeader.payloadLength} bytes');
      result = ReplyHeader.INVALID_PAYLOAD;
    } else {
      _context.logger.info('Read fletch-agent package binary'
          ' of length ${binary.lengthInBytes} bytes.');
      File file = new File.open(PACKAGE_FILE_NAME, mode: File.WRITE);
      try {
        file.write(binary);
      } catch (e) {
        _context.logger.warn('UpgradeAgent failed: $e');
        _sendReply(new UpgradeAgentReply(_requestHeader.id,
                ReplyHeader.UPGRADE_FAILED));
      } finally {
        file.close();
      }
      _context.logger.info('Package file written successfully.');
      if (_context.applyUpgrade) {
        int pid = os.NativeProcess.startDetached('/usr/bin/dpkg',
            [// Force dpkg to overwrite configuration files installed by
             // the agent.
             '--force-confnew',
             '--install',
             PACKAGE_FILE_NAME]);
        _context.logger.info('started package update (PID $pid)');
      }
      result = ReplyHeader.SUCCESS;
    }
    _context.logger.info('sending reply');
    _sendReply(new UpgradeAgentReply(_requestHeader.id, result));
  }

  void _fletchVersion() {
    String version = fletch.version();
    _context.logger.info('Returning fletch version $version');
    _sendReply(new FletchVersionReply(
        _requestHeader.id, ReplyHeader.SUCCESS, version: version));
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
