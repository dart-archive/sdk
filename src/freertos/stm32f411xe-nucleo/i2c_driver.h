// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_FREERTOS_STM32F411XE_NUCLEO_I2C_DRIVER_H_
#define SRC_FREERTOS_STM32F411XE_NUCLEO_I2C_DRIVER_H_

#include <cmsis_os.h>
#include <stm32f4xx_hal.h>
#include <stm32f4xx_hal_i2c.h>

#include <cinttypes>

#include "src/freertos/device_manager.h"
#include "src/shared/platform.h"

extern "C" void HAL_I2C_ErrorCallback(I2C_HandleTypeDef *i2cHandle);
extern "C" void I2C1_EV_IRQHandler();
extern "C" void I2C1_ER_IRQHandler();
extern "C" void I2C2_EV_IRQHandler();
extern "C" void I2C2_ER_IRQHandler();
extern "C" void I2C3_EV_IRQHandler();
extern "C" void I2C3_ER_IRQHandler();

// Interface to the I2C bus.
class I2CDriverImpl {
 public:
  I2CDriverImpl();

  void Initialize(uintptr_t device_id, int i2c_no);
  void DeInitialize();

  int IsDeviceReady(uint16_t address);
  int RequestRead(uint16_t address, uint8_t* buffer, size_t count);
  int RequestWrite(uint16_t address, uint8_t* buffer, size_t count);
  int RequestReadRegisters(
      uint16_t address, uint16_t reg, uint8_t* buffer, size_t count);
  int RequestWriteRegisters(
      uint16_t address, uint16_t reg, uint8_t* buffer, size_t count);
  int AcknowledgeResult();

 private:
  friend void __I2CTask(const void *arg);
  friend void I2C1_EV_IRQHandler();
  friend void I2C1_ER_IRQHandler();
  friend void I2C2_EV_IRQHandler();
  friend void I2C2_ER_IRQHandler();
  friend void I2C3_EV_IRQHandler();
  friend void I2C3_ER_IRQHandler();
  friend void SignalSuccess(I2C_HandleTypeDef *i2cHandle);
  friend void HAL_I2C_ErrorCallback(I2C_HandleTypeDef *i2cHandle);

  enum State {
    IDLE = 0,
    ACTIVE = 1,
    DONE = 2,
  };

  // TODO(jakobr): Share with stm32f746g-discovery implementation, since there's
  // only one version of the Dart code.
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
    DMA_ERROR = -9,
    TIMEOUT = -10,
    INTERNAL_ERROR = -99,
  };

  void InitializeI2C1();
  void InitializeI2C2();
  void InitializeI2C3();
  void InitHandle(I2C_TypeDef *instance);

  void Task();
  void SignalSuccess();
  void SignalError();

  dartino::Mutex* mutex_;
  I2C_HandleTypeDef i2c_;
  State state_;
  int error_code_;

  // Thread id of the thread that signals the event-handler.
  osThreadId signalThread_;

  // Device ID returned from device driver registration.
  uintptr_t device_id_;
};

extern "C" void FillI2CDriver(I2CDriver* driver, int i2c_no);

#endif  // SRC_FREERTOS_STM32F411XE_NUCLEO_I2C_DRIVER_H_
