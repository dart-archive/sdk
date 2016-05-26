#Serial Port

[![pub package](http://img.shields.io/pub/v/serial_port.svg)](https://pub.dartlang.org/packages/serial_port)
[![Build Status](https://travis-ci.org/nfrancois/serial_port.svg?branch=master)](https://travis-ci.org/nfrancois/serial_port/)
[![Build status](https://ci.appveyor.com/api/projects/status/btsc9dnff8445ff2?svg=true)](https://ci.appveyor.com/project/nfrancois/serial-port)
[![Coverage Status](https://img.shields.io/coveralls/nfrancois/serial_port.svg)](https://coveralls.io/r/nfrancois/serial_port)


SerialPort is a Dart Api to provide access read and write access to serial port. <br/>
Binaries are provided for:
 - Win 64 bits
 - Linux 64 bits
 - MacOS 64 bits

Inspiration come from [node-serialport](https://github.com/voodootikigod/node-serialport).

## How use it ?

### Echo

Simple program :
- Arduino repeat all character send to it.
- Dart send "Hello !" and print what Arduino send.

Dart part:

```Dart

import 'package:serial_port/serial_port.dart';
import 'dart:async';

main() async {
  var arduino = new SerialPort("/dev/tty.usbmodem1421");
  arduino.onRead.map(BYTES_TO_STRING).listen(print);
  await arduino.open();
  // Wait a little bit before sending data
  new Timer(new Duration(seconds: 2), () => arduino.writeString("Hello !"));
}

```

Arduino part:

```c
void setup(){
  Serial.begin(9600);
}

void loop(){
  while (Serial.available() > 0) {
    Serial.write(Serial.read());
  }
}
```

### List connected serial ports

```Dart

import 'package:serial_port/serial_port.dart';

main() async {
  final portNames = await SerialPort.availablePortNames;
  print("${portNames.length} devices found:");
  portNames.forEach((device) => print(">$device"));
}


```

## Executable

Install serial_port with as pub global executable.

```
pub global activate serial_port
```

And use it to list available serial ports.

```
serial_port list
```


## Nexts developments

* Have a better implementation for writing bytes.
* Wait for `TODO(turnidge): Currently handle_concurrently is ignored`from Dart VM.
* Support serial port communication parameter like (FLOWCONTROLS, ...).
