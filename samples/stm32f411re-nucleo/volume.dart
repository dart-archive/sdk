// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// This sample implements a 'volume' control using the ADC.
//
// To use, hook up a potentiometer to A0 (PA0 - ADC1_IN0) on the board, and
// connected to GND and 3V3 (I/O pins are not 5V tolerant in analog mode, per
// the documentation). The code will sample the pin and output the resulting
// value on the console every 100ms.

import 'dart:dartino';

import 'package:gpio/gpio.dart';
import 'package:stm32/stm32f411re_nucleo.dart';
import 'package:stm32/adc.dart';
import 'package:stm32/gpio.dart';

final int CHANNEL = 0;

main() {
  STM32F411RENucleo board = new STM32F411RENucleo();
  STM32Gpio gpio = board.gpio;
  GpioOutputPin led = gpio.initOutput(STM32F411RENucleo.LED2);
  STM32Adc adc = board.adc;

  adc.init();
  adc.initChannel(CHANNEL);
  adc.configureSingleChannelSequence(CHANNEL);
  adc.continuousMode = true;
  adc.start();
  print('Reading volume...');
  while (true) {
    adc.waitForConversionEnd();
    int value = adc.readData();
    print('Value: $value');
    led.toggle();
    sleep(100);
  }
}
