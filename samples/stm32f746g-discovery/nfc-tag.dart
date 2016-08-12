// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino';
import 'dart:typed_data';

import 'package:gpio/gpio.dart';
import 'package:stm32/gpio.dart';
import 'package:stm32/stm32f746g_disco.dart';
import 'package:nucleo_nfc01a1/nucleo_nfc01a1.dart';

String _toHexString(ByteData data) {
  var result = '';
  var bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  for (var b in bytes) {
    result += '${b.toRadixString(16)} ';
  }
  return result;
}

main() {
  STM32F746GDiscovery board = new STM32F746GDiscovery();
  GpioOutputPin led1 = board.gpio.initOutput(STM32Pin.PB4);
  GpioOutputPin led2 = board.gpio.initOutput(STM32Pin.PB5);
  GpioOutputPin led3 = board.gpio.initOutput(STM32Pin.PA10);
  NucleoNFC01A1 nfc = new NucleoNFC01A1(board.i2c1, led1, led2, led3);

  nfc.led1.low();
  nfc.led2.high();
  nfc.led3.low();

  var m24sr = nfc.m24sr;
  m24sr.initialize();
  print("M24SR product code ${m24sr.productCode.toRadixString(16)}"
        " - UID ${_toHexString(m24sr.uid)}");
  print("NDEF file ID: ${m24sr.ndefFileId.toRadixString(16)}, "
        "${m24sr.ndefFileSize} bytes");
  m24sr.openSession();
  m24sr.selectApplication();
  m24sr.selectNdefFile();
  var ndefData = m24sr.readFile();
  m24sr.closeSession();

  print("NDEF data: ${_toHexString(ndefData)}");

  while (true) {
    nfc.led1.high();
    sleep(100);
    nfc.led2.high();
    sleep(100);
    nfc.led3.high();
    sleep(100);
    nfc.led1.low();
    sleep(100);
    nfc.led2.low();
    sleep(100);
    nfc.led3.low();
    sleep(100);
  }
}
