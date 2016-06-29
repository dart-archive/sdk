// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.adc;

import 'dart:dartino.ffi';

import 'package:stm32/gpio.dart';
import 'package:stm32/src/constants.dart';
import 'package:stm32/src/peripherals.dart';

class STM32AdcConstants {
  static const ADC1 = const STM32AdcConstants(
      "ADC1", ADC1_BASE - PERIPH_BASE, RCC_APB2ENR_ADC1EN,
      const [STM32Pin.PA0, STM32Pin.PA1, STM32Pin.PA2, STM32Pin.PA3,
             STM32Pin.PA4, STM32Pin.PA5, STM32Pin.PA6, STM32Pin.PA7,
             STM32Pin.PB0, STM32Pin.PB1, STM32Pin.PC0, STM32Pin.PC1,
             STM32Pin.PC2, STM32Pin.PC3, STM32Pin.PC4, STM32Pin.PC5]);
  static const ADC2 = const STM32AdcConstants(
      "ADC2", ADC2_BASE - PERIPH_BASE, RCC_APB2ENR_ADC2EN,
      const [STM32Pin.PA0, STM32Pin.PA1, STM32Pin.PA2, STM32Pin.PA3,
             STM32Pin.PA4, STM32Pin.PA5, STM32Pin.PA6, STM32Pin.PA7,
             STM32Pin.PB0, STM32Pin.PB1, STM32Pin.PC0, STM32Pin.PC1,
             STM32Pin.PC2, STM32Pin.PC3, STM32Pin.PC4, STM32Pin.PC5]);
  static const ADC3 = const STM32AdcConstants(
      "ADC3", ADC3_BASE - PERIPH_BASE, RCC_APB2ENR_ADC3EN,
      const [STM32Pin.PA0, STM32Pin.PA1, STM32Pin.PA2, STM32Pin.PA3,
             STM32Pin.PF6, STM32Pin.PF7, STM32Pin.PF8, STM32Pin.PF9,
             STM32Pin.PF10, STM32Pin.PF3, STM32Pin.PC0, STM32Pin.PC1,
             STM32Pin.PC2, STM32Pin.PC3, STM32Pin.PF4, STM32Pin.PF5]);

  final String interfaceName;
  final int base; // Peripheral base.
  final int apb2enr; // Clock enable bit in RCC->APB2ENR.
  final List<STM32Pin> pinForChannel; // GPIO pin for ADC channel

  const STM32AdcConstants(this.interfaceName, this.base, this.apb2enr,
                          this.pinForChannel);
}

/// Access to STM32 ADC interfaces.
/// Note: Not all models have all interfaces, and the channels on different
/// interfaces may share pins.
class STM32Adc {
  static const ADC1 = const STM32Adc(
      "ADC1", ADC1_BASE - PERIPH_BASE, RCC_APB2ENR_ADC1EN,
      const [STM32Pin.PA0, STM32Pin.PA1, STM32Pin.PA2, STM32Pin.PA3,
             STM32Pin.PA4, STM32Pin.PA5, STM32Pin.PA6, STM32Pin.PA7,
             STM32Pin.PB0, STM32Pin.PB1, STM32Pin.PC0, STM32Pin.PC1,
             STM32Pin.PC2, STM32Pin.PC3, STM32Pin.PC4, STM32Pin.PC5]);
  static const ADC2 = const STM32Adc(
      "ADC2", ADC2_BASE - PERIPH_BASE, RCC_APB2ENR_ADC2EN,
      const [STM32Pin.PA0, STM32Pin.PA1, STM32Pin.PA2, STM32Pin.PA3,
             STM32Pin.PA4, STM32Pin.PA5, STM32Pin.PA6, STM32Pin.PA7,
             STM32Pin.PB0, STM32Pin.PB1, STM32Pin.PC0, STM32Pin.PC1,
             STM32Pin.PC2, STM32Pin.PC3, STM32Pin.PC4, STM32Pin.PC5]);
  static const ADC3 = const STM32Adc(
      "ADC3", ADC3_BASE - PERIPH_BASE, RCC_APB2ENR_ADC3EN,
      const [STM32Pin.PA0, STM32Pin.PA1, STM32Pin.PA2, STM32Pin.PA3,
             STM32Pin.PF6, STM32Pin.PF7, STM32Pin.PF8, STM32Pin.PF9,
             STM32Pin.PF10, STM32Pin.PF3, STM32Pin.PC0, STM32Pin.PC1,
             STM32Pin.PC2, STM32Pin.PC3, STM32Pin.PF4, STM32Pin.PF5]);

  static const _ADC_COMMON_BASE = ADC_COMMON_BASE - PERIPH_BASE;

  final String interfaceName;
  final int _base; // Peripheral base.
  final int _apb2enr; // Clock enable bit in RCC->APB2ENR.
  final List<STM32Pin> _pinForChannel; // GPIO pin for ADC channel
  final STM32Gpio _gpio;

  const STM32Adc(STM32AdcConstants cfg, this._gpio) :
            this.interfaceName = cfg.interfaceName,
            this._base = cfg.base,
            this._apb2enr = cfg.apb2enr,
            this._pinForChannel = cfg.pinForChannel;

  String toString() => interfaceName;

  static bool _isSet(int base, int reg, int mask) {
    int value = peripherals.getUint32(base + reg);
    return value & mask == mask;
  }

  static void _setMask(int base, int reg, int mask) {
    int offset = base + reg;
    int temp = peripherals.getUint32(offset);
    peripherals.setUint32(offset, temp | mask);
  }

  static void _resetMask(int base, int reg, int mask) {
    int offset = base + reg;
    int temp = peripherals.getUint32(offset);
    peripherals.setUint32(offset, temp & ~mask);
  }

  static void _setMaskedValue(int base, int reg, int mask, int value) {
    int offset = base + reg;
    int temp = peripherals.getUint32(offset);
    peripherals.setUint32(offset, (temp & ~mask) | value);
  }

  static void _setMaskEnabled(int base, int reg, int mask, bool enabled) {
    if (enabled) {
      _setMask(base, reg, mask);
    } else {
      _resetMask(base, reg, mask);
    }
  }

  /// Set ADC clock (PCLK2 clock divided by the configured prescaler).
  static void setClock(int prescaler) =>
    _setMaskedValue(_ADC_COMMON_BASE, ADC.CCR, ADC_CCR_ADCPRE_MASK, prescaler);

  /// Enable or disable the VBat channel.
  static void setVBatEnabled(bool enabled) =>
    _setMaskEnabled(_ADC_COMMON_BASE, ADC.CCR, ADC_CCR_VBATE, enabled);
  /// Enable or disable the temperature and VRef channel.
  static void setTemperatureAndVRefEnabled(bool enabled) =>
    _setMaskEnabled(_ADC_COMMON_BASE, ADC.CCR, ADC_CCR_TSVREFE, enabled);

  /// Initialize this ADC.
  void init() {
    setClock(ADC_CCR_ADCPRE_PCLK2_DIV_4);
    enableClock();
    powerOn();
    _alignment = ADC_CR2_ALIGN_RIGHT;
    continuousMode = false;
  }

  /// Initialize a channel for ADC input. This configures the corresponding
  /// GPIO pin for analog mode. Only channels 0..15 have GPIO pins.
  void initChannel(int channel) {
    if (channel < 0 || channel > 18) {
      throw new ArgumentError('Invalid ADC channel');
    }
    if (channel > 15) {
      // Internal voltage/temperature sensor. No corresponding GPIO pin.
      return;
    }
    _gpio.initSTM32Analog(_pinForChannel[channel]);
  }

  /// Enable ADC clock in RCC.
  void enableClock() =>
    _setMask(RCC_BASE - PERIPH_BASE, RCC.APB2ENR, _apb2enr);
  /// Disable ADC clock in RCC.
  void disableClock() =>
    _clearMask(RCC_BASE - PERIPH_BASE, RCC.APB2ENR, _apb2enr);

  /// Power on the ADC.
  void powerOn() => _setMask(_base, ADC.CR2, ADC_CR2_ADON);
  /// Power off the ADC.
  void powerOff() => _resetMask(_base, ADC.CR2, ADC_CR2_ADON);

  /// Start conversion.
  void start() => _setMask(_base, ADC.CR2, ADC_CR2_SWSTART);
  /// Wait for the EOC bit to be set, signalling end of current conversion.
  /// This is a blocking call.
  void waitForConversionEnd() {
    while (!_isSet(_base, ADC.SR, ADC_SR_EOC));
  }
  /// Read the current sample value. Clears the EOC flag.
  int readData() => peripherals.getUint32(_base + ADC.DR) & ADC_DR_DATA_MASK;
  /// Stop conversion.
  void stop() => _resetMask(_base, ADC.CR2, ADC_CR2_SWSTART);

  /// Configures the ADC to sample a single channel.
  void configureSingleChannelSequence(int channel) {
    channelSequenceLength = 1;
    setChannelRank(channel, 1);
  }

  /// Returns a single sample value. The ADC is configured for a single channel
  /// sequence, and actively polled for end of conversion.
  /// This is a blocking call.
  int readSingleValue(int channel) {
    configureSingleChannelSequence(channel);
    start();
    waitForConversionEnd();
    int value = readData();
    stop();
    return value;
  }

  /// Set sample value alignment (right or left).
  void set _alignment(int alignment) =>
    _setMaskedValue(_base, ADC.CR2, ADC_CR2_ALIGN_MASK, alignment);
  /// Set continuous mode.
  void set continuousMode(bool continuous) =>
    _setMaskEnabled(_base, ADC.CR2, ADC_CR2_CONT, continuous);

  /// Set channel sequence length. The ADC will sample the configured channel
  /// ranks.
  void set channelSequenceLength(int length) {
    if (length < 1 || length > 16) {
      throw new ArgumentError('Invalid channel sequence length');
    }
    int value = (length - 1) << 20;
    _setMaskedValue(_base, ADC.SQR1, ADC_SQR1_L_MASK, value);
  }

  /// Set sampling time for a single channel.
  void setChannelSamplingTime(int channel, int smprSelection) {
    if (channel < 0 || channel > 18) {
      throw new ArgumentError('Invalid ADC channel');
    }
    int register;
    int position;
    if (channel > 9) {
      register = ADC.SMPR1;
      position = channel - 10;
    } else {
      register = ADC.SMPR2;
      position = channel;
    }
    int shift = position * 3;
    int mask = ADC_SMPRX_MASK << shift;
    int value = smprSelection << shift;
    _setMaskedValue(_base, register, mask, value);
  }

  /// Configure a channel for sampling in the given sequence rank.
  void setChannelRank(int channel, int rank) {
    if (channel < 0 || channel > 18) {
      throw new ArgumentError('Invalid ADC channel');
    }
    if (rank < 1 || rank > 16) {
      throw new ArgumentError('Invalid ADC channel rank');
    }
    int register;
    int position;
    if (rank > 12) {
      register = ADC.SQR1;
      position = rank - 13;
    } else if (rank > 6) {
      register = ADC.SQR2;
      position = rank - 7;
    } else {
      register = ADC.SQR3;
      position = rank - 1;
    }
    int shift = position * 5;
    int mask = ADC_SQR_MASK << shift;
    int value = channel << shift;
    _setMaskedValue(_base, register, mask, value);
  }
}
