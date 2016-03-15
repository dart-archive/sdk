# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'variables': {
    'posix': 0,

    'freertos': '<(DEPTH)/third_party/freertos/',
    'stm32_cube_f7': '<(DEPTH)/third_party/stm/stm32cube_fw_f7',
    'stm32_cube_f7_free_rtos':
      '<(stm32_cube_f7)/Middlewares/Third_Party/FreeRTOS',
    'stm32_cube_f7_bsp_discovery':
      '<(stm32_cube_f7)/Drivers/BSP/STM32746G-Discovery/',

    'gcc-arm-embedded':
      '<(DEPTH)/third_party/gcc-arm-embedded/<(OS)/gcc-arm-embedded/bin',
    'objcopy': '<(gcc-arm-embedded)/arm-none-eabi-objcopy',
  },

  'includes': [
    '../../common.gypi'
  ],

  'target_defaults': {
    'configurations': {
      'dartino_stm': {
        'abstract': 1,

        'target_conditions': [
          ['_toolset=="target"', {
            'defines': [
              'USE_HAL_DRIVER',
              'STM32F746xx',
            ],
            'include_dirs': [
              # We need to set these here since the src/shared/platform_cmsis.h
              # includes cmsis_os.h from here.
              '<(stm32_cube_f7_free_rtos)/Source/CMSIS_RTOS/',
              '<(stm32_cube_f7_free_rtos)/Source/include/',
              '<(stm32_cube_f7_free_rtos)/Source/portable/GCC/ARM_CM7/r0p1/',
              '<(stm32_cube_f7)/Drivers/CMSIS/Include/',
              'disco_dartino/src',
              '../..'
            ],
          }],
        ],
      },

      'ReleaseSTM': {
        'inherit_from': [
          'dartino_base', 'dartino_release',
          'dartino_cortex_m_base', 'dartino_cortex_m7', 'dartino_stm',
          'dartino_disable_live_coding',
          'dartino_disable_native_processes',
        ],
        'target_conditions': [
          # Change to optimize for size.
          ['_toolset=="target"', {
            'cflags!': [
              '-O3',
            ],
            'cflags': [
              '-Os',
            ],
          }],
        ],
      },

      'DebugSTM': {
        'inherit_from': [
          'dartino_base', 'dartino_debug',
          'dartino_cortex_m_base', 'dartino_cortex_m7', 'dartino_stm',
          'dartino_disable_live_coding',
          'dartino_disable_native_processes',
        ],
      },
    },
  },
}
