// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/freertos/device_manager_api.h"

#include "src/freertos/device_manager.h"

namespace dartino {

}  // namespace dartino

void DeviceManagerRegisterUartDevice(char* name, UartDriver* driver) {
  dartino::DeviceManager* device_manager =
      dartino::DeviceManager::GetDeviceManager();
  device_manager->RegisterUartDevice(name, driver);
}

void DeviceManagerRegisterButtonDevice(char* name, ButtonDriver* driver) {
  dartino::DeviceManager* device_manager =
      dartino::DeviceManager::GetDeviceManager();
  device_manager->RegisterButtonDevice(name, driver);
}

void DeviceManagerRegisterI2CDevice(char* name, I2CDriver* driver) {
  dartino::DeviceManager* device_manager =
      dartino::DeviceManager::GetDeviceManager();
  device_manager->RegisterI2CDevice(name, driver);
}

void DeviceManagerSetFlags(uintptr_t device_id, uint32_t flags) {
  dartino::DeviceManager* device_manager =
      dartino::DeviceManager::GetDeviceManager();
  device_manager->DeviceSetFlags(device_id, flags);
}

void DeviceManagerClearFlags(uintptr_t device_id, uint32_t flags) {
  dartino::DeviceManager* device_manager =
      dartino::DeviceManager::GetDeviceManager();
  device_manager->DeviceClearFlags(device_id, flags);
}
