// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.src.constants;

// Base address of AHB/ABP peripherals.
//
// These are from
// stm32cube_fw_f7/Drivers/CMSIS/Device/ST/STM32F7xx/Include/stm32f746xx.h
//
// Not all models have all the peripherals that F7 has, but the common
// parts have the same addresses.
const int PERIPH_BASE = 0x40000000;

const int APB1PERIPH_BASE = PERIPH_BASE;
const int APB2PERIPH_BASE = PERIPH_BASE + 0x00010000;
const int AHB1PERIPH_BASE = PERIPH_BASE + 0x00020000;
const int AHB2PERIPH_BASE = PERIPH_BASE + 0x10000000;

const int GPIOA_BASE = AHB1PERIPH_BASE + 0x0000;
const int GPIOB_BASE = AHB1PERIPH_BASE + 0x0400;
const int GPIOC_BASE = AHB1PERIPH_BASE + 0x0800;
const int GPIOD_BASE = AHB1PERIPH_BASE + 0x0C00;
const int GPIOE_BASE = AHB1PERIPH_BASE + 0x1000;
const int GPIOF_BASE = AHB1PERIPH_BASE + 0x1400;
const int GPIOG_BASE = AHB1PERIPH_BASE + 0x1800;
const int GPIOH_BASE = AHB1PERIPH_BASE + 0x1C00;
const int GPIOI_BASE = AHB1PERIPH_BASE + 0x2000;
const int GPIOJ_BASE = AHB1PERIPH_BASE + 0x2400;
const int GPIOK_BASE = AHB1PERIPH_BASE + 0x2800;
const int CRC_BASE = AHB1PERIPH_BASE + 0x3000;
const int RCC_BASE = AHB1PERIPH_BASE + 0x3800;
const int FLASH_R_BASE = AHB1PERIPH_BASE + 0x3C00;
const int DMA1_BASE = AHB1PERIPH_BASE + 0x6000;
const int DMA2_BASE = AHB1PERIPH_BASE + 0x6400;
const int ETH_BASE = AHB1PERIPH_BASE + 0x8000;
const int DMA2D_BASE = AHB1PERIPH_BASE + 0xB000;

const int ADC1_BASE = APB2PERIPH_BASE + 0x2000;
const int ADC2_BASE = APB2PERIPH_BASE + 0x2100;
const int ADC3_BASE = APB2PERIPH_BASE + 0x2200;
const int ADC_COMMON_BASE = APB2PERIPH_BASE + 0x2300;

// Reset and Clock Control (RCC) registers.
//
// These are offsets into the peripheral registers from offset RCC_BASE.
class RCC {
  static const int CR = 0x00; // RCC clock control register.
  static const int PLLCFGR = 0x04; // RCC PLL configuration register.
  static const int CFGR = 0x08; // RCC clock configuration register.
  static const int CIR = 0x0C; // RCC clock interrupt register.
  static const int AHB1RSTR = 0x10; // RCC AHB1 peripheral reset register.
  static const int AHB2RSTR = 0x14; // RCC AHB2 peripheral reset register.
  static const int AHB3RSTR = 0x18; // RCC AHB3 peripheral reset register.
  // Reserved, 0x1C.
  static const int APB1RSTR = 0x20; // RCC APB1 peripheral reset register.
  static const int APB2RSTR = 0x24; // RCC APB2 peripheral reset register.
  // Reserved, 0x28-0x2C.
  static const int AHB1ENR = 0x30; // RCC AHB1 peripheral clock register
  static const int AHB2ENR = 0x34; // RCC AHB2 peripheral clock register.
  static const int AHB3ENR = 0x38; // RCC AHB3 peripheral clock register.
  // Reserved, 0x3C.
  static const int APB1ENR = 0x40; // RCC APB1 peripheral clock enable register.
  static const int APB2ENR = 0x44; // RCC APB2 peripheral clock enable register.
  // Reserved, 0x48-0x4C.
  // RCC AHB1 peripheral clock enable in low power mode register.
  static const int AHB1LPENR = 0x50;
  // RCC AHB2 peripheral clock enable in low power mode register.
  static const int AHB2LPENR = 0x54;
  // RCC AHB3 peripheral clock enable in low power mode register.
  static const int AHB3LPENR = 0x58;
  // Reserved, 0x5C.
  // RCC APB1 peripheral clock enable in low power mode register.
  static const int APB1LPENR = 0x60;
  // RCC APB2 peripheral clock enable in low power mode register.
  static const int APB2LPENR = 0x64;
  // Reserved, 0x68-0x6C.
  static const int BDCR = 0x70; // RCC Backup domain control register.
  static const int CSR = 0x74; // RCC clock control & status register.
  // Reserved, 0x78-0x7C.
  // RCC spread spectrum clock generation register.
  static const int SSCGR = 0x80;
  static const int PLLI2SCFGR = 0x84; // RCC PLLI2S configuration register.
  static const int PLLSAICFGR = 0x88; // RCC PLLSAI configuration register.
  // RCC Dedicated Clocks configuration register1.
  static const int DCKCFGR1 = 0x8C;
  // RCC Dedicated Clocks configuration register 2.
  static const int DCKCFGR2 = 0x90;
}

// Bit definition for RCC_AHB1ENR register
const int RCC_AHB1ENR_GPIOAEN = 0x00000001;
const int RCC_AHB1ENR_GPIOBEN = 0x00000002;
const int RCC_AHB1ENR_GPIOCEN = 0x00000004;
const int RCC_AHB1ENR_GPIODEN = 0x00000008;
const int RCC_AHB1ENR_GPIOEEN = 0x00000010;
const int RCC_AHB1ENR_GPIOFEN = 0x00000020;
const int RCC_AHB1ENR_GPIOGEN = 0x00000040;
const int RCC_AHB1ENR_GPIOHEN = 0x00000080;
const int RCC_AHB1ENR_GPIOIEN = 0x00000100;
const int RCC_AHB1ENR_GPIOJEN = 0x00000200;
const int RCC_AHB1ENR_GPIOKEN = 0x00000400;
const int RCC_AHB1ENR_CRCEN = 0x00001000;
const int RCC_AHB1ENR_BKPSRAMEN = 0x00040000;
const int RCC_AHB1ENR_DTCMRAMEN = 0x00100000;
const int RCC_AHB1ENR_DMA1EN = 0x00200000;
const int RCC_AHB1ENR_DMA2EN = 0x00400000;
const int RCC_AHB1ENR_DMA2DEN = 0x00800000;
const int RCC_AHB1ENR_ETHMACEN = 0x02000000;
const int RCC_AHB1ENR_ETHMACTXEN = 0x04000000;
const int RCC_AHB1ENR_ETHMACRXEN = 0x08000000;
const int RCC_AHB1ENR_ETHMACPTPEN = 0x10000000;
const int RCC_AHB1ENR_OTGHSEN = 0x20000000;
const int RCC_AHB1ENR_OTGHSULPIEN = 0x40000000;

// Bit definition for RCC_APB2ENR register
const int RCC_APB2ENR_TIM1EN = 0x00000001;
const int RCC_APB2ENR_TIM8EN = 0x00000002;
const int RCC_APB2ENR_USART1EN = 0x00000010;
const int RCC_APB2ENR_USART6EN = 0x00000020;
const int RCC_APB2ENR_ADC1EN = 0x00000100;
const int RCC_APB2ENR_ADC2EN = 0x00000200;
const int RCC_APB2ENR_ADC3EN = 0x00000400;
const int RCC_APB2ENR_SDMMC1EN = 0x00000800;
const int RCC_APB2ENR_SPI1EN = 0x00001000;
const int RCC_APB2ENR_SPI4EN = 0x00002000;
const int RCC_APB2ENR_SYSCFGEN = 0x00004000;
const int RCC_APB2ENR_TIM9EN = 0x00010000;
const int RCC_APB2ENR_TIM10EN = 0x00020000;
const int RCC_APB2ENR_TIM11EN = 0x00040000;
const int RCC_APB2ENR_SPI5EN = 0x00100000;
const int RCC_APB2ENR_SPI6EN = 0x00200000;
const int RCC_APB2ENR_SAI1EN = 0x00400000;
const int RCC_APB2ENR_SAI2EN = 0x00800000;
const int RCC_APB2ENR_LTDCEN = 0x04000000;

// Offset to GPIO registers for each GPIO port.
//
// These are from the GPIO_TypeDef in
// stm32cube_fw_f7/Drivers/CMSIS/Device/ST/STM32F7xx/Include/stm32f746xx.h
const int MODER = 0x00; // GPIO port mode register.
const int OTYPER = 0x04; // GPIO port output type register.
const int OSPEEDR = 0x08; // GPIO port output speed register.
const int PUPDR = 0x0c; // GPIO port pull-up/pull-down register.
const int IDR = 0x10; // GPIO port input data register.
const int ODR = 0x14; // GPIO port output data register.
const int BSRR = 0x18; // GPIO port bit set/reset register.
const int LCKR = 0x1c; // GPIO port configuration lock register.
const int AFR = 0x20; // GPIO alternate function registers.
const int AFR_1 = 0x20; // GPIO alternate function register 1.
const int AFR_2 = 0x24; // GPIO alternate function register 2.

// GPIO modes.
// Input Floating Mode.
const int GPIO_MODE_INPUT = 0x00000000;
// Output Push Pull Mode.
const int GPIO_MODE_OUTPUT_PP = 0x00000001;
// Output Open Drain Mode.
const int GPIO_MODE_OUTPUT_OD = 0x00000011;
// Alternate Function Push Pull Mode.
const int GPIO_MODE_AF_PP = 0x00000002;
// Alternate Function Open Drain Mode.
const int GPIO_MODE_AF_OD = 0x00000012;
// Analog Mode.
const int GPIO_MODE_ANALOG = 0x00000003;
// External Interrupt Mode with Rising edge trigger detection.
const int GPIO_MODE_IT_RISING = 0x10110000;
// External Interrupt Mode with Falling edge trigger detection
const int GPIO_MODE_IT_FALLING = 0x10210000;
// External Interrupt Mode with Rising/Falling edge trigger detection.
const int GPIO_MODE_IT_RISING_FALLING = 0x10310000;
// External Event Mode with Rising edge trigger detection.
const int GPIO_MODE_EVT_RISING = 0x10120000;
// External Event Mode with Falling edge trigger detection.
const int GPIO_MODE_EVT_FALLING = 0x10220000;
// External Event Mode with Rising/Falling edge trigger detection.
const int GPIO_MODE_EVT_RISING_FALLING = 0x10320000;

// GPIO speed.
const int GPIO_SPEED_FREQ_LOW = 0x00000000;
const int GPIO_SPEED_FREQ_MEDIUM = 0x00000001;
const int GPIO_SPEED_FREQ_HIGH = 0x00000002;
const int GPIO_SPEED_FREQ_VERY_HIGH = 0x00000003;

// GPIO pull-up/pull-down.
const int GPIO_NOPULL = 0x00000000;
const int GPIO_PULLUP = 0x00000001;
const int GPIO_PULLDOWN = 0x00000002;

// Mode bits (two bits per pin).
const int GPIO_MODER_MODER0 = 0x00000003;

// Output type bits (one bit per pin).
const int GPIO_OTYPER_OT_0 = 0x00000001;

// IO speed bits (two bits per pin).
const int GPIO_OSPEEDER_OSPEEDR0 = 0x00000003;

// Pull-up/pull-down (two bits per pin).
const int GPIO_PUPDR_PUPDR0 = 0x00000003;

// Masks.
const int GPIO_MODE = 0x00000003;
const int EXTI_MODE = 0x10000000;
const int GPIO_MODE_IT = 0x00010000;
const int GPIO_MODE_EVT = 0x00020000;
const int RISING_EDGE = 0x00100000;
const int FALLING_EDGE = 0x00200000;
const int GPIO_OUTPUT_TYPE = 0x00000010;

// Analog-to-digital converter (ADC) registers.
class ADC {
  // Offset to ADC registers for each ADC port, relative to port base.
  static const int SR = 0x00; // ADC status register.
  static const int CR1 = 0x04; // ADC control register 1.
  static const int CR2 = 0x08; // ADC control register 2.
  static const int SMPR1 = 0x0C; // ADC sample time register 1.
  static const int SMPR2 = 0x10; // ADC sample time register 2.
  static const int JOFR1 = 0x14; // ADC injected channel data offset register 1.
  static const int JOFR2 = 0x18; // ADC injected channel data offset register 2.
  static const int JOFR3 = 0x1C; // ADC injected channel data offset register 3.
  static const int JOFR4 = 0x20; // ADC injected channel data offset register 4.
  static const int HTR = 0x24; // ADC watchdog higher threshold register.
  static const int LTR = 0x28; // ADC watchdog lower threshold register.
  static const int SQR1 = 0x2C; // ADC regular sequence register 1.
  static const int SQR2 = 0x30; // ADC regular sequence register 2.
  static const int SQR3 = 0x34; // ADC regular sequence register 3.
  static const int JSQR = 0x38; // ADC injected sequence register.
  static const int JDR1 = 0x3C; // ADC injected data register 1.
  static const int JDR2 = 0x40; // ADC injected data register 2.
  static const int JDR3 = 0x44; // ADC injected data register 3.
  static const int JDR4 = 0x48; // ADC injected data register 4.
  static const int DR = 0x4C; // ADC regular data register.

  // Common register offsets, relative to ADC_COMMON_BASE.
  static const int CSR = 0x00; // ADC common status register.
  static const int CCR = 0x04; // ADC common control register.
  // ADC common regular data register for dual and triple modes.
  static const int CDR = 0x08;
}

// Analog to Digital Converter (ADC).

// Bit definition for ADC_SR register.
const int ADC_SR_AWD = 0x00000001; // Analog watchdog flag.
const int ADC_SR_EOC = 0x00000002; // End of conversion.
const int ADC_SR_JEOC = 0x00000004; // Injected channel end of conversion.
const int ADC_SR_JSTRT = 0x00000008; // Injected channel Start flag.
const int ADC_SR_STRT = 0x00000010; // Regular channel Start flag.
const int ADC_SR_OVR = 0x00000020; // Overrun flag.

// Bit definition for ADC_CR1 register.

// AWDCH[4:0] bits (Analog watchdog channel select bits).
const int ADC_CR1_AWDCH_MASK = 0x0000001F;
// Interrupt enable for EOC.
const int ADC_CR1_EOCIE = 0x00000020;
// Analog Watchdog interrupt enable.
const int ADC_CR1_AWDIE = 0x00000040;
// Interrupt enable for injected channels.
const int ADC_CR1_JEOCIE = 0x00000080;
// Scan mode.
const int ADC_CR1_SCAN = 0x00000100;
// Enable the watchdog on a single channel in scan mode.
const int ADC_CR1_AWDSGL = 0x00000200;
// Automatic injected group conversion.
const int ADC_CR1_JAUTO = 0x00000400;
// Discontinuous mode on regular channels.
const int ADC_CR1_DISCEN = 0x00000800;
// Discontinuous mode on injected channels.
const int ADC_CR1_JDISCEN = 0x00001000;
// DISCNUM[2:0] bits (Discontinuous mode channel count).
const int ADC_CR1_DISCNUM_MASK = 0x0000E000;
// Analog watchdog enable on injected channels.
const int ADC_CR1_JAWDEN = 0x00400000;
// Analog watchdog enable on regular channels.
const int ADC_CR1_AWDEN = 0x00800000;
// RES[2:0] bits (Resolution).
const int ADC_CR1_RES_MASK = 0x03000000;
const int ADC_CR1_RES_12BIT = 0x00000000;
const int ADC_CR1_RES_10BIT = 0x01000000;
const int ADC_CR1_RES_8BIT = 0x02000000;
const int ADC_CR1_RES_6BIT = 0x03000000;
// Overrun interrupt enable.
const int ADC_CR1_OVRIE = 0x04000000;

// Bit definition for ADC_CR2 register.

// A/D Converter ON / OFF.
const int ADC_CR2_ADON = 0x00000001;
// Continuous Conversion.
const int ADC_CR2_CONT = 0x00000002;
// Direct Memory access mode.
const int ADC_CR2_DMA = 0x00000100;
// DMA disable selection (Single ADC).
const int ADC_CR2_DDS = 0x00000200;
// End of conversion selection.
const int ADC_CR2_EOCS = 0x00000400;
// Data Alignment.
const int ADC_CR2_ALIGN_MASK = 0x00000800;
const int ADC_CR2_ALIGN_RIGHT = 0x00000000;
const int ADC_CR2_ALIGN_LEFT = 0x00000800;
// JEXTSEL[3:0] bits (External event select for injected group).
const int ADC_CR2_JEXTSEL_MASK = 0x000F0000;
// JEXTEN[1:0] bits (External Trigger Conversion mode for injected channelsp).
const int ADC_CR2_JEXTEN_MASK = 0x00300000;
// Start Conversion of injected channels.
const int ADC_CR2_JSWSTART = 0x00400000;
// EXTSEL[3:0] bits (External Event Select for regular group).
const int ADC_CR2_EXTSEL_MASK = 0x0F000000;
// EXTEN[1:0] bits (External Trigger Conversion mode for regular channelsp).
const int ADC_CR2_EXTEN_MASK = 0x30000000;
// Start Conversion of regular channels.
const int ADC_CR2_SWSTART = 0x40000000;

// Bit definition for ADC_SMPRx registers.

// Channel x Sample time mask.
const int ADC_SMPR_MASK = 0x00000007;
// Sampling time selections (ADCCLK cycles).
const int ADC_SMPR_CYCLES_3 = 0x00000000;
const int ADC_SMPR_CYCLES_15 = 0x00000001;
const int ADC_SMPR_CYCLES_28 = 0x00000002;
const int ADC_SMPR_CYCLES_56 = 0x00000003;
const int ADC_SMPR_CYCLES_84 = 0x00000004;
const int ADC_SMPR_CYCLES_112 = 0x00000005;
const int ADC_SMPR_CYCLES_144 = 0x00000006;
const int ADC_SMPR_CYCLES_480 = 0x00000007;

// Bit definition for ADC_JOFR1 register.

// Data offset for injected channel 1.
const int ADC_JOFR1_JOFFSET1_MASK = 0x0FFF;

// Bit definition for ADC_JOFR2 register.

// Data offset for injected channel 2.
const int ADC_JOFR2_JOFFSET2_MASK = 0x0FFF;

// Bit definition for ADC_JOFR3 register.

// Data offset for injected channel 3.
const int ADC_JOFR3_JOFFSET3_MASK = 0x0FFF;

// Bit definition for ADC_JOFR4 register.

// Data offset for injected channel 4.
const int ADC_JOFR4_JOFFSET4_MASK = 0x0FFF;

// Bit definition for ADC_HTR register.
const int ADC_HTR_HT_MASK = 0x0FFF; // Analog watchdog high threshold.

// Bit definition for ADC_LTR register.
const int ADC_LTR_LT_MASK = 0x0FFF; // Analog watchdog low threshold.

// Bit definition for ADC_SQRx registers.

// Regular sequence channel mask.
const int ADC_SQR_MASK = 0x0000001F;
// L[3:0] bits (Regular channel sequence length).
const int ADC_SQR1_L_MASK = 0x00F00000;

// Bit definition for ADC_JSQR register.

// JSQ1[4:0] bits (1st conversion in injected sequence).
const int ADC_JSQR_JSQ1_MASK = 0x0000001F;
// JSQ2[4:0] bits (2nd conversion in injected sequence).
const int ADC_JSQR_JSQ2_MASK = 0x000003E0;
// JSQ3[4:0] bits (3rd conversion in injected sequence).
const int ADC_JSQR_JSQ3_MASK = 0x00007C00;
// JSQ4[4:0] bits (4th conversion in injected sequence).
const int ADC_JSQR_JSQ4_MASK = 0x000F8000;
// JL[1:0] bits (Injected Sequence length).
const int ADC_JSQR_JL_MASK = 0x00300000;

// Bit definition for ADC_JDR1 register.
const int ADC_JDR1_JDATA_MASK = 0xFFFF; // Injected data.

// Bit definition for ADC_JDR2 register.
const int ADC_JDR2_JDATA_MASK = 0xFFFF; // Injected data.

// Bit definition for ADC_JDR3 register.
const int ADC_JDR3_JDATA_MASK = 0xFFFF; // Injected data.

// Bit definition for ADC_JDR4 register.
const int ADC_JDR4_JDATA_MASK = 0xFFFF; // Injected data.

// Bit definition for ADC_DR register.
const int ADC_DR_DATA_MASK = 0x0000FFFF; // Regular data.
const int ADC_DR_ADC2DATA_MASK = 0xFFFF0000; // ADC2 data.

// Bit definition for ADC_CSR register.

// ADC1 Analog watchdog flag.
const int ADC_CSR_AWD1 = 0x00000001;
// ADC1 End of conversion.
const int ADC_CSR_EOC1 = 0x00000002;
// ADC1 Injected channel end of conversion.
const int ADC_CSR_JEOC1 = 0x00000004;
// ADC1 Injected channel Start flag.
const int ADC_CSR_JSTRT1 = 0x00000008;
// ADC1 Regular channel Start flag.
const int ADC_CSR_STRT1 = 0x00000010;
// ADC1 Overrun flag.
const int ADC_CSR_OVR1 = 0x00000020;
// ADC2 Analog watchdog flag.
const int ADC_CSR_AWD2 = 0x00000100;
// ADC2 End of conversion.
const int ADC_CSR_EOC2 = 0x00000200;
// ADC2 Injected channel end of conversion.
const int ADC_CSR_JEOC2 = 0x00000400;
// ADC2 Injected channel Start flag.
const int ADC_CSR_JSTRT2 = 0x00000800;
// ADC2 Regular channel Start flag.
const int ADC_CSR_STRT2 = 0x00001000;
// ADC2 Overrun flag.
const int ADC_CSR_OVR2 = 0x00002000;
// ADC3 Analog watchdog flag.
const int ADC_CSR_AWD3 = 0x00010000;
// ADC3 End of conversion.
const int ADC_CSR_EOC3 = 0x00020000;
// ADC3 Injected channel end of conversion.
const int ADC_CSR_JEOC3 = 0x00040000;
// ADC3 Injected channel Start flag.
const int ADC_CSR_JSTRT3 = 0x00080000;
// ADC3 Regular channel Start flag.
const int ADC_CSR_STRT3 = 0x00100000;
// ADC3 Overrun flag.
const int ADC_CSR_OVR3 = 0x00200000;

// Bit definition for ADC_CCR register.

// MULTI[4:0] bits (Multi-ADC mode selection).
const int ADC_CCR_MULTI_MASK = 0x0000001F;
// DELAY[3:0] bits (Delay between 2 sampling phases).
const int ADC_CCR_DELAY_MASK = 0x00000F00;
// DMA disable selection (Multi-ADC mode).
const int ADC_CCR_DDS = 0x00002000;
// DMA[1:0] bits (Direct Memory Access mode for multimode).
const int ADC_CCR_DMA_MASK = 0x0000C000;
// ADCPRE[1:0] bits (ADC clock prescaler).
const int ADC_CCR_ADCPRE_MASK = 0x00030000;
const int ADC_CCR_ADCPRE_PCLK2_DIV_2 = 0x00000000;
const int ADC_CCR_ADCPRE_PCLK2_DIV_4 = 0x00010000;
const int ADC_CCR_ADCPRE_PCLK2_DIV_6 = 0x00020000;
const int ADC_CCR_ADCPRE_PCLK2_DIV_8 = 0x00030000;
// VBAT Enable.
const int ADC_CCR_VBATE = 0x00400000;
// Temperature Sensor and VREFINT Enable.
const int ADC_CCR_TSVREFE = 0x00800000;

// Bit definition for ADC_CDR register.

// 1st data of a pair of regular conversions.
const int ADC_CDR_DATA1_MASK = 0x0000FFFF;
// 2nd data of a pair of regular conversions.
const int ADC_CDR_DATA2_MASK = 0xFFFF0000;

// DMA controller registers.
class DMA {
  // Interrupt status registers, relative to DMA controller base.
  static const int LISR = 0x00; // Low Interrupt Status Register.
  static const int HISR = 0x04; // High Interrupt Status Register.
  static const int LIFCR = 0x08; // Low Interrupt Flag Clear Register.
  static const int HIFCR = 0x0C; // High Interrupt Flag Clear Register.

  static const int STREAM_OFFSET = 0x18; // Stream register offset multiplier.

  // Stream registers.
  // Relative to DMA controller base + STREAM_OFFSET * stream number.
  static const int SxCR = 0x10; // Stream Configuration Register.
  static const int SxNDTR = 0x14; // Stream Number of Data Register.
  static const int SxPAR = 0x18; // Stream Peripheral Address Register.
  static const int SxM0AR = 0x1C; // Stream Memory 0 Address Register.
  static const int SxM1AR = 0x20; // Stream Memory 1 Address Register.
  static const int SxFCR = 0x24; // Stream FIFO Control Register.
}

// DMA Controller.

// Bit definitions for DMA_SxCR register.
const int DMA_SxCR_CHSEL_MASK = 0x0E000000;
const int DMA_SxCR_CHSEL_SHIFT = 25;
const int DMA_SxCR_MBURST_MASK = 0x01800000;
const int DMA_SxCR_PBURST_MASK = 0x00600000;
const int DMA_SxCR_CT = 0x00080000;
const int DMA_SxCR_DBM = 0x00040000;
const int DMA_SxCR_PL_MASK = 0x00030000;
const int DMA_SxCR_PL_LOW = 0x00000000;
const int DMA_SxCR_PL_MEDIUM = 0x00010000;
const int DMA_SxCR_PL_HIGH = 0x00020000;
const int DMA_SxCR_PL_VERY_HIGH = 0x00030000;
const int DMA_SxCR_PINCOS = 0x00008000;
const int DMA_SxCR_MSIZE_MASK = 0x00006000;
const int DMA_SxCR_MSIZE_BYTE = 0x00000000;
const int DMA_SxCR_MSIZE_HALF_WORD = 0x00002000;
const int DMA_SxCR_MSIZE_WORD = 0x00004000;
const int DMA_SxCR_PSIZE_MASK = 0x00001800;
const int DMA_SxCR_PSIZE_BYTE = 0x00000000;
const int DMA_SxCR_PSIZE_HALF_WORD = 0x00000800;
const int DMA_SxCR_PSIZE_WORD = 0x00001000;
const int DMA_SxCR_MINC = 0x00000400;
const int DMA_SxCR_PINC = 0x00000200;
const int DMA_SxCR_CIRC = 0x00000100;
const int DMA_SxCR_DIR_MASK = 0x000000C0;
const int DMA_SxCR_DIR_PERIPHERAL_TO_MEMORY = 0x00000000;
const int DMA_SxCR_DIR_MEMORY_TO_PERIPHERAL = 0x00000040;
const int DMA_SxCR_DIR_MEMORY_TO_MEMORY = 0x00000080;
const int DMA_SxCR_PFCTRL = 0x00000020;
const int DMA_SxCR_TCIE = 0x00000010;
const int DMA_SxCR_HTIE = 0x00000008;
const int DMA_SxCR_TEIE = 0x00000004;
const int DMA_SxCR_DMEIE = 0x00000002;
const int DMA_SxCR_EN = 0x00000001;

// Bit definitions for DMA_SxNDTR register.
const int DMA_SxNDTR_MASK = 0x0000FFFF;

// Bit definitions for DMA_SxFCR register.
const int DMA_SxFCR_FEIE = 0x00000080;
const int DMA_SxFCR_FS_MASK = 0x00000038;
const int DMA_SxFCR_DMDIS = 0x00000004;
const int DMA_SxFCR_FTH_MASK = 0x00000003;
const int DMA_SxFCR_FTH_1_4 = 0x00000000;
const int DMA_SxFCR_FTH_HALF = 0x00000001;
const int DMA_SxFCR_FTH_3_4 = 0x00000002;
const int DMA_SxFCR_FTH_FULL = 0x00000003;

// Bit definitions for DMA_(H/L)ISR register.
const int DMA_ISR_MASK = 0x0000003D;
const int DMA_ISR_TCIF = 0x00000020;
const int DMA_ISR_HTIF = 0x00000010;
const int DMA_ISR_TEIF = 0x00000008;
const int DMA_ISR_DMEIF = 0x00000004;
const int DMA_ISR_FEIF = 0x00000001;

// Bits definition for DMA_(H/L)IFCR register.
const int DMA_IFCR_MASK = 0x0000003D;
const int DMA_IFCR_CTCIF = 0x00000020;
const int DMA_IFCR_CHTIF = 0x00000010;
const int DMA_IFCR_CTEIF = 0x00000008;
const int DMA_IFCR_CDMEIF = 0x00000004;
const int DMA_IFCR_CFEIF = 0x00000001;
