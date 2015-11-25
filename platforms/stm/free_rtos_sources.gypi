# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'variables': {
    'stm32_cube_f7_free_rtos_src':
      '<(stm32_cube_f7)/Middlewares/Third_Party/FreeRTOS/Source/',
  },
  'include_dirs': [
    '<(stm32_cube_f7_free_rtos_src)/',
    '<(stm32_cube_f7_free_rtos_src)/CMSIS_RTOS/',
    '<(stm32_cube_f7_free_rtos_src)/include/',
    '<(stm32_cube_f7_free_rtos_src)/portable/GCC/ARM_CM7/r0p1/',
  ],
  'sources': [
    '<(stm32_cube_f7_free_rtos_src)/croutine.c',
    '<(stm32_cube_f7_free_rtos_src)/event_groups.c',
    '<(stm32_cube_f7_free_rtos_src)/list.c',
    '<(stm32_cube_f7_free_rtos_src)/queue.c',
    '<(stm32_cube_f7_free_rtos_src)/tasks.c',
    '<(stm32_cube_f7_free_rtos_src)/timers.c',
    '<(stm32_cube_f7_free_rtos_src)/CMSIS_RTOS/cmsis_os.c',
    '<(stm32_cube_f7_free_rtos_src)/portable/MemMang/heap_4.c',
    '<(stm32_cube_f7_free_rtos_src)/portable/GCC/ARM_CM7/r0p1/port.c',
  ],
}
