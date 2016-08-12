// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.stm32f411re_nucleo;

import 'package:gpio/gpio.dart';
import 'package:i2c/i2c.dart';
import 'package:stm32/adc.dart';
import 'package:stm32/dma.dart';
import 'package:stm32/gpio.dart';
import 'package:stm32/i2c.dart';
import 'package:stm32/uart.dart';
import 'package:stm32/src/constants.dart';

class STM32F411RENucleo {
  static const int apb1Clock = 100000000;
  static const int apb2Clock = 100000000;
  /// GPIO pin for on-board green LED.
  static const Pin LED2 = STM32Pin.PA5;
  /// GPIO pin for on-board blue button.
  static const Pin Button1 = STM32Pin.PC13;

  /// GPIO pins on the Arduino connector.
  static const Pin A0 = STM32Pin.PA0;
  static const Pin A1 = STM32Pin.PA1;
  static const Pin A2 = STM32Pin.PA4;
  static const Pin A3 = STM32Pin.PB0;
  static const Pin A4 = STM32Pin.PC1;
  static const Pin A5 = STM32Pin.PC0;

  static const Pin D0 = STM32Pin.PA3;
  static const Pin D1 = STM32Pin.PA2;
  static const Pin D2 = STM32Pin.PA10;
  static const Pin D3 = STM32Pin.PB3;
  static const Pin D4 = STM32Pin.PB5;
  static const Pin D5 = STM32Pin.PB4;
  static const Pin D6 = STM32Pin.PB10;
  static const Pin D7 = STM32Pin.PA8;
  static const Pin D8 = STM32Pin.PA9;
  static const Pin D9 = STM32Pin.PC7;
  static const Pin D10 = STM32Pin.PB6;
  static const Pin D11 = STM32Pin.PA7;
  static const Pin D12 = STM32Pin.PA6;
  static const Pin D13 = STM32Pin.PA5;

  STM32Gpio _gpio;
  Uart _uart;
  STM32Adc _adc;
  STM32Dma _dma1;
  STM32Dma _dma2;
  I2CBus _i2c1;
  I2CBus _i2c2;
  I2CBus _i2c3;

  STM32F411RENucleo();

  Gpio get gpio {
    if (_gpio == null) {
      _gpio = new STM32Gpio(apb1Clock, apb2Clock);
    }
    return _gpio;
  }

  Uart get uart {
    if (_uart == null) {
      _uart = new Uart();
    }
    return _uart;
  }

  STM32Adc get adc {
    if (_adc == null) {
      _adc = new STM32Adc(STM32AdcConstants.ADC1, gpio, dma2.stream0);
    }
    return _adc;
  }

  STM32Dma get dma1 {
    if (_dma1 == null) {
      _dma1 = new STM32Dma('DMA1', 1, DMA1_BASE, RCC_AHB1ENR_DMA1EN);
      // Enable DMA clock - assuming no-one asks for the DMA unless they want to
      // use it.
      _dma1.enableClock();
    }
    return _dma1;
  }

  STM32Dma get dma2 {
    if (_dma2 == null) {
      _dma2 = new STM32Dma('DMA2', 2, DMA2_BASE, RCC_AHB1ENR_DMA2EN);
      // Enable DMA clock - assuming no-one asks for the DMA unless they want to
      // use it.
      _dma2.enableClock();
    }
    return _dma2;
  }

  I2CBus get i2c1 => _i2c1 ??= new I2CBusSTM('i2c1');
  I2CBus get i2c2 => _i2c2 ??= new I2CBusSTM('i2c2');
  I2CBus get i2c3 => _i2c3 ??= new I2CBusSTM('i2c3');
}
