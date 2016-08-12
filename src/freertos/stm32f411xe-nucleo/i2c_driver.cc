// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/freertos/stm32f411xe-nucleo/i2c_driver.h"

#include <stdlib.h>

#include "src/freertos/device_manager_api.h"

// Bits set from the interrupt handler.
const int kResultReadyBit = 1 << 0;
const int kErrorBit = 1 << 1;

static I2CDriverImpl *i2c1;
static I2CDriverImpl *i2c2;
static I2CDriverImpl *i2c3;

I2CDriverImpl::I2CDriverImpl()
  : mutex_(dartino::Platform::CreateMutex()),
    state_(IDLE),
    signalThread_(NULL),
    device_id_(kIllegalDeviceId) { }

// This is declared as friend, so it cannot be static here.
void __I2CTask(const void *arg) {
  const_cast<I2CDriverImpl*>(
      reinterpret_cast<const I2CDriverImpl*>(arg))->Task();
}

void I2CDriverImpl::Initialize(uintptr_t device_id, int i2c_no) {
  ASSERT(device_id_ == kIllegalDeviceId);
  ASSERT(device_id != kIllegalDeviceId);
  device_id_ = device_id;
  osThreadDef(I2C_TASK, __I2CTask, osPriorityHigh, 0, 1280);
  signalThread_ =
      osThreadCreate(osThread(I2C_TASK), reinterpret_cast<void*>(this));

  switch (i2c_no) {
  case 1:
    i2c1 = this;
    InitializeI2C1();
    break;
  case 2:
    i2c2 = this;
    InitializeI2C3();
    break;
  case 3:
    i2c3 = this;
    InitializeI2C3();
    break;
  default:
    UNREACHABLE();
  }
}

void I2CDriverImpl::InitializeI2C1() {
  // TODO(jakobr): Generalize function, take i2c handle and IRQn as parameters.
  // TODO(jakobr): Dart code for GPIO init?

  __HAL_RCC_GPIOB_CLK_ENABLE();

  // I2C1 GPIO Configuration
  // PB8 --> I2C1_SCL
  // PB9 --> I2C1_SDA
  GPIO_InitTypeDef gpio_init;
  gpio_init.Pin = GPIO_PIN_8|GPIO_PIN_9;
  gpio_init.Mode = GPIO_MODE_AF_OD;
  gpio_init.Pull = GPIO_PULLUP;
  gpio_init.Speed = GPIO_SPEED_FAST;
  gpio_init.Alternate = GPIO_AF4_I2C1;
  HAL_GPIO_Init(GPIOB, &gpio_init);

  // Peripheral clock enable
  __HAL_RCC_I2C1_CLK_ENABLE();

  InitHandle(I2C1);
  HAL_NVIC_SetPriority(I2C1_EV_IRQn, 5, 0);
  HAL_NVIC_EnableIRQ(I2C1_EV_IRQn);
  HAL_NVIC_SetPriority(I2C1_ER_IRQn, 5, 0);
  HAL_NVIC_EnableIRQ(I2C1_ER_IRQn);
}

void I2CDriverImpl::InitializeI2C2() {
  FATAL("NOT IMPLEMENTED");
}

void I2CDriverImpl::InitializeI2C3() {
  FATAL("NOT IMPLEMENTED");
}

void I2CDriverImpl::InitHandle(I2C_TypeDef *instance) {
  // TODO(jakobr): I2C address.
  i2c_.Instance = instance;
  i2c_.Init.AddressingMode = I2C_ADDRESSINGMODE_7BIT;
  i2c_.Init.ClockSpeed = 400000;
  i2c_.Init.DualAddressMode = I2C_DUALADDRESS_DISABLE;
  i2c_.Init.DutyCycle = I2C_DUTYCYCLE_16_9;
  i2c_.Init.GeneralCallMode = I2C_GENERALCALL_DISABLE;
  i2c_.Init.NoStretchMode = I2C_NOSTRETCH_DISABLE;
  i2c_.Init.OwnAddress1 = 0;
  i2c_.Init.OwnAddress2 = 0;

  HAL_I2C_Init(&i2c_);

  // Configure Analog filter.
  HAL_I2CEx_AnalogFilter_Config(&i2c_, I2C_ANALOGFILTER_ENABLE);
}

void I2CDriverImpl::DeInitialize() {
  FATAL("NOT IMPLEMENTED");
}

int I2CDriverImpl::IsDeviceReady(uint16_t address) {
  dartino::ScopedLock lock(mutex_);
  if (state_ != IDLE) return INVALID_ARGUMENTS;
  if (address > 0x7f) return INVALID_ARGUMENTS;

  HAL_StatusTypeDef result = HAL_I2C_IsDeviceReady(&i2c_, address << 1, 1, 1);
  return result == HAL_OK ? NO_ERROR : TIMEOUT;
}

int I2CDriverImpl::RequestRead(
    uint16_t address, uint8_t* buffer, size_t count) {
  dartino::ScopedLock lock(mutex_);
  if (state_ != IDLE) return INVALID_ARGUMENTS;
  if (address > 0x7f) return INVALID_ARGUMENTS;

  error_code_ = NO_ERROR;
  state_ = ACTIVE;

  HAL_StatusTypeDef result =
      HAL_I2C_Master_Receive_IT(&i2c_, address << 1, buffer, count);

  if (result != HAL_OK) {
    state_ = DONE;
    return TIMEOUT;
  }

  return NO_ERROR;
}

int I2CDriverImpl::RequestWrite(
    uint16_t address, uint8_t* buffer, size_t count) {
  dartino::ScopedLock lock(mutex_);
  if (state_ != IDLE) return INVALID_ARGUMENTS;
  if (address > 0x7f) return INVALID_ARGUMENTS;

  error_code_ = NO_ERROR;
  state_ = ACTIVE;

  HAL_StatusTypeDef result =
      HAL_I2C_Master_Transmit_IT(&i2c_, address << 1, buffer, count);

  if (result != HAL_OK) {
    state_ = DONE;
    return TIMEOUT;
  }

  return NO_ERROR;
}

int I2CDriverImpl::RequestReadRegisters(
    uint16_t address, uint16_t reg, uint8_t* buffer, size_t count) {
  dartino::ScopedLock lock(mutex_);
  if (state_ != IDLE) return INVALID_ARGUMENTS;
  if (address > 0x7f) return INVALID_ARGUMENTS;

  error_code_ = NO_ERROR;
  state_ = ACTIVE;

  uint16_t reg_size = reg > 0xff ? I2C_MEMADD_SIZE_16BIT : I2C_MEMADD_SIZE_8BIT;
  HAL_StatusTypeDef result =
      HAL_I2C_Mem_Read_IT(&i2c_, address << 1, reg, reg_size, buffer, count);

  if (result != HAL_OK) {
    state_ = DONE;
    return TIMEOUT;
  }

  return NO_ERROR;
}

int I2CDriverImpl::RequestWriteRegisters(
    uint16_t address, uint16_t reg, uint8_t* buffer, size_t count) {
  dartino::ScopedLock lock(mutex_);
  if (state_ != IDLE) return INVALID_ARGUMENTS;
  if (address > 0x7f) return INVALID_ARGUMENTS;

  error_code_ = NO_ERROR;
  state_ = ACTIVE;

  uint16_t reg_size = reg > 0xff ? I2C_MEMADD_SIZE_16BIT : I2C_MEMADD_SIZE_8BIT;
  HAL_StatusTypeDef result =
      HAL_I2C_Mem_Write_IT(&i2c_, address << 1, reg, reg_size, buffer, count);

  if (result != HAL_OK) {
    state_ = DONE;
    return TIMEOUT;
  }

  return NO_ERROR;
}

int I2CDriverImpl::AcknowledgeResult() {
  dartino::ScopedLock lock(mutex_);
  if (state_ == IDLE) return NO_PENDING_REQUEST;
  if (state_ != DONE) return RESULT_NOT_READY;
  state_ = IDLE;
  DeviceManagerClearFlags(device_id_, kResultReadyBit | kErrorBit);
  return error_code_;
}

void I2CDriverImpl::Task() {
  // Process notifications from the interrupt handlers.
  for (;;) {
    // Wait for a signal.
    osEvent event = osSignalWait(0x0000FFFF, osWaitForever);
    if (event.status == osEventSignal) {
      dartino::ScopedLock lock(mutex_);
      state_ = DONE;
      uint32_t flags = event.value.signals;
      // This will send a message on the event handler,
      // if there currently is an eligible listener.
      DeviceManagerSetFlags(device_id_, flags);
    }
  }
}

void I2CDriverImpl::SignalSuccess() {
  osSignalSet(signalThread_, kResultReadyBit);
}

void I2CDriverImpl::SignalError() {
  uint32_t error = i2c_.ErrorCode;
  if ((error | HAL_I2C_ERROR_TIMEOUT) != RESET) {
    error_code_ = TIMEOUT;
  } else if ((error | HAL_I2C_ERROR_DMA) != RESET) {
    error_code_ = DMA_ERROR;
  } else if ((error | HAL_I2C_ERROR_OVR) != RESET) {
    error_code_ = OVERRUN_ERROR;
  } else if ((error | HAL_I2C_ERROR_AF) != RESET) {
    error_code_ = TIMEOUT;
  } else if ((error | HAL_I2C_ERROR_ARLO) != RESET) {
    error_code_ = ARBITRATION_LOSS;
  } else if ((error | HAL_I2C_ERROR_BERR) != RESET) {
    error_code_ = BUS_ERROR;
  } else {
    error_code_ = INTERNAL_ERROR;
  }
  uint32_t result = osSignalSet(signalThread_, kErrorBit);
  ASSERT(result == osOK);
}

extern "C" void HAL_I2C_ErrorCallback(I2C_HandleTypeDef *i2cHandle) {
  if (i2cHandle->Instance == I2C1) {
    i2c1->SignalError();
  } else if (i2cHandle->Instance == I2C2) {
    i2c2->SignalError();
  } else if (i2cHandle->Instance == I2C3) {
    i2c3->SignalError();
  } else {
    UNREACHABLE();
  }
}

void SignalSuccess(I2C_HandleTypeDef *i2cHandle) {
  if (i2cHandle->Instance == I2C1) {
    i2c1->SignalSuccess();
  } else if (i2cHandle->Instance == I2C2) {
    i2c2->SignalSuccess();
  } else if (i2cHandle->Instance == I2C3) {
    i2c3->SignalSuccess();
  } else {
    UNREACHABLE();
  }
}

extern "C" void HAL_I2C_MasterTxCpltCallback(I2C_HandleTypeDef *i2cHandle) {
  SignalSuccess(i2cHandle);
}

extern "C" void HAL_I2C_MasterRxCpltCallback(I2C_HandleTypeDef *i2cHandle) {
  SignalSuccess(i2cHandle);
}

extern "C" void HAL_I2C_MemTxCpltCallback(I2C_HandleTypeDef *i2cHandle) {
  SignalSuccess(i2cHandle);
}

extern "C" void HAL_I2C_MemRxCpltCallback(I2C_HandleTypeDef *i2cHandle) {
  SignalSuccess(i2cHandle);
}

extern "C" void I2C1_EV_IRQHandler(void) {
  HAL_I2C_EV_IRQHandler(&i2c1->i2c_);
}

extern "C" void I2C1_ER_IRQHandler(void) {
  HAL_I2C_ER_IRQHandler(&i2c1->i2c_);
}

extern "C" void I2C2_EV_IRQHandler(void) {
  HAL_I2C_EV_IRQHandler(&i2c2->i2c_);
}

extern "C" void I2C2_ER_IRQHandler(void) {
  HAL_I2C_ER_IRQHandler(&i2c2->i2c_);
}

extern "C" void I2C3_EV_IRQHandler(void) {
  HAL_I2C_EV_IRQHandler(&i2c3->i2c_);
}

extern "C" void I2C3_ER_IRQHandler(void) {
  HAL_I2C_ER_IRQHandler(&i2c3->i2c_);
}

static void Initialize(I2CDriver* driver) {
  I2CDriverImpl* i2c = new I2CDriverImpl();
  driver->context = reinterpret_cast<uintptr_t>(i2c);
  i2c->Initialize(driver->device_id, driver->i2c_no);
}

static void DeInitialize(I2CDriver* driver) {
  I2CDriverImpl* i2c = reinterpret_cast<I2CDriverImpl*>(driver->context);
  i2c->DeInitialize();
  delete i2c;
  driver->context = 0;
}

static int IsDeviceReady(I2CDriver* driver, uint16_t address) {
  I2CDriverImpl* i2c = reinterpret_cast<I2CDriverImpl*>(driver->context);
  return i2c->IsDeviceReady(address);
}

static int RequestRead(I2CDriver* driver, uint16_t address,
                       uint8_t* buffer, size_t count) {
  I2CDriverImpl* i2c = reinterpret_cast<I2CDriverImpl*>(driver->context);
  return i2c->RequestRead(address, buffer, count);
}

static int RequestWrite(I2CDriver* driver, uint16_t address,
                        uint8_t* buffer, size_t count) {
  I2CDriverImpl* i2c = reinterpret_cast<I2CDriverImpl*>(driver->context);
  return i2c->RequestWrite(address, buffer, count);
}

static int RequestReadRegisters(I2CDriver* driver,
                                uint16_t address, uint16_t reg,
                                uint8_t* buffer, size_t count) {
  I2CDriverImpl* i2c = reinterpret_cast<I2CDriverImpl*>(driver->context);
  return i2c->RequestReadRegisters(address, reg, buffer, count);
}

static int RequestWriteRegisters(I2CDriver* driver,
                                 uint16_t address, uint16_t reg,
                                 uint8_t* buffer, size_t count) {
  I2CDriverImpl* i2c = reinterpret_cast<I2CDriverImpl*>(driver->context);
  return i2c->RequestWriteRegisters(address, reg, buffer, count);
}

static int AcknowledgeResult(I2CDriver* driver) {
  I2CDriverImpl* i2c = reinterpret_cast<I2CDriverImpl*>(driver->context);
  return i2c->AcknowledgeResult();
}

extern "C" void FillI2CDriver(I2CDriver* driver, int i2c_no) {
  driver->i2c_no = i2c_no;
  driver->context = 0;
  driver->device_id = kIllegalDeviceId;
  driver->Initialize = Initialize;
  driver->DeInitialize = DeInitialize;
  driver->IsDeviceReady = IsDeviceReady;
  driver->RequestRead = RequestRead;
  driver->RequestWrite = RequestWrite;
  driver->RequestReadRegisters = RequestReadRegisters;
  driver->RequestWriteRegisters = RequestWriteRegisters;
  driver->AcknowledgeResult = AcknowledgeResult;
}
