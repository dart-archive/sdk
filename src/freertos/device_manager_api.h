// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_FREERTOS_DEVICE_MANAGER_API_H_
#define SRC_FREERTOS_DEVICE_MANAGER_API_H_

#include <inttypes.h>
#include <stdlib.h>

// This file defines the API for device with drivers drivers for the
// FreeRTOS Dartino embedding.
//
// A device driver is defined though a C struct with two fields and a
// number of function pointers.
//
// For each device driver the fields "context" and "device_id" are the
// first members in the struct. The "context" field can be used by the
// device driver implementer to store information. The "device_id" is
// filled by the device manager and must be used when calling back
// into the device manager.

#ifdef __cplusplus
extern "C" {
#endif

// Value that can be used to initialize a device_id field.
const uintptr_t kIllegalDeviceId = UINTPTR_MAX;

// Definition of a UART driver.
struct UartDriver {
  uintptr_t context;
  uintptr_t device_id;
  void (*Initialize)(struct UartDriver* driver);
  void (*DeInitialize)(struct UartDriver* driver);
  size_t (*Read)(struct UartDriver* driver, uint8_t* buffer, size_t count);
  size_t (*Write)(struct UartDriver* driver,
                  const uint8_t* buffer, size_t offset, size_t count);
  uint32_t (*GetError)(struct UartDriver* driver);
};

typedef struct UartDriver UartDriver;

// Definition of a button driver.
struct ButtonDriver {
  uintptr_t context;
  uintptr_t device_id;
  void (*Initialize)(struct ButtonDriver* driver);
  void (*DeInitialize)(struct ButtonDriver* driver);
  void (*NotifyRead)(struct ButtonDriver* driver);
};

typedef struct ButtonDriver ButtonDriver;

// Definition of an I2C driver.
struct I2CDriver {
  uintptr_t context;
  uintptr_t device_id;
  int i2c_no;
  void (*Initialize)(struct I2CDriver* driver);
  void (*DeInitialize)(struct I2CDriver* driver);
  int (*IsDeviceReady)(struct I2CDriver* driver, uint16_t address);
  int (*RequestRead)(struct I2CDriver* driver, uint16_t address,
                              uint8_t* buffer, size_t count);
  int (*RequestWrite)(struct I2CDriver* driver, uint16_t address,
                               uint8_t* buffer, size_t count);
  int (*RequestReadRegisters)(struct I2CDriver* driver,
                              uint16_t address, uint16_t reg,
                              uint8_t* buffer, size_t count);
  int (*RequestWriteRegisters)(struct I2CDriver* driver,
                               uint16_t address, uint16_t reg,
                               uint8_t* buffer, size_t count);
  int (*AcknowledgeResult)(struct I2CDriver* driver);
};

typedef struct I2CDriver I2CDriver;

// Register a UART driver with the device manager.
void DeviceManagerRegisterUartDevice(char* name, UartDriver* driver);

// Register a button driver with the device manager.
void DeviceManagerRegisterButtonDevice(char* name, ButtonDriver* driver);

// Register a I2C driver with the device manager.
void DeviceManagerRegisterI2CDevice(char* name, I2CDriver* driver);

// Set state flags for a given driver.
void DeviceManagerSetFlags(uintptr_t device_id, uint32_t flags);

// Clear state flags for a given driver.
void DeviceManagerClearFlags(uintptr_t device_id, uint32_t flags);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // SRC_FREERTOS_DEVICE_MANAGER_API_H_
