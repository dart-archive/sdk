// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "platforms/stm/disco_dartino/src/device_manager.h"

namespace dartino {

// The size of the queue used by the event handler.
const uint32_t kMailQSize = 50;

bool Device::SetFlags(uint32_t flags) {
  ScopedLock locker(mutex_);
  if ((flags_ & flags) != 0) return false;
  int before = IsReady();
  flags_ |= flags;
  // Send a message if the status changed.
  if (!before && IsReady()) {
    if (DeviceManager::GetDeviceManager()->SendMessage(device_id_) != osOK) {
      FATAL("Could not send message");
    }
  }
  return true;
}

bool Device::ClearFlags(uint32_t flags) {
  ScopedLock locker(mutex_);
  if ((flags_ & flags) == 0) return false;
  flags_ = flags_ & ~flags;
  return true;
}

bool Device::ClearWaitFlags() {
  return ClearFlags(wait_mask_);
}

bool Device::IsReady() {
  return port_ != NULL && (flags_ & wait_mask_) != 0;
}

void Device::SetWaitMask(uint32_t wait_mask) {
  wait_mask_ = wait_mask;
}

Mutex *Device::GetMutex() {
  return mutex_;
}

Port *Device::GetPort() {
  return port_;
}

uint32_t Device::GetFlags() {
  return flags_;
}

void Device::SetPort(Port *port) {
  port_ = port;
}

DeviceManager::DeviceManager() : mutex_(new Mutex()) {
  osMessageQDef(device_event_queue, kMailQSize, int);
  mail_queue_ = osMessageCreate(osMessageQ(device_event_queue), NULL);
}

DeviceManager *DeviceManager::GetDeviceManager() {
  if (instance_ == NULL) {
    instance_ = new DeviceManager();
  }
  return instance_;
}

// Call from a device driver to indicate a flag change.
void DeviceManager::DeviceSetFlags(uintptr_t device_id, uint32_t flags) {
  ScopedLock locker(mutex_);
  Device* device = devices_[device_id];
  device->SetFlags(flags);
}

// Call from a device driver to indicate a flag change.
void DeviceManager::DeviceClearFlags(uintptr_t device_id, uint32_t flags) {
  ScopedLock locker(mutex_);
  Device* device = devices_[device_id];
  device->ClearFlags(flags);
}

void DeviceManager::RegisterUartDevice(const char* name, UartDriver* driver) {
  UartDevice* device = new UartDevice(name, driver);
  ScopedLock locker(mutex_);
  devices_.PushBack(device);
  uintptr_t device_id = devices_.size() - 1;
  driver->device_id = device_id;
  device->set_device_id(device_id);
}

void DeviceManager::RegisterButtonDevice(const char* name,
                                         ButtonDriver* driver) {
  ButtonDevice* device = new ButtonDevice(name, driver);
  ScopedLock locker(mutex_);
  devices_.PushBack(device);
  uintptr_t device_id = devices_.size() - 1;
  driver->device_id = device_id;
  device->set_device_id(device_id);
}

Device* DeviceManager::LookupDevice(const char* name, Device::Type type) {
  // Lookup the named device.
  // No locking - only called by methods which already lock.
  for (int i = 0; i < devices_.size(); i++) {
    Device* device = devices_[i];
    if (device->type() == type && strcmp(name, devices_[i]->name()) == 0) {
      return device;
    }
  }
  return NULL;
}

int DeviceManager::OpenUart(const char* name) {
  ScopedLock locker(mutex_);
  Device* device = LookupDevice(name, Device::UART_DEVICE);
  if (device == NULL) return -1;
  if (device->initialized_) return -1;

  UartDevice* uart_device = UartDevice::cast(device);
  uart_device->Initialize();
  device->initialized_ = true;

  return device->device_id();
}

int DeviceManager::OpenButton(const char* name) {
  ScopedLock locker(mutex_);
  Device* device = LookupDevice(name, Device::BUTTON_DEVICE);
  if (device == NULL) return -1;
  if (device->initialized_) return -1;

  ButtonDevice* button_device = ButtonDevice::cast(device);
  button_device->Initialize();
  device->initialized_ = true;

  return device->device_id();
}

Device* DeviceManager::GetDevice(int handle) {
  ScopedLock locker(mutex_);
  return devices_[handle];
}

UartDevice* DeviceManager::GetUart(int handle) {
  ScopedLock locker(mutex_);
  return UartDevice::cast(devices_[handle]);
}

ButtonDevice* DeviceManager::GetButton(int handle) {
  ScopedLock locker(mutex_);
  return ButtonDevice::cast(devices_[handle]);
}

int DeviceManager::SendMessage(int handle) {
  return osMessagePut(mail_queue_, static_cast<uint32_t>(handle), 0);
}

}  // namespace dartino
