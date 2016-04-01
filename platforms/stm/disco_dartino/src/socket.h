// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef PLATFORMS_STM_DISCO_DARTINO_SRC_SOCKET_H_
#define PLATFORMS_STM_DISCO_DARTINO_SRC_SOCKET_H_

#include "platforms/stm/disco_dartino/src/ethernet.h"

#include <FreeRTOS_Sockets.h>

#ifdef __cplusplus
extern "C" {
#endif

uint32_t RegisterSocket(Socket_t socket);
uint32_t SocketConnect(Socket_t socket, uint32_t address, uint32_t port);
void ResetSocketFlags(uint32_t handle);
void SocketHandlerTask(void *parameters);
void ListenForSocketEvent(Socket_t socket, uint32_t mask);
void UnregisterAndCloseSocket(Socket_t socket);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // PLATFORMS_STM_DISCO_DARTINO_SRC_SOCKET_H_
