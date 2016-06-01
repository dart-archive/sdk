// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "platforms/stm/disco_dartino/src/stm32f746g-discovery/ethernet.h"

#include <stdarg.h>
#include <stdlib.h>
#include <time.h>

#include <stm32746g_discovery.h>
#include <stm32746g_discovery_lcd.h>

#include "include/dartino_api.h"
#include "include/static_ffi.h"

#include "platforms/stm/disco_dartino/src/dartino_entry.h"
#include "platforms/stm/disco_dartino/src/device_manager.h"
#include "platforms/stm/disco_dartino/src/page_allocator.h"
#include "src/shared/platform.h"
#include "src/shared/utils.h"

#include "FreeRTOS.h"
#include "FreeRTOSIPConfig.h"
#include "FreeRTOS_IP.h"
#include "FreeRTOS_Sockets.h"

// The value of the ethernet adapter's "Basic Mode Status Register".  This
// value is updated by the driver and can be used, e.g., to check for link
// status, link speed, and duplex mode.
extern uint32_t bmsrValue;

// The MAC_ADDRx constants are currently defined in FreeRTOSIPConfig.h.
uint8_t MACAddress[6] = {MAC_ADDR0, MAC_ADDR1, MAC_ADDR2,
                         MAC_ADDR3, MAC_ADDR4, MAC_ADDR5};

static bool networkIsUp = false;
static bool networkAddressMayHaveChanged = false;
static int device_handle_ = -1;
static dartino::Mutex* mutex_;

// Return the host address in network byte order, if an address for the host has
// been resolved and 0 otherwise.
//
// If the second argument is non-NULL, the result is also written to the 32 bit
// integer it points to.
//
// (The FreeRTOS IP stack currently only supports IP4; we need to change the
// types here when we add IPv6 support.)
uint32_t LookupHost(const char *host, uint32_t *result) {
  uint32_t address = FreeRTOS_inet_addr(host);
  if (address == 0) {
    address = FreeRTOS_gethostbyname(host);
  }
  if (address == 0) {
    return 0;
  }
  if (result != NULL) {
    *result = address;
  }
  return address;
}

bool IsNetworkUp() {
  dartino::ScopedLock lock(mutex_);
  return networkIsUp;
}

bool IsNetworkInitialized() { return (device_handle_ != -1); }

bool NetworkAddressMayHaveChanged() {
  dartino::ScopedLock lock(mutex_);
  bool oldState = networkAddressMayHaveChanged;
  networkAddressMayHaveChanged = false;
  return oldState;
}

void GetNetworkAddressConfiguration(NetworkParameters *parameters) {
  FreeRTOS_GetAddressConfiguration(
      reinterpret_cast<uint32_t *>(parameters->ipAddress),
      reinterpret_cast<uint32_t *>(parameters->netMask),
      reinterpret_cast<uint32_t *>(parameters->gatewayAddress),
      reinterpret_cast<uint32_t *>(parameters->DNSServerAddress));
}

// TODO(karlklose): this function should take an adapter index as argument when
// we support multiple physical ethernet units.
uint32_t GetEthernetAdapterStatus() { return bmsrValue; }

// Initialize the stack.
//
// Returns pdPASS if successful and pdFAIL if not.
BaseType_t InitializeNetworkStack(NetworkParameters const *parameters) {
  BaseType_t result;
  result = FreeRTOS_IPInit(parameters->ipAddress, parameters->netMask,
                           parameters->gatewayAddress,
                           parameters->DNSServerAddress, MACAddress);
  if (result == pdPASS) {
    // Initialize random number generator for use in uxRand.
    srand(time(NULL));
  } else {
    ASSERT(result == pdFAIL);
  }
  mutex_ = dartino::Platform::CreateMutex();
  return result;
}

UBaseType_t uxRand() { return rand(); }

BaseType_t xApplicationDNSQueryHook(const char *pcName) {
  return strcasecmp(pcName, "disco_dartino") == 0;
}

const char *pcApplicationHostnameHook() { return "disco_dartino"; }

void vApplicationIPNetworkEventHook(eIPCallbackEvent_t eNetworkEvent) {
  dartino::ScopedLock lock(mutex_);
  if (eNetworkEvent == eNetworkUp) {
    networkIsUp = true;
    networkAddressMayHaveChanged = true;
  } else {
    networkIsUp = true;
  }
}

// This empty implementation is expected to exist by the framework.
void vApplicationPingReplyHook(ePingReplyStatus_t eStatus,
                               uint16_t usIdentifier) {}

// Debug printing function.  Enable printing in FreeRTOSIPConfig.h.
int lUDPLoggingPrintf(const char *format, ...) {
  va_list argptr;
  va_start(argptr, format);
  int result = vfprintf(stderr, format, argptr);
  va_end(argptr);
  return result;
}
