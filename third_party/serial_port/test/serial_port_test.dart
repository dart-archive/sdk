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

library test_serial_port;

import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:test/test.dart';
import 'package:serial_port/serial_port.dart';


void main() {

  group('Util', (){

    test('Convert bytes to string', (){
      expect(BYTES_TO_STRING([72, 101, 108, 108, 111]), "Hello");
    });

  });

  group('Serial port', () {

    String portName;

    setUp(() async {
        final testDir = await Directory.systemTemp.createTemp('serial_port_test');
        portName = "${testDir.path}/tty-usb-device-${new Random().nextInt(99999999)}";
        return new File(portName).create();
    });

    test('Detect serial port', () async {
      // When
      List<String> names = await SerialPort.availablePortNames;

      // Then
      // Not easy to have test for all Platform. The minimal requirement is nothing detected
      expect(names, isNotNull);
    });

    test('Check port name is available', () async {
      // When
      PortNameAvailability availability = await SerialPort.isAvailablePortName(portName);

      // Then
      expect(availability, isNotNull);
      expect(availability.portName, portName);
      expect(availability.isAvailable, isTrue);
    });

    test('Check port name is not available', () async {
      // When
      PortNameAvailability availability = await SerialPort.isAvailablePortName("notExists");

      // Then
      expect(availability, isNotNull);
      expect(availability.portName, "notExists");
      expect(availability.isAvailable, isFalse);
    });

    test('Defaut open', () async {
      // Given
      var serial =  new SerialPort(portName);

      // When
      await serial.open();

      // Then
      expect(serial.fd!=-1, true);
      expect(serial.isOpen, true);


      await serial.close();

	  });
	  
	      test('Open with parameter', () async {
      // Given
      var serial =  new SerialPort(portName, baudrate : 9600, databits: 8, parity: Parity.NONE, stopBits : StopBits.ONE);

      // When
      await serial.open();

      // Then
      expect(serial.fd!=-1, true);
      expect(serial.isOpen, true);


      await serial.close();

	  });

    test('Close', () async {
      // Given
      var serial =  new SerialPort(portName);
      await serial.open();

      // When
      await serial.close();

      // Then
      expect(serial.fd, -1);
      expect(serial.isOpen, false);
    });

    test('Write String', () async {
      // Given
      var serial =  new SerialPort(portName);
      await serial.open();

      // When
      final success = await serial.writeString("Hello");

      // When
      expect(success, isTrue);


      await serial.close();
    });

    test('Write bytes', () async  {
      // Given
      var serial =  new SerialPort(portName);
      await serial.open();

      // When
      final success = await serial.write([72, 101, 108, 108, 111]);

      // Then
      expect(success, true);

      await serial.close();
    });

    test('Read bytes', () async {
      // Given
      new File(portName).writeAsStringSync("Hello");
      var serial =  new SerialPort(portName);
      final t = new Timer(new Duration(seconds: 2), () async {
        if(serial.isOpen){
          await serial.close();
        }
        fail('event not fired in time');
      });
      await serial.open();

      // When
      List<int> bytes = await serial.onRead.first;

      // Then
      expect(bytes, "Hello".codeUnits);

      t.cancel();
      await serial.close();

    });

    test('Defaut values', () {
      // When
      var serial =  new SerialPort(portName);

      // Then
      expect(serial.baudrate, 9600);
      expect(serial.databits, 8);
      expect(serial.parity, Parity.NONE);
      expect(serial.stopBits, StopBits.ONE);
    });

    test('Fail with unkwnon portname', (){
      // Given
      var serial = new SerialPort("notExist");

      // When/Then
      expect(serial.open(), throwsA(equals("Cannot open notExist : Invalid access")));
    });

    test('Fail with unkwnon baudrate', (){
      // Given
      var serial = new SerialPort(portName, baudrate: -1);

      // When/Then
      expect(serial.open(), throwsA(equals("Cannot open ${portName} : Invalid baudrate")));
    });

    test('Fail when open twice', () async {
      // Given
      var serial =  new SerialPort(portName);
      await serial.open();

      // When/Then
      expect(serial.open(), throwsA(equals("${portName} is yet open")));

      await serial.close();
    });


    test('Fail when close and not open', (){
      // Given
      var serial =  new SerialPort(portName);

      // Then/ When
      serial.close().catchError((error) => expect(error, "${portName} is not open"));
    });

    test('Fail when writeString and not open', (){
      // Given
      var serial =  new SerialPort(portName);

      // When/Then
      serial.writeString("Hello").catchError((error) => expect(error, "${portName} is not open"));
    });

    test('Fail when write and not open', (){
      // Given
      var serial =  new SerialPort(portName);

      // When/Then
      serial.write("Hello".codeUnits).catchError((error) => expect(error, "${portName} is not open"));
    });

 });

}
