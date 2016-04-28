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
  return event_listener_ != NULL && (flags_ & wait_mask_) != 0;
}

void Device::SendIfReady() {
  if (IsReady()) {
    event_listener_->Send(flags_);
    delete event_listener_;
    event_listener_ = NULL;
  }
}

Mutex* Device::GetMutex() {
  return mutex_;
}

void Device::SetEventListener(
    EventListener* event_listener, uint32_t wait_mask) {
  wait_mask_ = wait_mask;
  event_listener_ = event_listener;
}

DeviceManager::DeviceManager() : mutex_(new Mutex()),
                                 next_free_slot_(kIllegalDeviceId) {
  osMessageQDef(device_event_queue, kMailQSize, int);
  mail_queue_ = osMessageCreate(osMessageQ(device_event_queue), NULL);
}

DeviceManager* DeviceManager::GetDeviceManager() {
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

// Return the index of the first free slot in the list of devices to be used for
// a new device.
//
// If there is no free slot in the exisiting list of devices, this function will
// add a new slot and return its index.
uintptr_t DeviceManager::FindFreeDeviceSlot() {
  if (next_free_slot_ != kIllegalDeviceId) {
    ASSERT(next_free_slot_ < devices_.size() &&
           devices_[next_free_slot_] == NULL);
    uintptr_t slot = next_free_slot_;
    // Update the invariant of next_free_slot_.
    next_free_slot_ = kIllegalDeviceId;
    for (uintptr_t i = slot + 1; i < devices_.size(); ++i) {
      if (devices_[i] == NULL) {
        next_free_slot_ = i;
        break;
      }
    }
    return slot;
  } else {
    // Invariant: there is no free slot in devices_.
    devices_.PushBack(NULL);
    return devices_.size() - 1;
  }
}

uintptr_t DeviceManager::RegisterDevice(Device* device) {
  ScopedLock locker(mutex_);
  uintptr_t device_id = FindFreeDeviceSlot();
  devices_[device_id] = device;
  device->set_device_id(device_id);
  return device_id;
}

void DeviceManager::RegisterUartDevice(const char* name, UartDriver* driver) {
  UartDevice* device = new UartDevice(name, driver);
  driver->device_id = RegisterDevice(device);
}

void DeviceManager::RegisterButtonDevice(const char* name,
                                         ButtonDriver* driver) {
  ButtonDevice* device = new ButtonDevice(name, driver);
  driver->device_id = RegisterDevice(device);
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

int DeviceManager::CreateSocket() {
  Device* device = new Device("socket", Device::SOCKET_DEVICE);
  return RegisterDevice(device);
}

void DeviceManager::RemoveSocket(int handle) {
  RemoveDevice(devices_[handle]);
}

void DeviceManager::RegisterFreeDeviceSlot(int handle) {
  if (next_free_slot_ == kIllegalDeviceId || handle < next_free_slot_) {
    next_free_slot_ = handle;
  }
}

void DeviceManager::RemoveDevice(Device *device) {
  ScopedLock locker(mutex_);
  int handle = device->device_id();
  device->set_device_id(kIllegalDeviceId);
  devices_[handle] = NULL;
  RegisterFreeDeviceSlot(handle);
}

Device* DeviceManager::GetDevice(int handle) {
  ScopedLock locker(mutex_);
  Device* device = devices_[handle];
  ASSERT(device != NULL);
  return device;
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
