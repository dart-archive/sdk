// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.dma;

import 'dart:dartino';
import 'dart:dartino.ffi';
import 'dart:dartino.os';

import 'package:stm32/src/constants.dart';
import 'package:stm32/src/peripherals.dart';

final _dmaOpen = ForeignLibrary.main.lookup('dma_open');
final _dmaAcknowledgeInterrupt =
    ForeignLibrary.main.lookup('dma_acknowledge_interrupt');

class STM32DmaStream {
  final int _controller;
  final int _dmaBase;
  final int _streamBase;
  Channel _channel;
  Port _port;
  int _isReg;
  int _ifcReg;
  int _irShift;
  int _dmaHandle;

  static const int _transferCompleteFlag = 1 << 0;
  static const int _halfTransferCompleteFlag = 1 << 1;
  static const int _transferErrorFlag = 1 << 3;
  static const int _directModeErrorFlag = 1 << 4;
  static const int _fifoErrorFlag = 1 << 5;

  STM32DmaStream(this._controller, int controllerBase, int stream)
      : _dmaBase = controllerBase,
        _streamBase = controllerBase + DMA.STREAM_OFFSET * stream {
    if (stream > 3) {
      _isReg = DMA.HISR;
      _ifcReg = DMA.HIFCR;
    } else {
      _isReg = DMA.LISR;
      _ifcReg = DMA.LIFCR;
    }
    int irShift = 0;
    if (stream & 0x10 != 0) irShift += 16;
    if (stream & 0x01 != 0) irShift += 6;
    _irShift = irShift;

    _channel = new Channel();
    _port = new Port(_channel);
    _dmaHandle = _dmaOpen.icall$2(_controller, stream);
  }

  bool _areBitsSet(int base, int reg, int mask) =>
      peripherals.getUint32(base + reg) & mask == mask;

  void _setBits(int base, int reg, int mask) {
    int offset = base + reg;
    int temp = peripherals.getUint32(offset);
    peripherals.setUint32(offset, temp | mask);
  }

  void _resetMask(int base, int reg, int mask) {
    int offset = base + reg;
    int temp = peripherals.getUint32(offset);
    peripherals.setUint32(offset, temp & ~mask);
  }

  int _getMaskedValue(int base, int reg, int mask) {
    return peripherals.getUint32(base + reg) & mask;
  }

  void _setMaskedValue(int base, int reg, int mask, int value) {
    int offset = base + reg;
    int temp = peripherals.getUint32(offset);
    peripherals.setUint32(offset, (temp & ~mask) | (value & mask));
  }

  /// Enable transfers on this DMA stream.
  void enable() => _setBits(_streamBase, DMA.SxCR, DMA_SxCR_EN);

  /// Disable this DMA stream.
  ///
  /// The stream will flush its FIFO queue before it is actually disabled, so
  /// there is a short period after clearing the enable bit before isEnabled
  /// returns false.
  void disable() => _resetMask(_streamBase, DMA.SxCR, DMA_SxCR_EN);

  /// Returns `true` if this stream is enabled, and `false` if it is disabled.
  bool get isEnabled => _areBitsSet(_streamBase, DMA.SxCR, DMA_SxCR_EN);

  /// Disable this stream, and wait for active transfers to stop (FIFO flush).
  /// This is a blocking call.
  void disableAndWait() {
    disable();
    while (isEnabled);
  }

  /// Return the currently configured channel for this DMA stream.
  int get channel {
    int temp = _getMaskedValue(_streamBase, DMA.SxCR, DMA_SxCR_CHSEL_MASK);
    return temp >> DMA_SxCR_CHSEL_SHIFT;
  }

  /// Set the [channel] for this DMA stream.
  void set channel(int channel) {
    _setMaskedValue(_streamBase, DMA.SxCR, DMA_SxCR_CHSEL_MASK,
        channel << DMA_SxCR_CHSEL_SHIFT);
  }

  /// The priority of this DMA stream.
  ///
  /// Possible priority values are:
  ///
  /// * [DMA_SxCR_PL_LOW]
  /// * [DMA_SxCR_PL_MEDIUM]
  /// * [DMA_SxCR_PL_HIGH]
  /// * [DMA_SxCR_PL_VERY_HIGH]
  int get priority => _getMaskedValue(_streamBase, DMA.SxCR, DMA_SxCR_PL_MASK);

  /// Set the [priority] of this DMA stream. Possible priority values are:
  ///
  /// * [DMA_SxCR_PL_LOW]
  /// * [DMA_SxCR_PL_MEDIUM]
  /// * [DMA_SxCR_PL_HIGH]
  /// * [DMA_SxCR_PL_VERY_HIGH]
  void set priority(int priority) {
    _setMaskedValue(_streamBase, DMA.SxCR, DMA_SxCR_PL_MASK, priority);
  }

  int get memoryDataSize =>
      _getMaskedValue(_streamBase, DMA.SxCR, DMA_SxCR_MSIZE_MASK);

  void set memoryDataSize(int dataSize) {
    _setMaskedValue(_streamBase, DMA.SxCR, DMA_SxCR_MSIZE_MASK, dataSize);
  }

  int get peripheralDataSize =>
      _getMaskedValue(_streamBase, DMA.SxCR, DMA_SxCR_PSIZE_MASK);

  void set peripheralDataSize(int dataSize) {
    _setMaskedValue(_streamBase, DMA.SxCR, DMA_SxCR_PSIZE_MASK, dataSize);
  }

  int get count => _getMaskedValue(_streamBase, DMA.SxNDTR, DMA_SxNDTR_MASK);

  void set count(int count) {
    peripherals.setUint32(_streamBase + DMA.SxNDTR, count & DMA_SxNDTR_MASK);
  }

  /// Start a DMA read from a peripheral to memory.
  ///
  /// Configures a DMA read of [count] words from [sourceRegister] into
  /// [destinationMemory]. By default, the destination pointer is incremented
  /// after each transfer, but the peripheral source register pointer is not.
  ///
  /// See the board reference manual for the DMA stream and [channel] mapping
  /// for the peripheral.
  void startReadFromPeripheral(int channel, int sourceRegister,
      ForeignMemory destinationMemory, int count,
      {bool incrementPeripheral: false,
      bool incrementMemory: true,
      int priority: DMA_SxCR_PL_HIGH,
      bool useFifo: true,
      int fifoThreshold: DMA_SxFCR_FTH_FULL}) {
    if (isEnabled) {
      disableAndWait();
    }
    // Clear any flags set by previous transfer.
    clearInterruptFlag(DMA_IFCR_MASK);

    int sxcr = (channel << DMA_SxCR_CHSEL_SHIFT) | priority;
    sxcr |= DMA_SxCR_DIR_PERIPHERAL_TO_MEMORY;
    sxcr |= DMA_SxCR_MSIZE_WORD | DMA_SxCR_PSIZE_WORD;
    if (incrementMemory) {
      sxcr |= DMA_SxCR_MINC;
    }
    if (incrementPeripheral) {
      sxcr |= DMA_SxCR_PINC;
    }
    sxcr |= DMA_SxCR_EN;

    int fcr = useFifo ? DMA_SxFCR_DMDIS | fifoThreshold : 0;

    peripherals.setUint32(_streamBase + DMA.SxPAR, sourceRegister);
    peripherals.setUint32(_streamBase + DMA.SxM0AR, destinationMemory.address);
    peripherals.setUint32(_streamBase + DMA.SxNDTR, count);
    peripherals.setUint32(_streamBase + DMA.SxFCR, fcr);
    peripherals.setUint32(_streamBase + DMA.SxCR, sxcr);
  }

  bool get halfTransferComplete => interruptStatus & DMA_ISR_HTIF != 0;
  bool get transferComplete => interruptStatus & DMA_ISR_TCIF != 0;

  int get interruptStatus =>
      (peripherals.getUint32(_dmaBase + _isReg) >> _irShift) & DMA_ISR_MASK;
  void clearInterruptFlag(int flag) {
    peripherals.setUint32(_dmaBase + _ifcReg, flag << _irShift);
  }
  void enableInterrupts(int interrupts) {
    _setBits(_streamBase, DMA.SxCR, interrupts);
  }

  void waitForTransferComplete() {
    eventHandler.registerPortForNextEvent(_dmaHandle, _port,
        _transferCompleteFlag);
    // Enable Transfer Complete interrupt
    enableInterrupts(DMA_SxCR_TCIE);
    int event = _channel.receive();
    _dmaAcknowledgeInterrupt.vcall$2(_dmaHandle, event);
  }
}

class STM32Dma {
  final String name;
  final int _controller;
  final int _base;
  final int _ahb1enr;

  STM32DmaStream _stream0;
  STM32DmaStream _stream1;
  STM32DmaStream _stream2;
  STM32DmaStream _stream3;
  STM32DmaStream _stream4;
  STM32DmaStream _stream5;
  STM32DmaStream _stream6;
  STM32DmaStream _stream7;

  STM32Dma(this.name, this._controller, int base, this._ahb1enr)
      : this._base = base - PERIPH_BASE;

  STM32DmaStream get stream0 =>
      _stream0 ??= new STM32DmaStream(_controller, _base, 0);

  STM32DmaStream get stream1 =>
      _stream1 ??= new STM32DmaStream(_controller, _base, 1);

  STM32DmaStream get stream2 =>
      _stream2 ??= new STM32DmaStream(_controller, _base, 2);

  STM32DmaStream get stream3 =>
      _stream3 ??= new STM32DmaStream(_controller, _base, 3);

  STM32DmaStream get stream4 =>
      _stream4 ??= new STM32DmaStream(_controller, _base, 4);

  STM32DmaStream get stream5 =>
      _stream5 ??= new STM32DmaStream(_controller, _base, 5);

  STM32DmaStream get stream6 =>
      _stream6 ??= new STM32DmaStream(_controller, _base, 6);

  STM32DmaStream get stream7 =>
      _stream7 ??= new STM32DmaStream(_controller, _base, 7);

  String toString() => name;

  /// Enable DMA clock in RCC.
  void enableClock() {
    int offset = RCC_BASE - PERIPH_BASE + RCC.AHB1ENR;
    int temp = peripherals.getUint32(offset);
    peripherals.setUint32(offset, temp | _ahb1enr);
  }

  /// Disable DMA clock in RCC.
  void disableClock() {
    int offset = RCC_BASE - PERIPH_BASE + RCC.AHB1ENR;
    int temp = peripherals.getUint32(offset);
    peripherals.setUint32(offset, temp & ~_ahb1enr);
  }
}
