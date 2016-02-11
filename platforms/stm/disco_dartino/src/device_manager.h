// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef PLATFORMS_STM_DISCO_DARTINO_SRC_DEVICE_MANAGER_H_
#define PLATFORMS_STM_DISCO_DARTINO_SRC_DEVICE_MANAGER_H_

#include "src/shared/platform.h"
#include "src/vm/port.h"

namespace dartino {

// An instance of a open device that can be listened to.
class Device {
 public:
  explicit Device(void* data)
    : data_(data),
      mutex_(Platform::CreateMutex()) {}

  // Sets the [flag] in [flags]. Returns true if anything changed.
  // Sends a message if there is a matching listener.
  bool SetFlag(uint32_t flag);

  // Clears the [flag] in [flags]. Returns true if anything changed.
  bool ClearFlag(uint32_t flag);

  uint32_t GetFlags();

  Mutex *GetMutex();

  // Returns true if there is a listener, and `(flags_ & wait_mask) != 0`.
  bool IsReady();

  void SetWaitMask(uint32_t wait_mask);

  Port *GetPort();

  void SetPort(Port *port);

  void SetHandle(int handle);

  void *GetData();

 private:
  // The device handle referring to this device.
  int handle_;

  // The port waiting for messages on this device.
  Port *port_ = NULL;

  // The current flags for this device.
  uint32_t flags_ = 0;

  // The mask for messages on this device.
  uint32_t wait_mask_;

  // Custom data associated with the device.
  void *data_;

  Mutex* mutex_;
};

class DeviceManager {
 public:
  static DeviceManager *GetDeviceManager();

  // Installs [device] so it can be listened to by the event handler.
  int InstallDevice(Device *device);

  Device *GetDevice(int handle);

  osMessageQId GetMailQueue() {
    return mail_queue_;
  }

  int SendMessage(int handle);

 private:
  DeviceManager();

  // All open devices are stored here.
  Vector<Device*> devices_ = Vector<Device*>();

  osMessageQId mail_queue_;

  static DeviceManager *instance_;

  Mutex* mutex_;
};


}  // namespace dartino

#endif  // PLATFORMS_STM_DISCO_DARTINO_SRC_DEVICE_MANAGER_H_
