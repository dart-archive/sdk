// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "platforms/stm/disco_dartino/src/device_manager.h"

namespace dartino {

// The size of the queue used by the event handler.
const uint32_t kMailQSize = 50;

DeviceManager::DeviceManager() : mutex_(new Mutex()) {
  osMessageQDef(device_event_queue, kMailQSize, int);
  mail_queue_ = osMessageCreate(osMessageQ(device_event_queue), NULL);
}

bool Device::SetFlag(uint32_t flag) {
  ScopedLock locker(mutex_);
  if ((flags_ & flag) != 0) return false;
  int before = IsReady();
  flags_ |= flag;
  // Send a message if the status changed.
  if (!before && IsReady()) {
    if (DeviceManager::GetDeviceManager()->SendMessage(handle_) != osOK) {
      FATAL("Could not send message");
    }
  }
  return true;
}

bool Device::ClearFlag(uint32_t flag) {
  ScopedLock locker(mutex_);
  if ((flags_ & flag) == 0) return false;
  flags_ = flags_ & ~flag;
  return true;
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

void Device::SetHandle(int handle) {
  handle_ = handle;
}

void *Device::GetData() {
  return data_;
}

DeviceManager *DeviceManager::GetDeviceManager() {
  if (instance_ == NULL) {
    instance_ = new DeviceManager();
  }
  return instance_;
}

int DeviceManager::InstallDevice(Device *device) {
  ScopedLock locker(mutex_);
  devices_.PushBack(device);
  int handle = devices_.size() - 1;
  device->SetHandle(handle);
  return handle;
}

Device *DeviceManager::GetDevice(int handle) {
  ScopedLock locker(mutex_);
  return devices_[handle];
}

int DeviceManager::SendMessage(int handle) {
  return osMessagePut(mail_queue_, static_cast<uint32_t>(handle), 0);
}

}  // namespace dartino
