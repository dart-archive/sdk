# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'variables': {
    'freertos_src': '<(freertos)/Source/',
    'freertos_plus_tcp':
      '<(freertos_with_labs)/'
          'freertos_labs/FreeRTOS-Plus/Source/FreeRTOS-Plus-TCP/',
  },
  'include_dirs': [
    '<(freertos_src)/',
    '<(freertos_src)/CMSIS_RTOS/',
    '<(freertos_src)/include/',
    '<(freertos_src)/portable/GCC/<(freertos_port)/',

    '<(freertos_plus_tcp)/include',
    '<(freertos_plus_tcp)/portable/Compiler/GCC/',
  ],
  'sources': [
    '<(freertos_src)/croutine.c',
    '<(freertos_src)/event_groups.c',
    '<(freertos_src)/list.c',
    '<(freertos_src)/queue.c',
    '<(freertos_src)/tasks.c',
    '<(freertos_src)/timers.c',
    '<(freertos_src)/CMSIS_RTOS/cmsis_os.c',
    '<(freertos_src)/portable/GCC/<(freertos_port)/port.c',

    # FreeRTOS+TCP package.
    '<(freertos_plus_tcp)/FreeRTOS_IP.c',
    '<(freertos_plus_tcp)/FreeRTOS_IP.c',
    '<(freertos_plus_tcp)/FreeRTOS_ARP.c',
    '<(freertos_plus_tcp)/FreeRTOS_DHCP.c',
    '<(freertos_plus_tcp)/FreeRTOS_DNS.c',
    '<(freertos_plus_tcp)/FreeRTOS_Sockets.c',
    '<(freertos_plus_tcp)/FreeRTOS_TCP_IP.c',
    '<(freertos_plus_tcp)/FreeRTOS_UDP_IP.c',
    '<(freertos_plus_tcp)/FreeRTOS_TCP_WIN.c',
    '<(freertos_plus_tcp)/FreeRTOS_Stream_Buffer.c',
  ],
}
