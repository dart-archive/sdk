// Copyright (c) 2014-2015, Nicolas François
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

part of serial_port;

// TODO FLOWCONTROLS

class SerialPort {

  static const int _TEST_PORT = 0;
  static const int _OPEN_METHOD = 1;
  static const int _CLOSE_METHOD = 2;
  static const int _READ_METHOD = 3;
  static const int _WRITE_METHOD = 4;
  static const int _WRITE_BYTE_METHOD = 5;

  // Name of device on which the connection is made
  final String portName;
  // Connexion speed
  final int baudrate;
  // Number of data bits in each character
  final int databits;
  // Method of detecting errors in transmission
  final Parity parity;
  // Bits sent at the end of every character allow the receiving signal hardware to detect the end of a character
  final StopBits stopBits;

  final StreamController<List<int>> _onReadController = new StreamController<List<int>>();

  int _ttyFd = -1;

  SerialPort(this.portName, {this.baudrate : 9600, this.databits: 8, this.parity: Parity.NONE, this.stopBits : StopBits.ONE});

  /// List all available port names
  static Future<List<String>> get availablePortNames async {
    final portNames = await _systemPortNames;
    final Iterable<Future<PortNameAvailability>> areAvailable = portNames.map(isAvailablePortName);
    final availability = await Future.wait(areAvailable);
    return availability.where((p) => p.isAvailable).map((p) => p.portName).toList();
  }

  /// List of potential portName depending for OS.
  static Future<List<String>> get _systemPortNames {
    if(Platform.isLinux || Platform.isMacOS) {
      final wildCard = Platform.isLinux ? "/dev/ttyS*": "/dev/*.*";
      return Process.run('/bin/sh', ['-c', 'ls $wildCard'])
                    .then((ProcessResult results) => results.stdout
                    .split('\n')
                    .where((String name) => name.isNotEmpty)
                    .toList());
    } else if(Platform.isWindows){
      final indexes = new List<int>.generate(9, (i) => i+1);
      return new Future.value(indexes.map((i) => "COM$i"));
    } else {
      throw new UnsupportedError("Cannot find serial port for this OS");
    }
  }

  /// Ask to system if a port name is available
  static Future<PortNameAvailability> isAvailablePortName(String portName) async {
    final replyPort = new ReceivePort();
     _servicePort.send([replyPort.sendPort, _TEST_PORT, portName, portName]);
    final result = await replyPort.first;
    if (result[0] == null) {
      return new PortNameAvailability(portName, result[1]);
    } else {
      return new PortNameAvailability(portName, false);
    }
  }

  /// Open the connection with serial port.
  Future open() async {
    if(isOpen){
      throw "$portName is yet open";
    }
    final replyPort = new ReceivePort();
    _servicePort.send([replyPort.sendPort, _OPEN_METHOD, portName, baudrate, databits, _parityCodes[parity], _stopBitsCodes[stopBits]]);
    final result = await replyPort.first;
    if (result[0] != null) {
      throw "Cannot open $portName : ${result[0]}";
    }
    _ttyFd = result[1];
    _read();
    return true;
  }


  /// Getter for open connection
  bool get isOpen => _ttyFd != -1;

  /// Getter for file descriptor (just for debug)
  int get fd => _ttyFd;

  /// Close the connection.
  Future close() async {
    _checkOpen();
    final replyPort = new ReceivePort();
    _servicePort.send([replyPort.sendPort, _CLOSE_METHOD, _ttyFd]);
    final result = await replyPort.first;
    _onReadController.close();
    if (result[0] != null) {
      throw "Cannot close $portName : ${result[0]}";
    }
    _ttyFd = -1;
    return true;
  }

  /// Write as a string
  Future writeString(String data) async {
    _checkOpen();
    final replyPort = new ReceivePort();
    _servicePort.send([replyPort.sendPort, _WRITE_METHOD, _ttyFd, data]);
    final result = await replyPort.first;
    if (result[0] != null) {
      throw "Cannot write in $portName : ${result[0]}";
    }
    return true;
  }

  /// Write bytes
  Future write(List<int> bytes){
    final writes = bytes.map((byte) => _writeOneByte(byte));
    return Future.wait(writes, eagerError: true).then((_) => true);
  }

  Future _writeOneByte(int byte) async {
    _checkOpen();
    final replyPort = new ReceivePort();
    _servicePort.send([replyPort.sendPort, _WRITE_BYTE_METHOD, _ttyFd, byte]);
    final result = await replyPort.first;
    if (result[0] != null) {
      throw "Cannot write in $portName : ${result[0]}";
    }
    return true;
  }

  /// Read data send from the serial port
  Stream<List<int>> get onRead => _onReadController.stream;

  _checkOpen() {
    if (!isOpen) {
      throw "$portName is not open";
    }
  }

  void _read(){
    if(isOpen){
      final _readPort = new ReceivePort();
      _servicePort.send([_readPort.sendPort, _READ_METHOD, _ttyFd, 256]);
      _readPort.first.then((List result){
        if (result[0] == null && result[1] != null && !_onReadController.isClosed) {
          _onReadController.add(result[1]);
        }
        // Continue to read
        _read();
      });
    }
  }

  // Communication with native part

  static SendPort _port;

  static SendPort get _servicePort {
    if (_port == null) {
      _port = _newServicePort();
    }
    return _port;
  }

  static SendPort _newServicePort() native "serialPortServicePort";

}

/// Wrap a port name and it available result;
class PortNameAvailability {
  final String portName;
  final bool isAvailable;

  PortNameAvailability(this.portName, this.isAvailable);
}

/// Type of stop bits
enum StopBits { ONE, TWO /*ONE5STOPBITS*/ }
/// Type of parity
enum Parity {NONE, EVEN, ODD}

final _stopBitsCodes = {StopBits.ONE:0, StopBits.TWO:3};
final _parityCodes = {Parity.NONE:0, Parity.ODD:1, Parity.EVEN:2};
