// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_FREERTOS_STM32F746G_DISCOVERY_I2C_DRIVER_H_
#define SRC_FREERTOS_STM32F746G_DISCOVERY_I2C_DRIVER_H_

#include <cmsis_os.h>
#include <stm32f7xx_hal.h>

#include <cinttypes>

#include "src/freertos/device_manager.h"
#include "src/shared/platform.h"

extern "C" void I2C1_EV_IRQHandler();
extern "C" void I2C1_ER_IRQHandler();

// Interface to the universal asynchronous receiver/transmitter (UART).
class I2CDriverImpl {
 public:
  I2CDriverImpl();

  void Initialize(uintptr_t device_id);
  void DeInitialize();

  // TODO(sgjesse): Add register size (8/16 bits).
  int RequestReadRegisters(
      uint16_t address, uint16_t reg, uint8_t* buffer, size_t count);
  int RequestWriteRegisters(
      uint16_t address, uint16_t reg, uint8_t* buffer, size_t count);
  int AcknowledgeResult();

  // Read the result of a finished request.
  int ReadResult();

 private:
  friend void __I2CTask(const void *arg);
  friend void I2C1_EV_IRQHandler();
  friend void I2C1_ER_IRQHandler();

  // States of the register read/write state machine.
  enum State {
    IDLE = 0,
    SEND_REGISTER_READ = 1,
    PREPARE_READ_REGISTER = 2,
    SEND_REGISTER_WRITE = 3,
    PREPARE_WRITE_REGISTER = 4,
    READ_DATA = 5,
    WRITE_DATA = 6,
    DONE = 7,
  };

  enum Direction {
    DIRECTION_WRITE = 0,
    DIRECTION_READ = 1,
  };

  enum ErrorCode {
    NO_ERROR = 0,
    INVALID_ARGUMENTS = -1,
    SHORT_READ_WRITE = -2,
    RECEIVED_NACK = -3,
    BUS_ERROR = -4,
    OVERRUN_ERROR = -5,
    ARBITRATION_LOSS = -6,
    NO_PENDING_REQUEST = -7,
    RESULT_NOT_READY = -8,
    INTERNAL_ERROR = -99,
  };

  void Task();
  void SetupTransfer(Direction direction, uint8_t size, uint32_t flags);
  void ResetCR2Value(uint32_t* cr2);
  void ResetCR2();
  void FlushTXDR();
  void SignalSuccess();
  void SignalError(int error_code);
  void InternalStateError();

  void InterruptHandler();
  void ErrorInterruptHandler();

  inline bool IsTXIS(uint32_t it_flags, uint32_t it_sources) {
    return ((it_flags & I2C_FLAG_TXIS) != RESET) &&
        ((it_sources & I2C_IT_TXI) != RESET);
  }
  inline bool IsRXNE(uint32_t it_flags, uint32_t it_sources) {
    return ((it_flags & I2C_FLAG_RXNE) != RESET) &&
        ((it_sources & I2C_IT_RXI) != RESET);
  }
  inline bool IsTCR(uint32_t it_flags, uint32_t it_sources) {
    return ((it_flags & I2C_FLAG_TCR) != RESET) &&
        ((it_sources & I2C_IT_TXI) != RESET);
  }
  inline bool IsTC(uint32_t it_flags, uint32_t it_sources) {
    return ((it_flags & I2C_FLAG_TC) != RESET) &&
        ((it_sources & I2C_IT_TXI) != RESET);
  }
  inline bool IsSTOPF(uint32_t it_flags, uint32_t it_sources) {
    return ((it_flags & I2C_FLAG_STOPF) != RESET) &&
        ((it_sources & I2C_IT_STOPI) != RESET);
  }
  inline bool IsNACKF(uint32_t it_flags, uint32_t it_sources) {
    return ((it_flags & I2C_FLAG_AF) != RESET) &&
        ((it_sources & I2C_IT_NACKI) != RESET);
  }
  inline bool IsBERR(uint32_t it_flags, uint32_t it_sources) {
    return ((it_flags & I2C_FLAG_BERR) != RESET) &&
        ((it_sources & I2C_IT_ERRI) != RESET);
  }
  inline bool IsOVR(uint32_t it_flags, uint32_t it_sources) {
    return ((it_flags & I2C_FLAG_OVR) != RESET) &&
        ((it_sources & I2C_IT_ERRI) != RESET);
  }
  inline bool IsARLO(uint32_t it_flags, uint32_t it_sources) {
    return ((it_flags & I2C_FLAG_ARLO) != RESET) &&
        ((it_sources & I2C_IT_ERRI) != RESET);
  }

  const uint32_t kStatusInterrupts =
      I2C_IT_ERRI | I2C_IT_TCI | I2C_IT_STOPI | I2C_IT_NACKI;
  inline void EnableRXInterrupts() {
    __HAL_I2C_ENABLE_IT(i2c_, kStatusInterrupts | I2C_IT_RXI);
  }

  inline void EnableTXInterrupts() {
    __HAL_I2C_ENABLE_IT(i2c_, kStatusInterrupts | I2C_IT_TXI);
  }

  inline void DisableInterrupts() {
    __HAL_I2C_DISABLE_IT(i2c_, kStatusInterrupts | I2C_IT_RXI | I2C_IT_TXI);
  }

  dartino::Mutex* mutex_;

  I2C_HandleTypeDef* i2c_;

  // Thread id of the thread that signals the event-handler.
  osThreadId signalThread_;

  // Device ID returned from device driver registration.
  uintptr_t device_id_;

  // Information on the current request.
  State state_;
  uint16_t address_;
  uint16_t reg_;
  uint8_t* buffer_;
  size_t count_;
  int error_code_;
};

extern "C" void FillI2CDriver(I2CDriver* driver);

#endif  // SRC_FREERTOS_STM32F746G_DISCOVERY_I2C_DRIVER_H_
