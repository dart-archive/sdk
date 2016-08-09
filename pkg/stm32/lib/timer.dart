// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.timer;

import 'dart:dartino.ffi';

import 'package:stm32/gpio.dart';
import 'package:stm32/src/constants.dart';
import 'package:stm32/src/peripherals.dart';

class StmTimer {
  final int alternativeFunction;
  final int _base;
  final int _enableReg;
  final int _enableMask;
  static const StmTimer timer1 =
    const StmTimer(1, TIM1_BASE, RCC.APB2ENR, RCC_APB2ENR_TIM1EN);
  static const StmTimer timer2 =
    const StmTimer(1, TIM2_BASE, RCC.APB1ENR, RCC_APB1ENR_TIM2EN);
  static const StmTimer timer3 =
    const StmTimer(2, TIM3_BASE, RCC.APB1ENR, RCC_APB1ENR_TIM3EN);
  static const StmTimer timer4 =
    const StmTimer(2, TIM4_BASE, RCC.APB1ENR, RCC_APB1ENR_TIM4EN);
  static const StmTimer timer5 =
    const StmTimer(2, TIM5_BASE, RCC.APB1ENR, RCC_APB1ENR_TIM5EN);
  // TIM6-7 are not usable for PWM
  static const StmTimer timer8 =
    const StmTimer(3, TIM8_BASE, RCC.APB2ENR, RCC_APB2ENR_TIM8EN);
  static const StmTimer timer9 =
    const StmTimer(3, TIM9_BASE, RCC.APB2ENR, RCC_APB2ENR_TIM9EN);
  static const StmTimer timer10 =
    const StmTimer(3, TIM10_BASE, RCC.APB2ENR, RCC_APB2ENR_TIM10EN);
  static const StmTimer timer11 =
    const StmTimer(3, TIM11_BASE, RCC.APB2ENR, RCC_APB2ENR_TIM11EN);
  static const StmTimer timer12 =
    const StmTimer(9, TIM12_BASE, RCC.APB1ENR, RCC_APB1ENR_TIM12EN);

  const StmTimer(this.alternativeFunction, this._base,
    this._enableReg, this._enableMask);

  int _read(int offset) {
    return peripherals.getUint32(_base - PERIPH_BASE + offset);
  }

  int _write(int offset, int value) {
    return peripherals.setUint32(_base - PERIPH_BASE + offset, value);
  }

  _enableClock() {
    // Enable RCC clock to TIMx
    int reg = peripherals.getUint32(RCC_BASE - PERIPH_BASE + _enableReg);
    reg |= _enableMask;
    peripherals.setUint32(RCC_BASE - PERIPH_BASE + _enableReg, reg);
  }

  _enable() {
    int cr1 = _read(TIM.CR1);
    cr1 |= TIM_CR1_CEN;
    _write(TIM.CR1, cr1);
  }

  setPrescaler(int prescaler) {
    _write(TIM.PSC, prescaler);
  }

  setPeriod(int period) {
    _write(TIM.ARR, period);
  }

  // Pick appropriate clock for this timer.
  int busClock(int apb1Clock, int apb2Clock) {
    return _enableReg == RCC.APB2ENR ? apb2Clock : apb1Clock;
  }

  setup() {
    _enableClock();
    // Enable preload of auto-reload register
    int cr1 = _read(TIM.CR1);
    cr1 |= TIM_CR1_ARPE;
    _write(TIM.CR1, cr1);
  }

  setupPwmOutput(int channel) {
    _enable();
    // For advanced timer only - set Main Output Enable
    _write(TIM.BDTR, TIM_BDTR_MOE);
    switch (channel) {
      case 1:
        int ccmr = _read(TIM.CCMR1);
        int mask = TIM_CCMR1_OC1M_0 | TIM_CCMR1_OC1M_1 | TIM_CCMR1_OC1M_2;
        _write(TIM.CCMR1, ccmr | mask);
        int ccer = _read(TIM.CCER);
        // Enable both main and complementary outputs
        // which ever is configured going to produce the signal.
        _write(TIM.CCER, ccer | TIM_CCER_CC1P | TIM_CCER_CC1E | TIM_CCER_CC1NE);
        _write(TIM.EGR, TIM_EGR_UG);
        break;
      case 2:
        int ccmr = _read(TIM.CCMR1);
        int mask = TIM_CCMR1_OC2M_0 | TIM_CCMR1_OC2M_1 | TIM_CCMR1_OC2M_2;
        _write(TIM.CCMR1, ccmr | mask);
        int ccer = _read(TIM.CCER);
        // ditto
        _write(TIM.CCER, ccer | TIM_CCER_CC2P | TIM_CCER_CC2E | TIM_CCER_CC2NE);
        _write(TIM.EGR, TIM_EGR_UG);
        break;
      case 3:
        int ccmr = _read(TIM.CCMR2);
        int mask = TIM_CCMR2_OC3M_0 | TIM_CCMR2_OC3M_1 | TIM_CCMR2_OC3M_2;
        _write(TIM.CCMR2, ccmr | mask);
        int ccer = _read(TIM.CCER);
        // ditto
        _write(TIM.CCER, ccer | TIM_CCER_CC3P | TIM_CCER_CC3E | TIM_CCER_CC3NE);
        _write(TIM.EGR, TIM_EGR_UG);
        break;
      case 4:
        int ccmr = _read(TIM.CCMR2);
        int mask = TIM_CCMR2_OC4M_0 | TIM_CCMR2_OC4M_1 | TIM_CCMR2_OC4M_2;
        _write(TIM.CCMR2, ccmr | mask);
        int ccer = _read(TIM.CCER);
        _write(TIM.CCER, ccer | TIM_CCER_CC4P | TIM_CCER_CC4E);
        _write(TIM.EGR, TIM_EGR_UG);
        break;
      case 5:
        int ccmr = _read(TIM.CCMR3);
        int mask = TIM_CCMR3_OC5M_0 | TIM_CCMR3_OC5M_1 | TIM_CCMR3_OC5M_2;
        _write(TIM.CCMR3, ccmr | mask);
        int ccer = _read(TIM.CCER);
        _write(TIM.CCER, ccer | TIM_CCER_CC5P | TIM_CCER_CC5E);
        _write(TIM.EGR, TIM_EGR_UG);
        break;
      case 6:
        int ccmr = _read(TIM.CCMR3);
        int mask = TIM_CCMR3_OC6M_0 | TIM_CCMR3_OC6M_1 | TIM_CCMR3_OC6M_2;
        _write(TIM.CCMR3, ccmr | mask);
        int ccer = _read(TIM.CCER);
        _write(TIM.CCER, ccer | TIM_CCER_CC6P | TIM_CCER_CC6E);
        _write(TIM.EGR, TIM_EGR_UG);
        break;
      default:
        throw new ArgumentError("Only 1-6 are allowed channels");
    }
  }

  setPwmLevel(int channel, int level) {
    switch(channel){
      case 1:
        _write(TIM.CCR1, level);
        break;
      case 2:
        _write(TIM.CCR2, level);
        break;
      case 3:
        _write(TIM.CCR3, level);
        break;
      case 4:
        _write(TIM.CCR4, level);
        break;
      case 5:
        _write(TIM.CCR5, level);
        break;
      case 6:
        _write(TIM.CCR6, level);
        break;
      default:
        throw new ArgumentError("Only 1-6 are allowed channels");
    }
  }
}
