// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.gpio;

import 'dart:dartino.ffi';

import 'package:gpio/gpio.dart';
import 'package:stm32/timer.dart';
import 'package:stm32/src/constants.dart';
import 'package:stm32/src/peripherals.dart';

/// All the GPIO ports on STM32 MCUs. Not all models have all ports.
class _STM32GpioPort {
  static const A = const _STM32GpioPort(
      "A", GPIOA_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOAEN);
  static const B = const _STM32GpioPort(
      "B", GPIOB_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOBEN);
  static const C = const _STM32GpioPort(
      "C", GPIOC_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOCEN);
  static const D = const _STM32GpioPort(
      "D", GPIOD_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIODEN);
  static const E = const _STM32GpioPort(
      "E", GPIOE_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOEEN);
  static const F = const _STM32GpioPort(
      "F", GPIOF_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOFEN);
  static const G = const _STM32GpioPort(
      "G", GPIOG_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOGEN);
  static const H = const _STM32GpioPort(
      "H", GPIOH_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOHEN);
  static const I = const _STM32GpioPort(
      "I", GPIOI_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOIEN);
  static const J = const _STM32GpioPort(
      "J", GPIOJ_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOJEN);
  static const K = const _STM32GpioPort(
      "K", GPIOK_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOKEN);

  final String port;
  final int _base; // Peripheral base.
  final int _ahb1enr; // Clock enable bit in RCC->AHB1ENR.

  const _STM32GpioPort(this.port, this._base, this._ahb1enr);

  String toString() => 'GPIO port $port';
}

// PWM channel assigned to a pin if any.
class _PwmChannel {
  final StmTimer timer;
  final int channel;
  const _PwmChannel(this.timer, this.channel);
}

/// All the GPIO pins on the STM32 MCUs. Not all models have all pins.
class STM32Pin implements Pin {
  static const Pin PA0 = const STM32Pin(
    'PA0', _STM32GpioPort.A, 0, const _PwmChannel(StmTimer.timer2, 1));
  static const Pin PA1 = const STM32Pin(
    'PA1', _STM32GpioPort.A, 1, const _PwmChannel(StmTimer.timer2, 2));
  static const Pin PA2 = const STM32Pin(
    'PA2', _STM32GpioPort.A, 2, const _PwmChannel(StmTimer.timer2, 3));
  static const Pin PA3 = const STM32Pin(
    'PA3', _STM32GpioPort.A, 3, const _PwmChannel(StmTimer.timer2, 4));
  static const Pin PA4 = const STM32Pin('PA4', _STM32GpioPort.A, 4);
  static const Pin PA5 = const STM32Pin(
    'PA5', _STM32GpioPort.A, 5, const _PwmChannel(StmTimer.timer2, 1));
  static const Pin PA6 = const STM32Pin(
    'PA6', _STM32GpioPort.A, 6, const _PwmChannel(StmTimer.timer3, 1));
  static const Pin PA7 = const STM32Pin(
    'PA7', _STM32GpioPort.A, 7, const _PwmChannel(StmTimer.timer1, 1));
  static const Pin PA8 = const STM32Pin(
    'PA8', _STM32GpioPort.A, 8, const _PwmChannel(StmTimer.timer1, 1));
  static const Pin PA9 = const STM32Pin(
    'PA9', _STM32GpioPort.A, 9, const _PwmChannel(StmTimer.timer1, 2));
  static const Pin PA10 = const STM32Pin(
    'PA10', _STM32GpioPort.A, 10, const _PwmChannel(StmTimer.timer1, 3));
  static const Pin PA11 = const STM32Pin(
    'PA11', _STM32GpioPort.A, 11, const _PwmChannel(StmTimer.timer1, 4));
  static const Pin PA12 = const STM32Pin('PA12', _STM32GpioPort.A, 12);
  static const Pin PA13 = const STM32Pin('PA13', _STM32GpioPort.A, 13);
  static const Pin PA14 = const STM32Pin('PA14', _STM32GpioPort.A, 14);
  static const Pin PA15 = const STM32Pin(
    'PA15', _STM32GpioPort.A, 15, const _PwmChannel(StmTimer.timer2, 1));

  static const Pin PB0 = const STM32Pin('PB0', _STM32GpioPort.B, 0);
  static const Pin PB1 = const STM32Pin('PB1', _STM32GpioPort.B, 1);
  static const Pin PB2 = const STM32Pin('PB2', _STM32GpioPort.B, 2);
  static const Pin PB3 = const STM32Pin(
    'PB3', _STM32GpioPort.B, 3, const _PwmChannel(StmTimer.timer2, 2));
  static const Pin PB4 = const STM32Pin(
    'PB4', _STM32GpioPort.B, 4, const _PwmChannel(StmTimer.timer3, 1));
  static const Pin PB5 = const STM32Pin(
    'PB5', _STM32GpioPort.B, 5, const _PwmChannel(StmTimer.timer3, 2));
  static const Pin PB6 = const STM32Pin(
    'PB6', _STM32GpioPort.B, 6, const _PwmChannel(StmTimer.timer4, 1));
  static const Pin PB7 = const STM32Pin(
    'PB7', _STM32GpioPort.B, 7, const _PwmChannel(StmTimer.timer4, 2));
  static const Pin PB8 = const STM32Pin(
    'PB8', _STM32GpioPort.B, 8, const _PwmChannel(StmTimer.timer4, 3));
  static const Pin PB9 = const STM32Pin(
    'PB9', _STM32GpioPort.B, 9, const _PwmChannel(StmTimer.timer4, 4));
  static const Pin PB10 = const STM32Pin(
    'PB10', _STM32GpioPort.B, 10, const _PwmChannel(StmTimer.timer2, 3));
  static const Pin PB11 = const STM32Pin(
    'PB11', _STM32GpioPort.B, 11, const _PwmChannel(StmTimer.timer2, 4));
  static const Pin PB12 = const STM32Pin('PB12', _STM32GpioPort.B, 12);
  static const Pin PB13 = const STM32Pin(
    'PB13', _STM32GpioPort.B, 13, const _PwmChannel(StmTimer.timer1, 1));
  static const Pin PB14 = const STM32Pin(
    'PB14', _STM32GpioPort.B, 14, const _PwmChannel(StmTimer.timer1, 2));
  static const Pin PB15 = const STM32Pin(
    'PB15', _STM32GpioPort.B, 15, const _PwmChannel(StmTimer.timer1, 3));

  static const Pin PC0 = const STM32Pin('PC0', _STM32GpioPort.C, 0);
  static const Pin PC1 = const STM32Pin('PC1', _STM32GpioPort.C, 1);
  static const Pin PC2 = const STM32Pin('PC2', _STM32GpioPort.C, 2);
  static const Pin PC3 = const STM32Pin('PC3', _STM32GpioPort.C, 3);
  static const Pin PC4 = const STM32Pin('PC4', _STM32GpioPort.C, 4);
  static const Pin PC5 = const STM32Pin('PC5', _STM32GpioPort.C, 5);
  static const Pin PC6 = const STM32Pin(
    'PC6', _STM32GpioPort.C, 6, const _PwmChannel(StmTimer.timer3, 1));
  static const Pin PC7 = const STM32Pin(
    'PC7', _STM32GpioPort.C, 7, const _PwmChannel(StmTimer.timer3, 2));
  static const Pin PC8 = const STM32Pin(
    'PC8', _STM32GpioPort.C, 8, const _PwmChannel(StmTimer.timer3, 3));
  static const Pin PC9 = const STM32Pin(
    'PC9', _STM32GpioPort.C, 9, const _PwmChannel(StmTimer.timer3, 4));
  static const Pin PC10 = const STM32Pin('PC10', _STM32GpioPort.C, 10);
  static const Pin PC11 = const STM32Pin('PC11', _STM32GpioPort.C, 11);
  static const Pin PC12 = const STM32Pin('PC12', _STM32GpioPort.C, 12);
  static const Pin PC13 = const STM32Pin('PC13', _STM32GpioPort.C, 13);
  static const Pin PC14 = const STM32Pin('PC14', _STM32GpioPort.C, 14);
  static const Pin PC15 = const STM32Pin('PC15', _STM32GpioPort.C, 15);

  static const Pin PD0 = const STM32Pin('PD0', _STM32GpioPort.D, 0);
  static const Pin PD1 = const STM32Pin('PD1', _STM32GpioPort.D, 1);
  static const Pin PD2 = const STM32Pin('PD2', _STM32GpioPort.D, 2);
  static const Pin PD3 = const STM32Pin('PD3', _STM32GpioPort.D, 3);
  static const Pin PD4 = const STM32Pin('PD4', _STM32GpioPort.D, 4);
  static const Pin PD5 = const STM32Pin('PD5', _STM32GpioPort.D, 5);
  static const Pin PD6 = const STM32Pin('PD6', _STM32GpioPort.D, 6);
  static const Pin PD7 = const STM32Pin('PD7', _STM32GpioPort.D, 7);
  static const Pin PD8 = const STM32Pin('PD8', _STM32GpioPort.D, 8);
  static const Pin PD9 = const STM32Pin('PD9', _STM32GpioPort.D, 9);
  static const Pin PD10 = const STM32Pin('PD10', _STM32GpioPort.D, 10);
  static const Pin PD11 = const STM32Pin('PD11', _STM32GpioPort.D, 11);
  static const Pin PD12 = const STM32Pin(
    'PD12', _STM32GpioPort.D, 12, const _PwmChannel(StmTimer.timer4, 1));
  static const Pin PD13 = const STM32Pin(
    'PD13', _STM32GpioPort.D, 13, const _PwmChannel(StmTimer.timer4, 2));
  static const Pin PD14 = const STM32Pin(
    'PD14', _STM32GpioPort.D, 14, const _PwmChannel(StmTimer.timer4, 3));
  static const Pin PD15 = const STM32Pin(
    'PD15', _STM32GpioPort.D, 15, const _PwmChannel(StmTimer.timer4, 4));

  static const Pin PE0 = const STM32Pin('PE0', _STM32GpioPort.E, 0);
  static const Pin PE1 = const STM32Pin('PE1', _STM32GpioPort.E, 1);
  static const Pin PE2 = const STM32Pin('PE2', _STM32GpioPort.E, 2);
  static const Pin PE3 = const STM32Pin('PE3', _STM32GpioPort.E, 3);
  static const Pin PE4 = const STM32Pin('PE4', _STM32GpioPort.E, 4);
  static const Pin PE5 = const STM32Pin(
    'PE5', _STM32GpioPort.E, 5, const _PwmChannel(StmTimer.timer9, 1));
  static const Pin PE6 = const STM32Pin(
    'PE6', _STM32GpioPort.E, 6, const _PwmChannel(StmTimer.timer9, 2));
  static const Pin PE7 = const STM32Pin('PE7', _STM32GpioPort.E, 7);
  static const Pin PE8 = const STM32Pin(
    'PE8', _STM32GpioPort.E, 8, const _PwmChannel(StmTimer.timer1, 1));
  static const Pin PE9 = const STM32Pin(
    'PE9', _STM32GpioPort.E, 9, const _PwmChannel(StmTimer.timer1, 1));
  static const Pin PE10 = const STM32Pin(
    'PE10', _STM32GpioPort.E, 10, const _PwmChannel(StmTimer.timer1, 2));
  static const Pin PE11 = const STM32Pin(
    'PE11', _STM32GpioPort.E, 11, const _PwmChannel(StmTimer.timer1, 2));
  static const Pin PE12 = const STM32Pin(
    'PE12', _STM32GpioPort.E, 12, const _PwmChannel(StmTimer.timer1, 3));
  static const Pin PE13 = const STM32Pin(
    'PE13', _STM32GpioPort.E, 13, const _PwmChannel(StmTimer.timer1, 3));
  static const Pin PE14 = const STM32Pin(
    'PE14', _STM32GpioPort.E, 14, const _PwmChannel(StmTimer.timer1, 4));
  static const Pin PE15 = const STM32Pin('PE15', _STM32GpioPort.E, 15);

  static const Pin PF1 = const STM32Pin('PF1', _STM32GpioPort.F, 1);
  static const Pin PF2 = const STM32Pin('PF2', _STM32GpioPort.F, 2);
  static const Pin PF3 = const STM32Pin('PF3', _STM32GpioPort.F, 3);
  static const Pin PF4 = const STM32Pin('PF4', _STM32GpioPort.F, 4);
  static const Pin PF5 = const STM32Pin('PF5', _STM32GpioPort.F, 5);
  static const Pin PF6 = const STM32Pin(
    'PF6', _STM32GpioPort.F, 6, const _PwmChannel(StmTimer.timer10, 1));
  static const Pin PF7 = const STM32Pin(
    'PF7', _STM32GpioPort.F, 7, const _PwmChannel(StmTimer.timer11, 1));
  static const Pin PF8 = const STM32Pin('PF8', _STM32GpioPort.F, 8);
  static const Pin PF9 = const STM32Pin('PF9', _STM32GpioPort.F, 9);
  static const Pin PF10 = const STM32Pin('PF10', _STM32GpioPort.F, 10);
  static const Pin PF11 = const STM32Pin('PF11', _STM32GpioPort.F, 11);
  static const Pin PF12 = const STM32Pin('PF12', _STM32GpioPort.F, 12);
  static const Pin PF13 = const STM32Pin('PF13', _STM32GpioPort.F, 13);
  static const Pin PF14 = const STM32Pin('PF14', _STM32GpioPort.F, 14);
  static const Pin PF15 = const STM32Pin('PF15', _STM32GpioPort.F, 15);

  static const Pin PG0 = const STM32Pin('PG0', _STM32GpioPort.G, 0);
  static const Pin PG1 = const STM32Pin('PG1', _STM32GpioPort.G, 1);
  static const Pin PG2 = const STM32Pin('PG2', _STM32GpioPort.G, 2);
  static const Pin PG3 = const STM32Pin('PG3', _STM32GpioPort.G, 3);
  static const Pin PG4 = const STM32Pin('PG4', _STM32GpioPort.G, 4);
  static const Pin PG5 = const STM32Pin('PG5', _STM32GpioPort.G, 5);
  static const Pin PG6 = const STM32Pin('PG6', _STM32GpioPort.G, 6);
  static const Pin PG7 = const STM32Pin('PG7', _STM32GpioPort.G, 7);
  static const Pin PG8 = const STM32Pin('PG8', _STM32GpioPort.G, 8);
  static const Pin PG9 = const STM32Pin('PG9', _STM32GpioPort.G, 9);
  static const Pin PG10 = const STM32Pin('PG10', _STM32GpioPort.G, 10);
  static const Pin PG11 = const STM32Pin('PG11', _STM32GpioPort.G, 11);
  static const Pin PG12 = const STM32Pin('PG12', _STM32GpioPort.G, 12);
  static const Pin PG13 = const STM32Pin('PG13', _STM32GpioPort.G, 13);
  static const Pin PG14 = const STM32Pin('PG14', _STM32GpioPort.G, 14);
  static const Pin PG15 = const STM32Pin('PG15', _STM32GpioPort.G, 15);

  static const Pin PH0 = const STM32Pin('PH0', _STM32GpioPort.H, 0);
  static const Pin PH1 = const STM32Pin('PH1', _STM32GpioPort.H, 1);
  static const Pin PH2 = const STM32Pin('PH2', _STM32GpioPort.H, 2);
  static const Pin PH3 = const STM32Pin('PH3', _STM32GpioPort.H, 3);
  static const Pin PH4 = const STM32Pin('PH4', _STM32GpioPort.H, 4);
  static const Pin PH5 = const STM32Pin('PH5', _STM32GpioPort.H, 5);
  static const Pin PH6 = const STM32Pin(
    'PH6', _STM32GpioPort.H, 6, const _PwmChannel(StmTimer.timer12, 1));
  static const Pin PH7 = const STM32Pin('PH7', _STM32GpioPort.H, 7);
  static const Pin PH8 = const STM32Pin('PH8', _STM32GpioPort.H, 8);
  static const Pin PH9 = const STM32Pin(
    'PH9', _STM32GpioPort.H, 9, const _PwmChannel(StmTimer.timer12, 2));
  static const Pin PH10 = const STM32Pin(
    'PH10', _STM32GpioPort.H, 10, const _PwmChannel(StmTimer.timer5, 1));
  static const Pin PH11 = const STM32Pin(
    'PH11', _STM32GpioPort.H, 11, const _PwmChannel(StmTimer.timer5, 2));
  static const Pin PH12 = const STM32Pin(
    'PH12', _STM32GpioPort.H, 12, const _PwmChannel(StmTimer.timer5, 3));
  static const Pin PH13 = const STM32Pin(
    'PH13', _STM32GpioPort.H, 13, const _PwmChannel(StmTimer.timer8, 1));
  static const Pin PH14 = const STM32Pin(
    'PH14', _STM32GpioPort.H, 14, const _PwmChannel(StmTimer.timer8, 2));
  static const Pin PH15 = const STM32Pin(
    'PH15', _STM32GpioPort.H, 15, const _PwmChannel(StmTimer.timer8, 3));

  static const Pin PI0 = const STM32Pin(
    'PI0', _STM32GpioPort.I, 0, const _PwmChannel(StmTimer.timer5, 4));
  static const Pin PI1 = const STM32Pin('PI1', _STM32GpioPort.I, 1);
  static const Pin PI2 = const STM32Pin('PI2', _STM32GpioPort.I, 2);
  static const Pin PI3 = const STM32Pin('PI3', _STM32GpioPort.I, 3);
  static const Pin PI4 = const STM32Pin('PI4', _STM32GpioPort.I, 4);
  static const Pin PI5 = const STM32Pin(
    'PI5', _STM32GpioPort.I, 5, const _PwmChannel(StmTimer.timer8, 1));
  static const Pin PI6 = const STM32Pin(
    'PI6', _STM32GpioPort.I, 6, const _PwmChannel(StmTimer.timer8, 2));
  static const Pin PI7 = const STM32Pin(
    'PI7', _STM32GpioPort.I, 7, const _PwmChannel(StmTimer.timer8, 3));
  static const Pin PI8 = const STM32Pin('PI8', _STM32GpioPort.I, 8);
  static const Pin PI9 = const STM32Pin('PI9', _STM32GpioPort.I, 9);
  static const Pin PI10 = const STM32Pin('PI10', _STM32GpioPort.I, 10);
  static const Pin PI11 = const STM32Pin('PI11', _STM32GpioPort.I, 11);
  static const Pin PI12 = const STM32Pin('PI12', _STM32GpioPort.I, 12);
  static const Pin PI13 = const STM32Pin('PI13', _STM32GpioPort.I, 13);
  static const Pin PI14 = const STM32Pin('PI14', _STM32GpioPort.I, 14);
  static const Pin PI15 = const STM32Pin('PI15', _STM32GpioPort.I, 15);

  static const Pin PJ0 = const STM32Pin('PJ0', _STM32GpioPort.J, 0);
  static const Pin PJ1 = const STM32Pin('PJ1', _STM32GpioPort.J, 1);
  static const Pin PJ2 = const STM32Pin('PJ2', _STM32GpioPort.J, 2);
  static const Pin PJ3 = const STM32Pin('PJ3', _STM32GpioPort.J, 3);
  static const Pin PJ4 = const STM32Pin('PJ4', _STM32GpioPort.J, 4);
  static const Pin PJ5 = const STM32Pin('PJ5', _STM32GpioPort.J, 5);
  static const Pin PJ6 = const STM32Pin('PJ6', _STM32GpioPort.J, 6);
  static const Pin PJ7 = const STM32Pin('PJ7', _STM32GpioPort.J, 7);
  static const Pin PJ8 = const STM32Pin('PJ8', _STM32GpioPort.J, 8);
  static const Pin PJ9 = const STM32Pin('PJ9', _STM32GpioPort.J, 9);
  static const Pin PJ10 = const STM32Pin('PJ10', _STM32GpioPort.J, 10);
  static const Pin PJ11 = const STM32Pin('PJ11', _STM32GpioPort.J, 11);
  static const Pin PJ12 = const STM32Pin('PJ12', _STM32GpioPort.J, 12);
  static const Pin PJ13 = const STM32Pin('PJ13', _STM32GpioPort.J, 13);
  static const Pin PJ14 = const STM32Pin('PJ14', _STM32GpioPort.J, 14);
  static const Pin PJ15 = const STM32Pin('PJ15', _STM32GpioPort.J, 15);

  final String name;
  final _STM32GpioPort _port;
  final int pin;
  final _PwmChannel _pwm;

  const STM32Pin(this.name, this._port, this.pin, [this._pwm]);

  String toString() => 'GPIO pin $name';

  void setAlternateFunction(int af) {
    if (pin < 8) {
      int value = peripherals.getUint32(_port._base + AFR_1);
      int shift = 4 * pin;
      peripherals.setUint32(_port._base + AFR_1, value | (af << shift));
    } else {
      int value = peripherals.getUint32(_port._base + AFR_2);
      int shift = 4 * (pin - 8);
      peripherals.setUint32(_port._base + AFR_2, value | (af << shift));
    }
  }
}

/// Pin on the STM32 MCU configured for GPIO output.
class _STM32GpioOutputPin extends GpioOutputPin {
  final STM32Pin pin;

  _STM32GpioOutputPin._(this.pin);

  bool get state {
    // Read bit for pin (GPIOx->ODR).
    return peripherals.getUint32(pin._port._base + ODR) & (1 << pin.pin) != 0;
  }

  void set state(bool newState) {
    if (newState) {
      peripherals.setUint32(pin._port._base + BSRR, 1 << pin.pin);
    } else {
      peripherals.setUint32(pin._port._base + BSRR, (1 << pin.pin) << 16);
    }
  }
}

/// Pin on the STM32 MCU configured for PWM output.
class Stm32PwmOutputPin extends GpioPwmOutputPin {
  final STM32Pin _pin;
  final int _busClock;
  int _period;
  double _pulse;
  double _frequency;

  Stm32PwmOutputPin._(this._pin, this._busClock) {
    _pin._pwm.timer.setup();
    _pulse = 0.0;
    _frequency = 0.0;
    _period = 0;
  }
  
  Pin get pin {
    return _pin;
  }

  void _outputPulse() {
    output((_period * _pulse / 100.0).round());
  }

  double get frequency => _frequency;

  void set frequency(double freq) {
    _frequency = freq;
    int ticks = (_busClock / freq).round();
    int err = ticks;
    int bestP = 0, bestQ = 0;
    for (int p = 0; p < 65535; p++) {
      int q = (ticks / (p + 1)).round() - 1;
      if(q > 65535) continue;
      int n = (p + 1) * (q + 1);
      int newErr = (ticks - n).abs();
      if (newErr < err) {
        err = newErr;
        bestP = p;
        bestQ = q;
      }
      if (err == 0) break;
    }
    prescaler = bestP;
    period = bestQ;
    // Reset the pwm output with new prescaler and period.
    _outputPulse();
  }

  double get pulse => _pulse;

  void set pulse(double value) {
    _pulse = value;
    _outputPulse();
  }

  /// Set the prescaler value, controls the duration of the timer's tick.
  void set prescaler(int value) {
    _pin._pwm.timer.setPrescaler(value);
  }

  /// Set the period value, which is upper bound for the counting.
  void set period(int period) {
    _period = period;
    _pin._pwm.timer.setPeriod(period);
  }

  /// Set the PWM fill rate, measured in ticks.
  /// Should be less then or equal to period.
  void output(int value) {
    _pin._pwm.timer.setupPwmOutput(_pin._pwm.channel);
    _pin._pwm.timer.setPwmLevel(_pin._pwm.channel, value);
  }
}

/// Pin on the STM32 MCU configured for GPIO input.
class _STM32GpioInputPin extends GpioInputPin {
  final STM32Pin pin;

  _STM32GpioInputPin._(this.pin);

  bool get state {
    // Read bit for pin (GPIOx->IDR).
    return (peripherals.getUint32(pin._port._base + IDR) & (1 << pin.pin)) != 0;
  }

  bool waitFor(bool value, int timeout) => throw new UnimplementedError();
}

/// Access to STM32 MCU GPIO interface to configure GPIO pins.
class STM32Gpio extends Gpio {
  int _apb1Clock;
  int _apb2Clock;

  STM32Gpio(this._apb1Clock, this._apb2Clock);

  GpioOutputPin initOutput(Pin pin) {
    _init(pin, GPIO_MODE_OUTPUT_PP, GPIO_PULLUP, GPIO_SPEED_FREQ_HIGH);
    return new _STM32GpioOutputPin._(pin);
  }

  GpioInputPin initInput(
      Pin pin, {GpioPullUpDown pullUpDown, GpioInterruptTrigger trigger}) {
    int pull = GPIO_NOPULL;
    if (pullUpDown != null && pullUpDown != GpioPullUpDown.floating) {
      pull = pullUpDown == GpioPullUpDown.pullUp ? GPIO_PULLUP : GPIO_PULLDOWN;
    }
    _init(pin, GPIO_MODE_INPUT, pull, GPIO_SPEED_FREQ_HIGH);
    return new _STM32GpioInputPin._(pin);
  }

  Stm32PwmOutputPin initPwmOutput(Pin pin) {
    STM32Pin sp = pin;
    if (sp._pwm == null) {
      throw new ArgumentError("The pin ${pin} doesn't support PWM");
    }
    _init(pin, GPIO_MODE_AF_PP, GPIO_PULLUP, GPIO_SPEED_FREQ_HIGH);
    sp.setAlternateFunction(sp._pwm.timer.alternativeFunction);
    return new Stm32PwmOutputPin._(pin, 
      sp._pwm.timer.busClock(_apb1Clock, _apb2Clock));
  }

  /// Initializes a STM32 pin for analog mode. Disables output buffer, Schmitt
  /// trigger, and pull-up/pull-down resistors. This mode enables the pin to
  /// be sampled by the ADC.
  void initSTM32Analog(Pin pin) {
    _init(pin, GPIO_MODE_ANALOG, GPIO_NOPULL, GPIO_SPEED_FREQ_HIGH);
  }

  void _init(STM32Pin pin, int mode, int pull, int speed) {
    if (pin is! STM32Pin) {
      throw new ArgumentError('Illegal pin type');
    }
    STM32Pin p = pin;
    int base = p._port._base;
    int temp;

    // Enable clock for the GPIO port (RCC->AHB1ENR).
    int ahb1enrOffset = RCC_BASE - PERIPH_BASE + RCC.AHB1ENR;
    temp = peripherals.getUint32(ahb1enrOffset);
    temp |= p._port._ahb1enr;
    peripherals.setUint32(ahb1enrOffset, temp);
    // Delay after an RCC peripheral clock enabling.
    peripherals.getUint32(ahb1enrOffset);

    // Configure pin mode (GPIOx->MODER).
    temp = peripherals.getUint32(base + MODER);
    temp &= ~(GPIO_MODER_MODER0 << (p.pin * 2));
    temp |= ((mode & GPIO_MODE) << (p.pin * 2));
    peripherals.setUint32(base + MODER, temp);

    // Configure the IO speed (GPIOx->OSPEEDR).
    temp = peripherals.getUint32(base + OSPEEDR);
    temp &= ~(GPIO_OSPEEDER_OSPEEDR0 << (p.pin * 2));
    temp |= (speed << (p.pin * 2));
    peripherals.setUint32(base + OSPEEDR, temp);

    // Configure the IO output type (GPIOx->OTYPER).
    temp = peripherals.getUint32(base + OTYPER);
    temp &= ~(GPIO_OTYPER_OT_0 << p.pin);
    temp |= (((mode & GPIO_OUTPUT_TYPE) >> 4) << p.pin);
    peripherals.setUint32(base + OTYPER, temp);

    // Activate the pull-up/pull-down resistor (GPIOx->PUPDR).
    temp = peripherals.getUint32(base + PUPDR);
    temp &= ~(GPIO_PUPDR_PUPDR0 << (p.pin * 2));
    temp |= (pull << (p.pin * 2));
    peripherals.setUint32(base + PUPDR, temp);
  }
}
